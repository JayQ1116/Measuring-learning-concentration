from __future__ import annotations

import csv
import datetime
import os
import time
from io import BytesIO
from collections import defaultdict
from typing import Any, Iterable, Tuple

import cv2
import numpy as np
from flask import Flask, Response, jsonify, request, send_file

try:
    from mlc.config import PipelineConfig
    from mlc.realtime.courseware import PdfCoursewareViewer
    from mlc.realtime.input import close_camera, open_camera, read_camera_frame
    from mlc.realtime.llm.llm import StudentQuestionHandler
    from mlc.realtime.model import (
        detect_faces_yolo,
        classify_state,
        load_inference_model,
        load_yolo_face_model,
        predict_emotions,
        preprocess_face,
        sliding_window,
        setup_gpu_memory_growth,
    )
    from mlc.realtime.output import (
        CsvWindowAverager,
        build_teacher_payload,
        draw_student_ui,
        init_student_window,
        read_key,
        set_student_window_mode,
        set_student_window_topmost,
        show_student_ui,
    )
    from mlc.realtime.teacher import generate_teacher_report, update_server_state
except ImportError:
    import sys

    CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
    SRC_DIR = os.path.dirname(os.path.dirname(CURRENT_DIR))
    if SRC_DIR not in sys.path:
        sys.path.insert(0, SRC_DIR)

    from mlc.config import PipelineConfig
    from mlc.realtime.courseware import PdfCoursewareViewer
    from mlc.realtime.input import close_camera, open_camera, read_camera_frame
    from mlc.realtime.llm.llm import StudentQuestionHandler
    from mlc.realtime.model import (
        detect_faces_yolo,
        classify_state,
        load_inference_model,
        load_yolo_face_model,
        predict_emotions,
        preprocess_face,
        sliding_window,
        setup_gpu_memory_growth,
    )
    from mlc.realtime.output import (
        CsvWindowAverager,
        build_teacher_payload,
        draw_student_ui,
        init_student_window,
        read_key,
        set_student_window_mode,
        set_student_window_topmost,
        show_student_ui,
    )
    from mlc.realtime.teacher import generate_teacher_report, update_server_state


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
FLASK_DEBUG = os.environ.get("DAISEE_FLASK_DEBUG", "0") == "1"
CSV_PATH = os.environ.get("DAISEE_CSV_PATH", "outputs/engagement_metrics.csv")
CSV_WINDOW_SEC = float(os.environ.get("DAISEE_CSV_WINDOW_SEC", "5"))
DEFAULT_PDF_PATH = PipelineConfig().pdf_path
PDF_PATH = os.environ.get("DAISEE_PDF_PATH", DEFAULT_PDF_PATH)
PDF_PAGE_DEFAULT = int(os.environ.get("DAISEE_PDF_PAGE", str(PipelineConfig().current_page)))
PDF_NAME = os.path.basename(PDF_PATH)


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


