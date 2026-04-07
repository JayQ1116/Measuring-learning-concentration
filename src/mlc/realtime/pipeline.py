from __future__ import annotations

import random
import time
from collections import defaultdict

from ..config import PipelineConfig
from .assistant import ask_learning_llm
from .courseware import PdfCoursewareViewer
from .input import close_camera, open_camera, read_camera_frame
from .model import classify_state, get_vit_prediction, sliding_window
from .output import (
    build_teacher_payload,
    draw_student_ui,
    init_student_window,
    read_key,
    set_student_window_mode,
    set_student_window_topmost,
    show_student_ui,
)
from .teacher import generate_teacher_report, update_server_state


def run_student_camera_loop(config: PipelineConfig) -> None:
    random.seed(config.random_seed)

    cap = open_camera(config.camera_index)
    window_size = config.window_seconds * config.fps
    predictions_history = []
    confusion_counts: dict[int, int] = defaultdict(int)
    last_sync_time = time.time()
    current_state = "compact"
    topmost = config.student_window_topmost

    init_student_window(config)

    pdf_viewer = PdfCoursewareViewer(config.pdf_path, config.pdf_window_name)
    print(
        f"PDF source: {config.pdf_path} | loaded: {pdf_viewer.is_available}"
    )

    print(f"System initialized. Student ID: {config.student_id}")
    print(
        "Hotkeys: "
        f"{config.ask_llm_key}=ask LLM, {config.next_page_key}/{config.prev_page_key}=next/prev page, "
        f"{config.toggle_window_key}=toggle student window size, "
        f"{config.toggle_topmost_key}=toggle topmost, {config.quit_key}=quit"
    )

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
        pdf_viewer.show()

        if time.time() - last_sync_time > config.sync_interval:
            payload = build_teacher_payload(
                config,
                smooth_score,
                confusion_count_on_page=confusion_counts[config.current_page],
            )
            update_server_state(payload)
            generate_teacher_report(config)
            last_sync_time = time.time()

        key = read_key()
        if key == config.quit_key:
            break
        if key == config.ask_llm_key:
            question = input("\n[LLM] Ask your question: ").strip()
            if question:
                response = ask_learning_llm(question, config.current_page, state)
                print(response)
                confusion_counts[config.current_page] += 1
        if key == config.next_page_key:
            pdf_viewer.next_page()
            config.current_page = pdf_viewer.current_page_number
        if key == config.prev_page_key:
            pdf_viewer.prev_page()
            config.current_page = pdf_viewer.current_page_number
        if key == config.toggle_window_key:
            current_state = "maximized" if current_state == "compact" else "compact"
            set_student_window_mode(config, current_state)
            print(f"[UI] Student camera window mode: {current_state}")
        if key == config.toggle_topmost_key:
            topmost = not topmost
            set_student_window_topmost(config.ui_window_name, topmost)
            print(f"[UI] Student camera topmost: {topmost}")

    pdf_viewer.close()
    close_camera(cap)


def run_realtime_pipeline(config: PipelineConfig | None = None) -> None:
    if config is None:
        config = PipelineConfig()

    run_student_camera_loop(config)
