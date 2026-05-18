# Backend API

This document lists the Flask backend endpoints used by the temporary web front-end.

## Base URL

- Default: `http://127.0.0.1:5000`
- If `DAISEE_USE_HTTPS=1`, the server runs on HTTPS (self-signed unless cert paths are provided).

## Endpoints

### GET /

- Description: Serve the live view front-end (video stream + PDF + Q&A).
- Response: HTML page.

### GET /video_feed

- Description: MJPEG stream of the local camera with YOLO face box + engagement scores.
- Response: `multipart/x-mixed-replace; boundary=frame`.
- Notes: Uses camera index `0` by default.

### GET /pdf

- Description: Serve the current PDF courseware file for the embedded viewer.
- Response: `application/pdf` (inline).

### GET /set_page

- Description: Update the server-side PDF page state.
- Query params:
  - `page` (int, required): Target page number (>= 1).
- Response: `ok`.

### GET /ask_stream

- Description: Stream LLM answers using Server-Sent Events (SSE).
- Query params:
  - `question` (string, required): Student question text.
  - `page` (int, optional): PDF page number to attach to the prompt.
  - `include_page` (0 or 1, optional, default `1`): Whether to include the page screenshot.
- Response: `text/event-stream`.
  - Data chunks are streamed as `data: <text>` lines.
  - Terminates with `data: [DONE]`.
- Errors: Returns a streamed error message (also in SSE format).

## Environment Variables

- `DAISEE_H5_MODEL`: Path to the engagement model (default `models/daisee_engagement_model_final.h5`).
- `DAISEE_YOLO_FACE_MODEL`: Path to YOLO face model (default `models/yolov8n-face.pt`).
- `DAISEE_YOLO_CONF`: YOLO confidence threshold (default `0.35`).
- `DAISEE_YOLO_IOU`: YOLO IoU threshold (default `0.45`).
- `DAISEE_PDF_PATH`: PDF path used by the web viewer.
- `DAISEE_PDF_PAGE`: Default page number on load.
- `DAISEE_CSV_PATH`: CSV output path for engagement metrics.
- `DAISEE_CSV_WINDOW_SEC`: CSV flush window in seconds.
- `DAISEE_USE_HTTPS`: Enable HTTPS (default `1`).
- `DAISEE_SSL_CERT`: Path to SSL certificate.
- `DAISEE_SSL_KEY`: Path to SSL key.
- `DAISEE_FLASK_DEBUG`: Enable Flask debug/reloader.

## LLM Configuration

The Q&A endpoint requires `GEMINI_API_KEY` (and optionally `GEMINI_MODEL`) in the environment.