def build_index_html(pdf_page: int) -> str:
    return (
        "<!DOCTYPE html>"
        "<html lang=\"en\">"
        "<head>"
        "<meta charset=\"UTF-8\" />"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />"
        "<title>DAISEE Live View</title>"
        "<style>"
        "body{margin:0;font-family:Segoe UI,Tahoma,Geneva,Verdana,sans-serif;"
        "background:#0f172a;color:#e2e8f0;min-height:100vh;}"
        ".layout{display:grid;grid-template-columns:1.2fr 1fr;gap:20px;"
        "padding:24px;min-height:100vh;box-sizing:border-box;}"
        ".card{background:#111827;border:1px solid #1f2937;border-radius:12px;"
        "padding:20px;box-shadow:0 20px 40px rgba(0,0,0,0.35);}"
        "h1{margin:0 0 12px;font-size:22px;font-weight:600;}"
        "p{margin:0 0 16px;color:#94a3b8;}"
        "img{width:100%;border-radius:8px;border:1px solid #1f2937;background:#0b1120;}"
        ".pdf-toolbar{display:flex;gap:12px;align-items:center;margin-bottom:12px;}"
        ".pdf-toolbar button{background:#1e293b;color:#e2e8f0;border:1px solid #334155;"
        "padding:8px 12px;border-radius:8px;cursor:pointer;}"
        ".pdf-toolbar input{width:72px;background:#0b1120;border:1px solid #334155;"
        "color:#e2e8f0;border-radius:8px;padding:6px 8px;}"
        ".pdf-toolbar .status{color:#94a3b8;font-size:14px;}"
        "iframe{width:100%;height:100%;min-height:420px;border-radius:8px;"
        "border:1px solid #1f2937;background:#0b1120;}"
        ".qa{margin-top:16px;display:flex;flex-direction:column;gap:10px;}"
        ".qa textarea{width:100%;min-height:90px;background:#0b1120;color:#e2e8f0;"
        "border:1px solid #334155;border-radius:8px;padding:8px;resize:vertical;}"
        ".qa button{align-self:flex-start;background:#2563eb;color:#f8fafc;"
        "border:0;border-radius:8px;padding:8px 14px;cursor:pointer;}"
        ".qa .answer{white-space:pre-wrap;background:#0b1120;border:1px solid #334155;"
        "border-radius:8px;padding:10px;min-height:48px;color:#e2e8f0;}"
        "@media (max-width: 980px){.layout{grid-template-columns:1fr;}}"
        "</style>"
        "</head>"
        "<body>"
        "<div class=\"layout\">"
        "<div class=\"card\">"
        "<h1>DAISEE Live View</h1>"
        "<p>Streaming from the local camera. If the frame is blank, refresh the page.</p>"
        "<img src=\"/video_feed\" alt=\"Live video stream\" />"
        "</div>"
        "<div class=\"card\">"
        "<h1>Courseware PDF</h1>"
        "<div class=\"pdf-toolbar\">"
        "<button type=\"button\" onclick=\"changePage(-1)\">Prev</button>"
        "<button type=\"button\" onclick=\"changePage(1)\">Next</button>"
        f"<input id=\"pageInput\" type=\"number\" min=\"1\" value=\"{pdf_page}\" />"
        "<button type=\"button\" onclick=\"goToPage()\">Go</button>"
        f"<span class=\"status\">Page <span id=\"pageLabel\">{pdf_page}</span></span>"
        "</div>"
        f"<iframe id=\"pdfFrame\" src=\"/pdf#page={pdf_page}\" title=\"Courseware PDF\"></iframe>"
        "<div class=\"qa\">"
        "<label for=\"questionInput\">Ask a question</label>"
        "<label><input id=\"usePage\" type=\"checkbox\" checked /> Use current PDF page</label>"
        "<textarea id=\"questionInput\" placeholder=\"Type your question...\"></textarea>"
        "<button type=\"button\" onclick=\"askQuestion()\">Ask</button>"
        "<div id=\"answerBox\" class=\"answer\"></div>"
        "</div>"
        "</div>"
        "</div>"
        "<script>"
        "const pageLabel = document.getElementById('pageLabel');"
        "const pageInput = document.getElementById('pageInput');"
        "const pdfFrame = document.getElementById('pdfFrame');"
        "const usePage = document.getElementById('usePage');"
        "function setPage(page){"
        "const nextPage = Math.max(1, Number(page) || 1);"
        "pageInput.value = nextPage;"
        "pageLabel.textContent = nextPage;"
        "pdfFrame.src = `/pdf?ts=${Date.now()}#page=${nextPage}`;"
        "fetch(`/set_page?page=${nextPage}`);"
        "}"
        "function changePage(delta){"
        "setPage((Number(pageInput.value) || 1) + delta);"
        "}"
        "function goToPage(){"
        "setPage(pageInput.value);"
        "}"
        "let activeStream = null;"
        "function askQuestion(){"
        "const answerBox = document.getElementById('answerBox');"
        "const question = document.getElementById('questionInput').value.trim();"
        "if(!question){answerBox.textContent = 'Please enter a question.';return;}"
        "if(activeStream){activeStream.close();}"
        "answerBox.textContent = '';"
        "const page = Number(pageInput.value) || 1;"
        "const includePage = usePage.checked ? 1 : 0;"
        "const url = `/ask_stream?question=${encodeURIComponent(question)}&page=${page}&include_page=${includePage}`;"
        "const stream = new EventSource(url);"
        "activeStream = stream;"
        "stream.onmessage = (evt) => {"
        "if(evt.data === '[DONE]'){stream.close();return;}"
        "answerBox.textContent += evt.data;"
        "};"
        "stream.onerror = () => {"
        "answerBox.textContent += '\n[stream error]';"
        "stream.close();"
        "};"
        "}"
        "</script>"
        "</body>"
        "</html>"
    )


