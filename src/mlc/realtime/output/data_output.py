from __future__ import annotations

import csv
import datetime
import os
import time
from typing import Dict, List

from ...config import PipelineConfig


class CsvWindowAverager:
    def __init__(self, csv_path: str, window_seconds: float) -> None:
        self.csv_path = csv_path
        self.window_seconds = window_seconds
        self.window_start = time.time()
        self.samples: List[float] = []
        self.last_page: int | None = None

        csv_dir = os.path.dirname(csv_path)
        if csv_dir:
            os.makedirs(csv_dir, exist_ok=True)

        csv_exists = os.path.exists(csv_path)
        self.csv_file = open(csv_path, "a", newline="", encoding="utf-8")
        self.writer = csv.writer(self.csv_file)
        if not csv_exists:
            self.writer.writerow([
                "timestamp",
                "avg_focus_score",
                "samples",
                "pdf_page",
                "pdf_name",
            ])
            self.csv_file.flush()

    def add_sample(self, score: float, page: int | None = None) -> None:
        self.samples.append(score)
        if page is not None:
            self.last_page = page
        now = time.time()
        if now - self.window_start >= self.window_seconds:
            self._flush(now)

    def close(self) -> None:
        if self.samples:
            self._flush(time.time())
        self.csv_file.close()

    def _flush(self, now: float) -> None:
        if not self.samples:
            self.window_start = now
            return

        avg_score = sum(self.samples) / len(self.samples)
        timestamp = datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
        page_value = "" if self.last_page is None else str(self.last_page)
        pdf_name = os.path.basename(PipelineConfig().pdf_path)
        self.writer.writerow([
            timestamp,
            f"{avg_score:.6f}",
            str(len(self.samples)),
            page_value,
            pdf_name,
        ])
        self.csv_file.flush()
        self.samples = []
        self.window_start = now


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
