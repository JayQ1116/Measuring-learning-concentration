from __future__ import annotations

import cv2


def open_camera(camera_index: int) -> cv2.VideoCapture:
    cap = cv2.VideoCapture(camera_index)
    if not cap.isOpened():
        raise RuntimeError(f"Unable to open camera index {camera_index}")
    return cap


def read_camera_frame(cap: cv2.VideoCapture):
    return cap.read()


def close_camera(cap: cv2.VideoCapture) -> None:
    cap.release()
    cv2.destroyAllWindows()