def render_pdf_page(pdf_path: str, page: int) -> bytes:
    try:
        from pdf2image import convert_from_path
    except ImportError as exc:
        raise RuntimeError("pdf2image is required for PDF screenshots") from exc

    images = convert_from_path(pdf_path, first_page=page, last_page=page)
    if not images:
        raise RuntimeError("Failed to render PDF page")

    buffer = BytesIO()
    images[0].save(buffer, format="PNG")
    return buffer.getvalue()


def iter_frames(
    model: Any,
    yolo_face_model: Any,
    cap_holder: dict,
    page_state: dict,
) -> Iterable[bytes]:
    csv_dir = os.path.dirname(CSV_PATH)
    if csv_dir:
        os.makedirs(csv_dir, exist_ok=True)

    csv_exists = os.path.exists(CSV_PATH)
    csv_file = open(CSV_PATH, "a", newline="", encoding="utf-8")
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
                    reopened = open_camera(0)
                    cap_holder["cap"] = reopened
                continue
            failed_reads = 0

            faces = detect_faces_yolo(yolo_face_model, frame, YOLO_CONFIDENCE, YOLO_IOU)

            pred = None
            for box in faces:
                face_tensor = preprocess_face(frame, box, IMG_SIZE)
                pred = predict_emotions(model, face_tensor)
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

            if pred is not None:
                window_preds.append(pred.flatten())

            now = time.time()
            if now - window_start >= CSV_WINDOW_SEC:
                if window_preds:
                    avg = np.mean(window_preds, axis=0)
                    timestamp = datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
                    writer.writerow([
                        timestamp,
                        f"{avg[0]:.6f}",
                        f"{avg[1]:.6f}",
                        f"{avg[2]:.6f}",
                        f"{avg[3]:.6f}",
                        str(len(window_preds)),
                        str(page_state.get("page", PDF_PAGE_DEFAULT)),
                        PDF_NAME,
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


def emotion_to_focus_score(emotions: np.ndarray) -> float:
    return float(emotions.flatten()[0])


def run_student_camera_loop(config: PipelineConfig | None = None) -> None:
    if config is None:
        config = PipelineConfig()

    setup_gpu_memory_growth()

    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(f"Model not found: {MODEL_PATH}")

    model = load_inference_model(MODEL_PATH, IMG_SIZE)
    yolo_face_model = load_yolo_face_model(YOLO_FACE_MODEL_PATH)

    cap = open_camera(config.camera_index)
    window_size = config.window_seconds * config.fps
    predictions_history: list[Tuple[float, str]] = []
    confusion_counts: dict[int, int] = defaultdict(int)
    last_sync_time = time.time()
    current_state = "compact"
    topmost = config.student_window_topmost

    init_student_window(config)
    llm_handler = StudentQuestionHandler()
    csv_averager = CsvWindowAverager(config.csv_path, config.csv_window_seconds)

    pdf_viewer = PdfCoursewareViewer(config.pdf_path, config.pdf_window_name)
    print(f"PDF source: {config.pdf_path} | loaded: {pdf_viewer.is_available}")

    print(f"System initialized. Student ID: {config.student_id}")
    print(
        "Hotkeys: "
        f"{config.ask_llm_key}=ask LLM, {config.next_page_key}/{config.prev_page_key}=next/prev page, "
        f"{config.toggle_window_key}=toggle student window size, "
        f"{config.toggle_topmost_key}=toggle topmost, {config.quit_key}=quit"
    )

    try:
        while cap.isOpened():
            ret, frame = read_camera_frame(cap)
            if not ret:
                break

            faces = detect_faces_yolo(yolo_face_model, frame, YOLO_CONFIDENCE, YOLO_IOU)
            if faces:
                face_tensor = preprocess_face(frame, faces[0], IMG_SIZE)
                emotions = predict_emotions(model, face_tensor)
                focus_score = emotion_to_focus_score(emotions)
                predictions_history.append((focus_score, "Engagement"))
                frame = draw_prediction(frame, faces[0], emotions)
            else:
                cv2.putText(
                    frame,
                    "No face detected",
                    (20, 35),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.9,
                    (0, 0, 255),
                    2,
                )

            if len(predictions_history) > window_size:
                predictions_history.pop(0)

            smooth_score = sliding_window(predictions_history, window_size)
            state = classify_state(smooth_score, config)
            csv_averager.add_sample(smooth_score, config.current_page)

            draw_student_ui(frame, config, smooth_score, state)
            show_student_ui(config.ui_window_name, frame)
            pdf_viewer.show()

            if time.time() - last_sync_time > config.sync_interval:
                payload = build_teacher_payload(
                    config,
                    smooth_score,
                    confusion_count_on_page=confusion_counts[config.current_page],
                )
                update_server_state(payload)
                generate_teacher_report(config)
                last_sync_time = time.time()

            key = read_key()
            if key == config.quit_key:
                break
            if key == config.ask_llm_key:
                question = input("\n[LLM] Ask your question: ").strip()
                if question:
                    response = llm_handler.handle(question, config.current_page, state)
                    print(response)
                    confusion_counts[config.current_page] += 1
            if key == config.next_page_key:
                pdf_viewer.next_page()
                config.current_page = pdf_viewer.current_page_number
            if key == config.prev_page_key:
                pdf_viewer.prev_page()
                config.current_page = pdf_viewer.current_page_number
            if key == config.toggle_window_key:
                current_state = "maximized" if current_state == "compact" else "compact"
                set_student_window_mode(config, current_state)
                print(f"[UI] Student camera window mode: {current_state}")
            if key == config.toggle_topmost_key:
                topmost = not topmost
                set_student_window_topmost(config.ui_window_name, topmost)
                print(f"[UI] Student camera topmost: {topmost}")
    finally:
        csv_averager.close()
        pdf_viewer.close()
        close_camera(cap)


def create_app() -> Flask:
    setup_gpu_memory_growth()

    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(f"Model not found: {MODEL_PATH}")

    model = load_inference_model(MODEL_PATH, IMG_SIZE)
    yolo_face_model = load_yolo_face_model(YOLO_FACE_MODEL_PATH)
    cap_holder = {"cap": open_camera(0)}
    if not cap_holder["cap"].isOpened():
        raise RuntimeError("Failed to open camera device 0")

    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    pdf_path = PDF_PATH
    if not os.path.isabs(pdf_path):
        pdf_path = os.path.join(base_dir, pdf_path)

    page_state = {"page": PDF_PAGE_DEFAULT}
    llm_handler = StudentQuestionHandler()

    app = Flask(__name__)

    @app.route("/")
    def index():
        return build_index_html(page_state["page"])

    @app.route("/set_page")
    def set_page():
        page = request.args.get("page", type=int)
        if page is not None and page > 0:
            page_state["page"] = page
        return "ok"

    @app.route("/ask_stream")
    def ask_stream():
        question = request.args.get("question", "").strip()
        page = request.args.get("page", type=int)
        include_page = request.args.get("include_page", "1") == "1"
        if not question:
            return Response("data: Question is required.\n\n", mimetype="text/event-stream")

        if page is None or page < 1:
            page = page_state.get("page", PDF_PAGE_DEFAULT)

        if not include_page:
            page = 0

        try:
            image_bytes = render_pdf_page(pdf_path, page) if include_page else None
        except Exception as exc:
            return Response(
                f"data: {str(exc)}\n\ndata: [DONE]\n\n",
                mimetype="text/event-stream",
            )

        def generate():
            try:
                for chunk in llm_handler.stream_with_image(
                    question,
                    page,
                    "Web",
                    image_bytes,
                ):
                    for line in chunk.splitlines() or [""]:
                        yield f"data: {line}\n\n"
            except Exception as exc:
                yield f"data: {str(exc)}\n\n"
            yield "data: [DONE]\n\n"

        headers = {
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        }
        return Response(generate(), headers=headers, mimetype="text/event-stream")

    @app.route("/pdf")
    def pdf():
        response = send_file(
            pdf_path,
            mimetype="application/pdf",
            as_attachment=False,
            download_name=os.path.basename(pdf_path),
            conditional=True,
        )
        response.headers["Content-Disposition"] = "inline"
        return response

    @app.route("/video_feed")
    def video_feed():
        return Response(
            iter_frames(model, yolo_face_model, cap_holder, page_state),
            mimetype="multipart/x-mixed-replace; boundary=frame",
        )

    return app


def run_flask_app() -> None:
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


def run_realtime_pipeline(config: PipelineConfig | None = None) -> None:
    run_student_camera_loop(config)


if __name__ == "__main__":
    run_flask_app()
