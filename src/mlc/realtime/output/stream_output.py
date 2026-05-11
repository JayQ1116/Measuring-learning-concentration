from __future__ import annotations

import csv
import datetime
import os
import time
from typing import Any, Iterable

import cv2
import numpy as np

from ..input import close_camera, open_camera, read_camera_frame
from ..model import detect_faces_yolo, predict_emotions, preprocess_face
from .ui_output import draw_prediction


def iter_frames(
    model: Any,
    yolo_face_model: Any,
    cap_holder: dict,
    page_state: dict,
    *,
    csv_path: str,
    csv_window_sec: float,
    pdf_name: str,
    default_page: int,
    img_size: tuple[int, int],
    yolo_confidence: float,
    yolo_iou: float,
    camera_index: int,
) -> Iterable[bytes]:
    csv_dir = os.path.dirname(csv_path)
    if csv_dir:
        os.makedirs(csv_dir, exist_ok=True)

    csv_exists = os.path.exists(csv_path)
    csv_file = open(csv_path, "a", newline="", encoding="utf-8")
    writer = csv.writer(csv_file)
    if not csv_exists:
        writer.writerow([
            "timestamp",
            "engagement",
            "boredom",
            "confusion",
            "frustration",
            "samples",
            "pdf_page",
            "pdf_name",
        ])
        csv_file.flush()

    window_start = time.time()
    window_preds: list[np.ndarray] = []
    failed_reads = 0

    try:
        while True:
            ok, frame = read_camera_frame(cap_holder["cap"])
            if not ok or frame is None:
                failed_reads += 1
                if failed_reads >= 5:
                    failed_reads = 0
                    close_camera(cap_holder["cap"])
                    reopened = open_camera(camera_index)
                    cap_holder["cap"] = reopened
                continue
            failed_reads = 0

            faces = detect_faces_yolo(yolo_face_model, frame, yolo_confidence, yolo_iou)

            pred = None
            for box in faces:
                face_tensor = preprocess_face(frame, box, img_size)
                pred = predict_emotions(model, face_tensor)
                draw_prediction(frame, box, pred)
                break

            if len(faces) == 0:
                cv2.putText(
                    frame,
                    "No face detected",
                    (20, 35),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.9,
                    (0, 0, 255),
                    2,
                )

            if pred is not None:
                window_preds.append(pred.flatten())

            now = time.time()
            if now - window_start >= csv_window_sec:
                if window_preds:
                    avg = np.mean(window_preds, axis=0)
                    kst = datetime.timezone(datetime.timedelta(hours=9))
                    timestamp = datetime.datetime.now(kst).replace(microsecond=0).isoformat()
                    writer.writerow([
                        timestamp,
                        f"{avg[0]:.6f}",
                        f"{avg[1]:.6f}",
                        f"{avg[2]:.6f}",
                        f"{avg[3]:.6f}",
                        str(len(window_preds)),
                        str(page_state.get("page", default_page)),
                        pdf_name,
                    ])
                    csv_file.flush()
                window_start = now
                window_preds = []

            ret, jpeg = cv2.imencode(".jpg", frame)
            if not ret:
                continue

            yield (
                b"--frame\r\n"
                b"Content-Type: image/jpeg\r\n\r\n" + jpeg.tobytes() + b"\r\n\r\n"
            )
    finally:
        csv_file.close()
