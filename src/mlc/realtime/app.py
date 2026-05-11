from __future__ import annotations

import os

from flask import Flask, Response, render_template, request, send_file

try:
    from mlc.realtime.courseware import render_pdf_page
    from mlc.realtime.input import open_camera
    from mlc.realtime.llm.llm import StudentQuestionHandler
    from mlc.realtime.model import (
        load_inference_model,
        load_yolo_face_model,
        setup_gpu_memory_growth,
    )
    from mlc.realtime.output import iter_frames
    from mlc.realtime.settings import (
        CSV_PATH,
        CSV_WINDOW_SEC,
        FLASK_DEBUG,
        IMG_SIZE,
        LABELS,
        MODEL_PATH,
        PDF_NAME,
        PDF_PAGE_DEFAULT,
        PDF_PATH,
        SSL_CERT_PATH,
        SSL_KEY_PATH,
        USE_HTTPS,
        YOLO_CONFIDENCE,
        YOLO_FACE_MODEL_PATH,
        YOLO_IOU,
    )
except ImportError:
    import sys

    CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
    SRC_DIR = os.path.dirname(os.path.dirname(CURRENT_DIR))
    if SRC_DIR not in sys.path:
        sys.path.insert(0, SRC_DIR)

    from mlc.realtime.courseware import render_pdf_page
    from mlc.realtime.input import open_camera
    from mlc.realtime.llm.llm import StudentQuestionHandler
    from mlc.realtime.model import (
        load_inference_model,
        load_yolo_face_model,
        setup_gpu_memory_growth,
    )
    from mlc.realtime.output import iter_frames
    from mlc.realtime.settings import (
        CSV_PATH,
        CSV_WINDOW_SEC,
        FLASK_DEBUG,
        IMG_SIZE,
        LABELS,
        MODEL_PATH,
        PDF_NAME,
        PDF_PAGE_DEFAULT,
        PDF_PATH,
        SSL_CERT_PATH,
        SSL_KEY_PATH,
        USE_HTTPS,
        YOLO_CONFIDENCE,
        YOLO_FACE_MODEL_PATH,
        YOLO_IOU,
    )


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

    app = Flask(
        __name__,
        template_folder=os.path.join(base_dir, "templates"),
    )

    @app.route("/")
    def index():
        return render_template("index.html", pdf_page=page_state["page"])

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
            iter_frames(
                model,
                yolo_face_model,
                cap_holder,
                page_state,
                csv_path=CSV_PATH,
                csv_window_sec=CSV_WINDOW_SEC,
                pdf_name=PDF_NAME,
                default_page=PDF_PAGE_DEFAULT,
                img_size=IMG_SIZE,
                yolo_confidence=YOLO_CONFIDENCE,
                yolo_iou=YOLO_IOU,
                camera_index=0,
            ),
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


if __name__ == "__main__":
    run_flask_app()
