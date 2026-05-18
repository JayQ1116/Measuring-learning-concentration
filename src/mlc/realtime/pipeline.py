from __future__ import annotations

import os
import time
from collections import defaultdict
from typing import Tuple

import cv2

from ..config import PipelineConfig
from .courseware import PdfCoursewareViewer
from .input import close_camera, open_camera, read_camera_frame
from .llm.llm import StudentQuestionHandler
from .model import (
	classify_state,
	detect_faces_yolo,
	load_inference_model,
	load_yolo_face_model,
	predict_emotions,
	preprocess_face,
	sliding_window,
	setup_gpu_memory_growth,
)
from .output import (
	CsvWindowAverager,
	build_teacher_payload,
	draw_prediction,
	draw_student_ui,
	init_student_window,
	read_key,
	set_student_window_mode,
	set_student_window_topmost,
	show_student_ui,
)
from .settings import IMG_SIZE, MODEL_PATH, YOLO_CONFIDENCE, YOLO_FACE_MODEL_PATH, YOLO_IOU
from .teacher import generate_teacher_report, update_server_state


def emotion_to_focus_score(emotions) -> float:
	return float(emotions.flatten()[0])


def run_student_camera_loop(config: PipelineConfig | None = None) -> None:
	if config is None:
		config = PipelineConfig()

	setup_gpu_memory_growth()

	if not os.path.exists(MODEL_PATH):
		raise FileNotFoundError(f"Model not found: {MODEL_PATH}")

	model = load_inference_model(MODEL_PATH, IMG_SIZE)
	yolo_face_model = load_yolo_face_model(YOLO_FACE_MODEL_PATH)

	cap = open_camera(config.camera_index)
	window_size = config.window_seconds * config.fps
	predictions_history: list[Tuple[float, str]] = []
	confusion_counts: dict[int, int] = defaultdict(int)
	last_sync_time = time.time()
	current_state = "compact"
	topmost = config.student_window_topmost

	init_student_window(config)
	llm_handler = StudentQuestionHandler()
	csv_averager = CsvWindowAverager(config.csv_path, config.csv_window_seconds)

	pdf_viewer = PdfCoursewareViewer(config.pdf_path, config.pdf_window_name)
	print(f"PDF source: {config.pdf_path} | loaded: {pdf_viewer.is_available}")

	print(f"System initialized. Student ID: {config.student_id}")
	print(
		"Hotkeys: "
		f"{config.ask_llm_key}=ask LLM, {config.next_page_key}/{config.prev_page_key}=next/prev page, "
		f"{config.toggle_window_key}=toggle student window size, "
		f"{config.toggle_topmost_key}=toggle topmost, {config.quit_key}=quit"
	)

	try:
		while cap.isOpened():
			ret, frame = read_camera_frame(cap)
			if not ret:
				break

			faces = detect_faces_yolo(yolo_face_model, frame, YOLO_CONFIDENCE, YOLO_IOU)
			if faces:
				face_tensor = preprocess_face(frame, faces[0], IMG_SIZE)
				emotions = predict_emotions(model, face_tensor)
				focus_score = emotion_to_focus_score(emotions)
				predictions_history.append((focus_score, "Engagement"))
				draw_prediction(frame, faces[0], emotions)
			else:
				cv2.putText(
					frame,
					"No face detected",
					(20, 35),
					cv2.FONT_HERSHEY_SIMPLEX,
					0.9,
					(0, 0, 255),
					2,
				)

			if len(predictions_history) > window_size:
				predictions_history.pop(0)

			smooth_score = sliding_window(predictions_history, window_size)
			state = classify_state(smooth_score, config)
			csv_averager.add_sample(smooth_score, config.current_page)

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
					response = llm_handler.handle(question, config.current_page, state)
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
	finally:
		csv_averager.close()
		pdf_viewer.close()
		close_camera(cap)


def run_realtime_pipeline(config: PipelineConfig | None = None) -> None:
	run_student_camera_loop(config)


__all__ = ["run_realtime_pipeline", "run_student_camera_loop", "PipelineConfig"]
