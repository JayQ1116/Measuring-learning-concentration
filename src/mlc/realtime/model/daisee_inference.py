from __future__ import annotations

import os
from typing import List, Tuple

import numpy as np
import tensorflow as tf


def setup_gpu_memory_growth() -> None:
    physical_devices = tf.config.list_physical_devices("GPU")
    for device in physical_devices:
        try:
            tf.config.experimental.set_memory_growth(device, True)
        except RuntimeError:
            pass


def build_notebook_architecture(input_shape: Tuple[int, int, int]) -> tf.keras.Model:
    """Recreate the notebook model architecture for legacy weight loading."""
    base_model = tf.keras.applications.MobileNetV2(
        weights=None,
        include_top=False,
        input_shape=input_shape,
        alpha=1.0,
    )

    model = tf.keras.Sequential(
        [
            tf.keras.layers.Input(shape=input_shape),
            base_model,
            tf.keras.layers.GlobalAveragePooling2D(),
            tf.keras.layers.Dropout(0.3),
            tf.keras.layers.Dense(512, activation="relu"),
            tf.keras.layers.BatchNormalization(),
            tf.keras.layers.Dropout(0.5),
            tf.keras.layers.Dense(256, activation="relu"),
            tf.keras.layers.BatchNormalization(),
            tf.keras.layers.Dropout(0.5),
            tf.keras.layers.Dense(4, activation="sigmoid", name="emotions"),
        ]
    )
    return model


def load_inference_model(model_path: str, img_size: Tuple[int, int]) -> tf.keras.Model:
    """Load model with a compatibility fallback for legacy H5 exports."""
    try:
        return tf.keras.models.load_model(model_path, compile=False)
    except Exception as exc:
        print(f"Primary load_model failed: {exc}")
        print("Trying fallback: rebuild architecture and load weights from H5...")

        fallback_model = build_notebook_architecture(
            input_shape=(img_size[0], img_size[1], 3)
        )
        fallback_model.load_weights(model_path)
        print("Fallback weight loading succeeded.")
        return fallback_model


def load_yolo_face_model(model_path: str):
    try:
        from ultralytics import YOLO
    except ImportError as exc:
        raise ImportError(
            "ultralytics is required for YOLO mode. Install with: pip install ultralytics"
        ) from exc

    if not os.path.exists(model_path):
        raise FileNotFoundError(
            f"YOLO face model not found: {model_path}. "
            "Set DAISEE_YOLO_FACE_MODEL to your .pt file path."
        )

    return YOLO(model_path)


def detect_faces_yolo(
    yolo_model,
    frame: np.ndarray,
    confidence: float,
    iou: float,
) -> List[Tuple[int, int, int, int]]:
    h, w = frame.shape[:2]
    results = yolo_model.predict(
        source=frame,
        conf=confidence,
        iou=iou,
        verbose=False,
    )

    faces: List[Tuple[int, int, int, int]] = []
    if not results:
        return faces

    boxes = results[0].boxes
    if boxes is None or boxes.xyxy is None:
        return faces

    for xyxy in boxes.xyxy.cpu().numpy():
        x1, y1, x2, y2 = xyxy.astype(int)
        x1 = max(0, min(x1, w - 1))
        y1 = max(0, min(y1, h - 1))
        x2 = max(0, min(x2, w - 1))
        y2 = max(0, min(y2, h - 1))

        bw = x2 - x1
        bh = y2 - y1
        if bw > 20 and bh > 20:
            faces.append((x1, y1, bw, bh))

    return faces


def preprocess_face(
    frame: np.ndarray,
    box: Tuple[int, int, int, int],
    img_size: Tuple[int, int],
) -> np.ndarray:
    x, y, w, h = box
    face = frame[y:y + h, x:x + w]
    face = tf.image.resize(face, img_size)
    face = tf.cast(face, tf.float32) / 255.0
    face = tf.expand_dims(face, axis=0)
    return face.numpy()


def predict_emotions(model: tf.keras.Model, face_tensor: np.ndarray) -> np.ndarray:
    return model.predict(face_tensor, verbose=0)
