"""Dry run implementation for a learning concentration monitoring system.

This script simulates an end-to-end pipeline:
1) Video frame collection
2) ViT-like frame-level inference (simulated)
3) Sliding-window smoothing
4) State classification
5) Intervention decision
6) RAG + LLM feedback (simulated)
7) UI rendering
8) Teacher-side sync
"""

from __future__ import annotations

import random
from collections import defaultdict
from dataclasses import dataclass
from typing import Any, Dict, List, Tuple


Prediction = Tuple[float, str]


@dataclass
class PipelineConfig:
	fps: int = 30
	duration_seconds: int = 5
	window_seconds: int = 5
	focused_threshold: float = 0.7
	slight_distracted_threshold: float = 0.4
	student_id: str = "A01"
	rag_page: str = "PDF_page_10"
	random_seed: int = 42


def collect_video_frames(config: PipelineConfig) -> List[int]:
	"""Simulate frame indices collected from a camera stream."""
	frame_count = config.fps * config.duration_seconds
	return list(range(frame_count))


def run_vit_model(frames: List[int]) -> List[Prediction]:
	"""Simulate per-frame ViT predictions with concentration drift over time."""
	results: List[Prediction] = []
	split_index = int(len(frames) * 0.53)

	for i, _frame in enumerate(frames):
		if i < split_index:
			score = random.uniform(0.8, 0.9)
			label = "Focused"
		else:
			score = random.uniform(0.3, 0.5)
			label = "Distracted"
		results.append((score, label))

	return results


def sliding_window(predictions: List[Prediction], window_size: int) -> float:
	"""Compute mean score of the latest window to smooth short-term noise."""
	scores = [score for score, _label in predictions]
	effective_window = min(window_size, len(scores))
	recent_scores = scores[-effective_window:]
	return sum(recent_scores) / len(recent_scores)


def classify_state(score: float, config: PipelineConfig) -> str:
	"""Map concentration score into qualitative state labels."""
	if score > config.focused_threshold:
		return "Focused"
	if score > config.slight_distracted_threshold:
		return "Slightly Distracted"
	return "Distracted"


def need_intervention(state: str) -> bool:
	"""Trigger intervention if current state is not focused."""
	return state != "Focused"


def rag_llm(page: str) -> str:
	"""Simulate retrieval-augmented feedback from study material."""
	return f"[AI 튜터] 현재 {page} 내용의 핵심 요약: 핵심 개념에 유의하고, 먼저 정의를 다시 설명한 후 문제를 풀어보세요."


def render_ui(score: float, state: str, feedback: str | None) -> None:
	"""Console UI output for student-side feedback."""
	print(f"Focus Score: {score:.2f}")
	print(f"State: {state}")
	if feedback:
		print(f"AI Feedback: {feedback}")


def send_to_teacher(score: float, state: str, config: PipelineConfig) -> Dict[str, object]:
	"""Build and print payload that would be sent to teacher dashboard."""
	payload = {
		"student_id": config.student_id,
		"page": 10,
		"focus_score": round(score, 2),
		"state": state,
	}
	print(f"Send to teacher: {payload}")
	return payload


def receive_student_data(student_payload: Dict[str, object]) -> List[Dict[str, object]]:
	"""Simulate teacher-side API intake by combining one real payload with peers."""
	data = [
		{
			"student_id": student_payload["student_id"],
			"page": student_payload.get("page", 10),
			"score": float(student_payload["focus_score"]),
		},
		{"student_id": "A02", "page": 10, "score": 0.82},
		{"student_id": "A03", "page": 10, "score": 0.45},
	]
	return data


def analyze_students(data: List[Dict[str, object]], config: PipelineConfig) -> List[Dict[str, object]]:
	"""Assign per-student focus state based on score thresholds."""
	processed: List[Dict[str, object]] = []
	for student in data:
		score = float(student["score"])
		if score > config.focused_threshold:
			state = "Focused"
		elif score > config.slight_distracted_threshold:
			state = "Slightly Distracted"
		else:
			state = "Distracted"

		item = dict(student)
		item["state"] = state
		processed.append(item)

	return processed


def generate_heatmap(data: List[Dict[str, object]], config: PipelineConfig) -> Dict[int, Dict[str, Any]]:
	"""Aggregate concentration per page and convert into heatmap colors."""
	page_scores: Dict[int, List[float]] = defaultdict(list)
	for student in data:
		page = int(student["page"])
		score = float(student["score"])
		page_scores[page].append(score)

	heatmap: Dict[int, Dict[str, Any]] = {}
	for page, scores in page_scores.items():
		avg_score = sum(scores) / len(scores)
		if avg_score > config.focused_threshold:
			color = "Green"
		elif avg_score > config.slight_distracted_threshold:
			color = "Yellow"
		else:
			color = "Red"

		heatmap[page] = {"avg_score": round(avg_score, 2), "color": color}

	return heatmap


def detect_at_risk_students(data: List[Dict[str, object]], config: PipelineConfig) -> List[str]:
	"""Return IDs of students below the distraction cutoff."""
	return [
		str(student["student_id"])
		for student in data
		if float(student["score"]) <= config.slight_distracted_threshold
	]


def render_dashboard(
	data: List[Dict[str, object]],
	heatmap: Dict[int, Dict[str, Any]],
	warnings: List[str],
) -> None:
	"""Console dashboard for teacher-side monitoring."""
	print("\n=== Teacher Dashboard ===")

	print("\n[Student Status]")
	for student in data:
		print(student)

	print("\n[Heatmap]")
	for page, info in sorted(heatmap.items()):
		print(f"Page {page}: {info}")

	print("\n[Warning Students]")
	print(warnings)


def teacher_main(student_payload: Dict[str, object], config: PipelineConfig) -> None:
	"""Run end-to-end teacher pipeline using uploaded student results."""
	raw_data = receive_student_data(student_payload)
	processed = analyze_students(raw_data, config)
	heatmap = generate_heatmap(processed, config)
	warnings = detect_at_risk_students(processed, config)
	render_dashboard(processed, heatmap, warnings)


def main() -> None:
	config = PipelineConfig()
	random.seed(config.random_seed)

	print("=== Learning Concentration System Dry Run ===")

	frames = collect_video_frames(config)
	predictions = run_vit_model(frames)

	window_size = config.window_seconds * config.fps
	focus_score = sliding_window(predictions, window_size=window_size)
	state = classify_state(focus_score, config)

	feedback = rag_llm(config.rag_page) if need_intervention(state) else None

	render_ui(focus_score, state, feedback)
	student_payload = send_to_teacher(focus_score, state, config)
	teacher_main(student_payload, config)


if __name__ == "__main__":
	main()
