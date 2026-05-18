from __future__ import annotations

import csv
import datetime
import os
import time
from typing import Any, Iterable, Optional

import cv2
import numpy as np

try:
    from supabase import Client, create_client
except ImportError:  # pragma: no cover - optional dependency
    Client = None
    create_client = None

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
    supabase_url: str,
    supabase_key: str,
    student_id: str,
    student_name: str,
    img_size: tuple[int, int],
    yolo_confidence: float,
    yolo_iou: float,
    camera_index: int,
) -> Iterable[bytes]:
    supabase_client: Optional["Client"] = None
    if supabase_url and supabase_key and create_client is not None and student_id:
        try:
            supabase_client = create_client(supabase_url, supabase_key)
            supabase_client.table("students").upsert({
                "id": student_id,
                "name": student_name or "신규림",
            }).execute()
        except Exception:
            supabase_client = None

    csv_file = None
    writer = None
    if supabase_client is None:
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
                    if supabase_client is not None:
                        supabase_client.table("engagement_metrics").insert({
                            "student_id": student_id,
                            "timestamp": timestamp,
                            "engagement": float(avg[0]),
                            "boredom": float(avg[1]),
                            "confusion": float(avg[2]),
                            "frustration": float(avg[3]),
                            "samples": int(len(window_preds)),
                            "pdf_page": int(page_state.get("page", default_page)),
                            "pdf_name": pdf_name,
                        }).execute()
                    elif writer is not None and csv_file is not None:
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
        if csv_file is not None:
            csv_file.close()
