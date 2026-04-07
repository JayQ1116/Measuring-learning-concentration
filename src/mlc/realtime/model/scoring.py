from __future__ import annotations

from ...config import PipelineConfig


def classify_state(score: float, config: PipelineConfig) -> str:
    if score > config.focused_threshold:
        return "Focused"
    if score > config.slight_distracted_threshold:
        return "Slightly Distracted"
    return "Distracted"


def sliding_window(scores_history: list[tuple[float, str]], window_size: int) -> float:
    if not scores_history:
        return 0.0

    recent = scores_history[-window_size:]
    scores = [score for score, _label in recent]
    return sum(scores) / len(scores)
