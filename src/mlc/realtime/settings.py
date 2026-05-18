from __future__ import annotations

import os

try:
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover - optional dependency
    load_dotenv = None

if load_dotenv is not None:
    load_dotenv()

from ..config import PipelineConfig

MODEL_PATH = os.environ.get(
    "DAISEE_H5_MODEL",
    "src/mlc/realtime/models/daisee_engagement_model_final.h5",
)
YOLO_FACE_MODEL_PATH = os.environ.get(
    "DAISEE_YOLO_FACE_MODEL",
    "src/mlc/realtime/models/yolov8n-face.pt",
)
YOLO_CONFIDENCE = float(os.environ.get("DAISEE_YOLO_CONF", "0.35"))
YOLO_IOU = float(os.environ.get("DAISEE_YOLO_IOU", "0.45"))
IMG_SIZE = (224, 224)
LABELS = ["Engagement", "Boredom", "Confusion", "Frustration"]
USE_HTTPS = os.environ.get("DAISEE_USE_HTTPS", "1") == "1"
SSL_CERT_PATH = os.environ.get("DAISEE_SSL_CERT", "")
SSL_KEY_PATH = os.environ.get("DAISEE_SSL_KEY", "")
FLASK_DEBUG = os.environ.get("DAISEE_FLASK_DEBUG", "0") == "1"
CSV_PATH = os.environ.get("DAISEE_CSV_PATH", "outputs/engagement_metrics.csv")
CSV_WINDOW_SEC = float(os.environ.get("DAISEE_CSV_WINDOW_SEC", "5"))
DEFAULT_PDF_PATH = PipelineConfig().pdf_path
PDF_PATH = os.environ.get("DAISEE_PDF_PATH", DEFAULT_PDF_PATH)
PDF_PAGE_DEFAULT = int(os.environ.get("DAISEE_PDF_PAGE", str(PipelineConfig().current_page)))
PDF_NAME = os.path.basename(PDF_PATH)
SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", os.environ.get("SUPABASE_KEY", ""))
SUPABASE_STUDENT_ID = os.environ.get("SUPABASE_STUDENT_ID", "")
SUPABASE_STUDENT_NAME = os.environ.get("SUPABASE_STUDENT_NAME", "신규림")
