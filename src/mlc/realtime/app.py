from __future__ import annotations

import os

from flask import Flask, Response, render_template, request, send_file

try:
    from supabase import Client, create_client
except ImportError:  # pragma: no cover - optional dependency
    Client = None
    create_client = None

try:
    from flask_cors import CORS
except ImportError:  # pragma: no cover - optional dependency
    CORS = None

try:
    from mlc.realtime.courseware import render_pdf_page
    from mlc.realtime.input import open_camera
    from mlc.realtime.llm.llm import StudentQuestionHandler
    from mlc.realtime.model import (
        detect_faces_yolo,
        load_inference_model,
        load_yolo_face_model,
        predict_emotions,
        preprocess_face,
        setup_gpu_memory_growth,
    )
    from mlc.realtime.output import iter_frames
    from mlc.realtime.settings import (
        CSV_PATH,
        CSV_WINDOW_SEC,
        SUPABASE_KEY,
        SUPABASE_STUDENT_ID,
        SUPABASE_STUDENT_NAME,
        SUPABASE_URL,
        DISABLE_CAMERA,
        FLASK_DEBUG,
        IMG_SIZE,
        LABELS,
        MODEL_PATH,
        PDF_NAME,
        PDF_PAGE_DEFAULT,
        PDF_PATH,
        SSL_CERT_PATH,
        SSL_KEY_PATH,
        SUPABASE_KEY,
        SUPABASE_STUDENT_ID,
        SUPABASE_STUDENT_NAME,
        SUPABASE_URL,
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
        detect_faces_yolo,
        load_inference_model,
        load_yolo_face_model,
        predict_emotions,
        preprocess_face,
        setup_gpu_memory_growth,
    )
    from mlc.realtime.output import iter_frames
    from mlc.realtime.settings import (
        CSV_PATH,
        CSV_WINDOW_SEC,
        SUPABASE_KEY,
        SUPABASE_STUDENT_ID,
        SUPABASE_STUDENT_NAME,
        SUPABASE_URL,
        DISABLE_CAMERA,
        FLASK_DEBUG,
        IMG_SIZE,
        LABELS,
        MODEL_PATH,
        PDF_NAME,
        PDF_PAGE_DEFAULT,
        PDF_PATH,
        SSL_CERT_PATH,
        SSL_KEY_PATH,
        SUPABASE_KEY,
        SUPABASE_STUDENT_ID,
        SUPABASE_STUDENT_NAME,
        SUPABASE_URL,
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
    cap_holder = None
    if not DISABLE_CAMERA:
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
    if CORS is not None:
        CORS(app)

    supabase_client: Client | None = None
    if SUPABASE_URL and SUPABASE_KEY and create_client is not None:
        try:
            supabase_client = create_client(SUPABASE_URL, SUPABASE_KEY)
            if SUPABASE_STUDENT_ID:
                supabase_client.table("students").upsert({
                    "id": SUPABASE_STUDENT_ID,
                    "name": SUPABASE_STUDENT_NAME,
                }).execute()
        except Exception:
            supabase_client = None

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

    @app.route("/infer", methods=["POST"])
    def infer():
        import base64
        import numpy as np
        import cv2
        from flask import jsonify
        from datetime import datetime, timezone

        data = request.get_json()
        if not data or "image" not in data:
            return jsonify({"error": "image required"}), 400
        try:
            image_bytes = base64.b64decode(data["image"])
            nparr = np.frombuffer(image_bytes, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            if os.environ.get("DAISEE_DEBUG_FRAME", "0") == "1":
                # Save the received frame for debugging.
                debug_dir = os.path.join(os.getcwd(), "outputs", "debug_frames")
                os.makedirs(debug_dir, exist_ok=True)
                ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S_%f")
                debug_path = os.path.join(debug_dir, f"frame_{ts}.jpg")
                if frame is not None:
                    cv2.imwrite(debug_path, frame)
                else:
                    with open(debug_path + ".txt", "w", encoding="utf-8") as f:
                        f.write("frame decode failed")
            if frame is None:
                # No frame available: return None values and skip DB writes.
                return jsonify({
                    "focus_score": None,
                    "state": "unknown",
                    "engagement": None,
                    "boredom": None,
                    "confusion": None,
                    "frustration": None,
                    "samples": None,
                    "pdf_page": int(data.get("page", 1) or 1),
                    "pdf_name": PDF_NAME,
                })
            faces = detect_faces_yolo(yolo_face_model, frame, YOLO_CONFIDENCE, YOLO_IOU)
            if not faces:
                # No face detected: return None values and skip DB writes.
                return jsonify({
                    "focus_score": None,
                    "state": "absent",
                    "engagement": None,
                    "boredom": None,
                    "confusion": None,
                    "frustration": None,
                    "samples": None,
                    "pdf_page": int(data.get("page", 1) or 1),
                    "pdf_name": PDF_NAME,
                })
            face_tensor = preprocess_face(frame, faces[0], IMG_SIZE)
            emotions = predict_emotions(model, face_tensor)
            focus_score = float(emotions.flatten()[0])
            state = "focused" if focus_score >= 0.6 else "confused"
            engagement = float(focus_score)
            boredom = float(emotions.flatten()[1]) if emotions.size > 1 else 0.0
            confusion = float(emotions.flatten()[2]) if emotions.size > 2 else 0.0
            frustration = float(emotions.flatten()[3]) if emotions.size > 3 else 0.0
            samples = 1
            pdf_page = int(data.get("page", 1) or 1)

            if supabase_client is not None and SUPABASE_STUDENT_ID and not data.get("client_write"):
                supabase_client.table("engagement_metrics").insert({
                    "student_id": SUPABASE_STUDENT_ID,
                    "timestamp": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
                    "engagement": engagement,
                    "boredom": boredom,
                    "confusion": confusion,
                    "frustration": frustration,
                    "samples": samples,
                    "pdf_page": pdf_page,
                    "pdf_name": PDF_NAME,
                }).execute()
            return jsonify({
                "focus_score": round(focus_score, 3),
                "state": state,
                "engagement": engagement,
                "boredom": boredom,
                "confusion": confusion,
                "frustration": frustration,
                "samples": samples,
                "pdf_page": pdf_page,
                "pdf_name": PDF_NAME,
            })
        except Exception as e:
            return jsonify({"error": str(e), "focus_score": 0.5, "state": "unknown"}), 500

    @app.route("/video_feed")
    def video_feed():
        if DISABLE_CAMERA or cap_holder is None:
            return Response("Camera disabled", status=404)
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
                supabase_url=SUPABASE_URL,
                supabase_key=SUPABASE_KEY,
                student_id=SUPABASE_STUDENT_ID,
                student_name=SUPABASE_STUDENT_NAME,
                img_size=IMG_SIZE,
                yolo_confidence=YOLO_CONFIDENCE,
                yolo_iou=YOLO_IOU,
                camera_index=0,
            ),
            mimetype="multipart/x-mixed-replace; boundary=frame",
        )

    @app.route("/infer_debug", methods=["POST"])
    def infer_debug():
        """Debug endpoint: create a fresh Supabase client and attempt to insert the
        same payload that /infer would insert, returning the PostgREST response.
        This helps check whether the server key in environment is accepted.
        """
        from datetime import datetime, timezone

        data = request.get_json() or {}
        page = int(data.get("page", 1) or 1)

        if not SUPABASE_URL or not SUPABASE_KEY:
            return jsonify({"error": "SUPABASE_URL/SUPABASE_KEY not set"}), 400

        try:
            client = create_client(SUPABASE_URL, SUPABASE_KEY)
        except Exception as exc:
            return jsonify({"error": f"create_client failed: {exc}"}), 500

        try:
            res = client.table("engagement_metrics").insert({
                "student_id": SUPABASE_STUDENT_ID,
                "timestamp": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
                "engagement": None,
                "boredom": None,
                "confusion": None,
                "frustration": None,
                "samples": None,
                "pdf_page": page,
                "pdf_name": PDF_NAME,
            }).execute()
            # Attempt to return a compact summary of the response
            return jsonify({
                "status": getattr(res, "status_code", None) or getattr(res, "status", None),
                "data": getattr(res, "data", None),
                "error": getattr(res, "error", None),
            })
        except Exception as exc:
            return jsonify({"error": str(exc)}), 500

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
        port=5001,
        debug=FLASK_DEBUG,
        use_reloader=FLASK_DEBUG,
        ssl_context=None, 
    )


if __name__ == "__main__":
    run_flask_app()
