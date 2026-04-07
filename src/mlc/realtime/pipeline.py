from __future__ import annotations

import random
import time

from ..config import PipelineConfig
from .input import close_camera, open_camera, read_camera_frame
from .model import classify_state, get_vit_prediction, sliding_window
from .output import build_teacher_payload, draw_student_ui, should_quit, show_student_ui
from .teacher import generate_teacher_report, update_server_state


def run_student_camera_loop(config: PipelineConfig) -> None:
    random.seed(config.random_seed)

    cap = open_camera(config.camera_index)
    window_size = config.window_seconds * config.fps
    predictions_history = []
    last_sync_time = time.time()

    print(f"System initialized. Student ID: {config.student_id}")

    while cap.isOpened():
        ret, frame = read_camera_frame(cap)
        if not ret:
            break

        score, label = get_vit_prediction(frame)
        predictions_history.append((score, label))
        if len(predictions_history) > window_size:
            predictions_history.pop(0)

        smooth_score = sliding_window(predictions_history, window_size)
        state = classify_state(smooth_score, config)

        draw_student_ui(frame, config, smooth_score, state)
        show_student_ui(config.ui_window_name, frame)

        if time.time() - last_sync_time > config.sync_interval:
            payload = build_teacher_payload(config, smooth_score)
            update_server_state(payload)
            generate_teacher_report(config)
            last_sync_time = time.time()

        if should_quit(config.quit_key):
            break

    close_camera(cap)


def run_realtime_pipeline(config: PipelineConfig | None = None) -> None:
    if config is None:
        config = PipelineConfig()

    run_student_camera_loop(config)
