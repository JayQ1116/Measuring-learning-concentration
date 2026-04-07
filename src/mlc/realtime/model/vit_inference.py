from __future__ import annotations

import random
from typing import Tuple

Prediction = Tuple[float, str]


def get_vit_prediction(_frame) -> Prediction:
    """Stub for real ViT inference output."""
    score = random.uniform(0.1, 0.95)
    label = "Focused" if score > 0.6 else "Distracted"
    return score, label
