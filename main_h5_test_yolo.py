from flask import Flask, Response, render_template
import os
import cv2
import numpy as np
import tensorflow as tf


MODEL_PATH = os.environ.get(
    "DAISEE_H5_MODEL",
    "models/daisee_engagement_model_final.h5",
)
YOLO_FACE_MODEL_PATH = os.environ.get(
    "DAISEE_YOLO_FACE_MODEL",
    "models/yolov8n-face.pt",
)
YOLO_CONFIDENCE = float(os.environ.get("DAISEE_YOLO_CONF", "0.35"))
YOLO_IOU = float(os.environ.get("DAISEE_YOLO_IOU", "0.45"))
IMG_SIZE = (224, 224)
LABELS = ["Engagement", "Boredom", "Confusion", "Frustration"]
USE_HTTPS = os.environ.get("DAISEE_USE_HTTPS", "1") == "1"
SSL_CERT_PATH = os.environ.get("DAISEE_SSL_CERT", "")
SSL_KEY_PATH = os.environ.get("DAISEE_SSL_KEY", "")
FLASK_DEBUG = os.environ.get("DAISEE_FLASK_DEBUG", "1") == "0"


def setup_gpu_memory_growth() -> None:
    physical_devices = tf.config.list_physical_devices("GPU")
    for device in physical_devices:
        try:
            tf.config.experimental.set_memory_growth(device, True)
        except RuntimeError:
            pass


def build_notebook_architecture(input_shape=(224, 224, 3)) -> tf.keras.Model:
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


def load_inference_model(model_path: str) -> tf.keras.Model:
    """Load model with a compatibility fallback for legacy H5 exports."""
    try:
        return tf.keras.models.load_model(model_path, compile=False)
    except Exception as e:
        print(f"Primary load_model failed: {e}")
        print("Trying fallback: rebuild architecture and load weights from H5...")

        fallback_model = build_notebook_architecture(input_shape=(IMG_SIZE[0], IMG_SIZE[1], 3))
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


def detect_faces_yolo(yolo_model, frame: np.ndarray):
    h, w = frame.shape[:2]
    results = yolo_model.predict(
        source=frame,
        conf=YOLO_CONFIDENCE,
        iou=YOLO_IOU,
        verbose=False,
    )

    faces: list[tuple[int, int, int, int]] = []
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


def preprocess_face(frame: np.ndarray, box: tuple[int, int, int, int]) -> np.ndarray:
    x, y, w, h = box
    face = frame[y:y + h, x:x + w]
    face = cv2.cvtColor(face, cv2.COLOR_BGR2RGB)
    face = cv2.resize(face, IMG_SIZE, interpolation=cv2.INTER_AREA)
    face = face.astype(np.float32) / 255.0
    face = np.expand_dims(face, axis=0)
    return face


def draw_prediction(frame: np.ndarray, box: tuple[int, int, int, int], pred: np.ndarray) -> np.ndarray:
    x, y, w, h = box
    cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 2)

    p = pred.flatten()
    top_line = f"Eng:{p[0]:.2f} Bor:{p[1]:.2f}"
    bottom_line = f"Con:{p[2]:.2f} Fru:{p[3]:.2f}"

    cv2.putText(
        frame,
        top_line,
        (x, max(20, y - 10)),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (36, 255, 12),
        2,
    )
    cv2.putText(
        frame,
        bottom_line,
        (x, y + h + 25),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (36, 255, 12),
        2,
    )
    return frame


def open_capture(device_index: int = 0) -> cv2.VideoCapture:
    cap = cv2.VideoCapture(device_index, cv2.CAP_DSHOW)
    if not cap.isOpened():
        cap = cv2.VideoCapture(device_index, cv2.CAP_MSMF)

    if cap.isOpened():
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

    return cap


def create_app() -> Flask:
    setup_gpu_memory_growth()

    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(f"Model not found: {MODEL_PATH}")

    model = load_inference_model(MODEL_PATH)
    yolo_face_model = load_yolo_face_model(YOLO_FACE_MODEL_PATH)
    cap_holder = {"cap": open_capture(0)}
    if not cap_holder["cap"].isOpened():
        raise RuntimeError("Failed to open camera device 0")

    app = Flask(__name__)

    @app.route("/")
    def index():
        return render_template("index.html")

    def gen():
        failed_reads = 0
        while True:
            ok, frame = cap_holder["cap"].read()
            if not ok or frame is None:
                failed_reads += 1
                if failed_reads >= 5:
                    failed_reads = 0
                    cap_holder["cap"].release()
                    reopened = open_capture(0)
                    if reopened.isOpened():
                        cap_holder["cap"] = reopened
                continue
            failed_reads = 0

            faces = detect_faces_yolo(yolo_face_model, frame)

            for box in faces:
                face_tensor = preprocess_face(frame, box)
                pred = model.predict(face_tensor, verbose=0)
                frame = draw_prediction(frame, box, pred)
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

            ret, jpeg = cv2.imencode(".jpg", frame)
            if not ret:
                continue

            yield (
                b"--frame\r\n"
                b"Content-Type: image/jpeg\r\n\r\n" + jpeg.tobytes() + b"\r\n\r\n"
            )

    @app.route("/video_feed")
    def video_feed():
        return Response(
            gen(),
            mimetype="multipart/x-mixed-replace; boundary=frame",
        )

    return app


if __name__ == "__main__":
    print(f"Using model: {MODEL_PATH}")
    print(f"YOLO face model: {YOLO_FACE_MODEL_PATH}")
    print(f"Label order: {LABELS}")
    flask_app = create_app()
    ssl_context = None
    if USE_HTTPS:
        if SSL_CERT_PATH and SSL_KEY_PATH:
            ssl_context = (SSL_CERT_PATH, SSL_KEY_PATH)
            print(f"HTTPS enabled with cert: {SSL_CERT_PATH}")
        else:
            ssl_context = "adhoc"
            print("HTTPS enabled with adhoc self-signed certificate")

    protocol = "https" if ssl_context else "http"
    print(f"Open in browser: {protocol}://127.0.0.1:5000")

    flask_app.run(
        host="0.0.0.0",
        port=5000,
        debug=FLASK_DEBUG,
        use_reloader=FLASK_DEBUG,
        ssl_context=ssl_context,
    )
