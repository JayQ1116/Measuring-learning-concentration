from __future__ import annotations

import cv2

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


def should_quit(quit_key: str) -> bool:
    return cv2.waitKey(1) & 0xFF == ord(quit_key)
