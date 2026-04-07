from __future__ import annotations

import time
from typing import Dict

from ...config import PipelineConfig


def build_teacher_payload(config: PipelineConfig, smooth_score: float) -> Dict[str, object]:
    return {
        "student_id": config.student_id,
        "page": config.current_page,
        "focus_score": smooth_score,
        "timestamp": time.time(),
    }
