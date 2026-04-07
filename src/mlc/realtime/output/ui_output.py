from __future__ import annotations

import cv2
from typing import Optional

from ...config import PipelineConfig


def draw_student_ui(frame, config: PipelineConfig, smooth_score: float, state: str) -> None:
    if state == "Focused":
        ui_color = (0, 255, 0)
    elif state == "Slightly Distracted":
        ui_color = (0, 255, 255)
    else:
        ui_color = (0, 0, 255)

    cv2.rectangle(frame, (15, 15), (430, 150), (0, 0, 0), -1)
    cv2.putText(
        frame,
        f"REAL-TIME MONITOR: {config.student_id}",
        (30, 45),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.5,
        (200, 200, 200),
        1,
    )
    cv2.putText(
        frame,
        f"SCORE: {smooth_score:.2f}",
        (30, 85),
        cv2.FONT_HERSHEY_SIMPLEX,
        1,
        ui_color,
        2,
    )
    cv2.putText(
        frame,
        f"STATE: {state}",
        (30, 120),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        ui_color,
        2,
    )

    if state == "Distracted":
        cv2.putText(
            frame,
            "AI HELP ACTIVE",
            (30, 175),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (255, 150, 0),
            2,
        )


def show_student_ui(window_name: str, frame) -> None:
    cv2.imshow(window_name, frame)


def init_student_window(config: PipelineConfig) -> None:
    cv2.namedWindow(config.ui_window_name, cv2.WINDOW_NORMAL)
    set_student_window_mode(config, mode="compact")
    set_student_window_topmost(config.ui_window_name, config.student_window_topmost)


def set_student_window_mode(config: PipelineConfig, mode: str) -> None:
    cv2.setWindowProperty(config.ui_window_name, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_NORMAL)
    if mode == "maximized":
        cv2.resizeWindow(config.ui_window_name, config.maximized_width, config.maximized_height)
    else:
        cv2.resizeWindow(config.ui_window_name, config.compact_width, config.compact_height)


def set_student_window_topmost(window_name: str, topmost: bool) -> None:
    try:
        cv2.setWindowProperty(
            window_name,
            cv2.WND_PROP_TOPMOST,
            1 if topmost else 0,
        )
    except Exception:
        # WND_PROP_TOPMOST is backend-dependent; ignore where unsupported.
        pass


def read_key() -> Optional[str]:
    key_code = cv2.waitKey(1) & 0xFF
    if key_code == 255:
        return None
    try:
        return chr(key_code).lower()
    except ValueError:
        return None
