from __future__ import annotations

import time
from typing import Dict

from ...config import PipelineConfig


def build_teacher_payload(
    config: PipelineConfig,
    smooth_score: float,
    confusion_count_on_page: int,
) -> Dict[str, object]:
    return {
        "student_id": config.student_id,
        "page": config.current_page,
        "focus_score": smooth_score,
        "confusion_count_on_page": confusion_count_on_page,
        "low_focus_flag": smooth_score <= config.slight_distracted_threshold,
        "timestamp": time.time(),
    }
