from __future__ import annotations

import cv2


def open_camera(
    camera_index: int,
    width: int = 640,
    height: int = 480,
) -> cv2.VideoCapture:
    backends = [cv2.CAP_DSHOW, cv2.CAP_MSMF, None]
    for backend in backends:
        cap = (
            cv2.VideoCapture(camera_index)
            if backend is None
            else cv2.VideoCapture(camera_index, backend)
        )
        if cap.isOpened():
            cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            return cap

    raise RuntimeError(f"Unable to open camera index {camera_index}")


def read_camera_frame(cap: cv2.VideoCapture):
    return cap.read()


def close_camera(cap: cv2.VideoCapture) -> None:
    cap.release()
    cv2.destroyAllWindows()
