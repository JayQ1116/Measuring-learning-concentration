# ============================================================
# gemini_server.py
# Gemini 멀티모달 API 서버 (Flask)
# 실행: python gemini_server.py
# 요구사항: pip install flask google-generativeai flask-cors
# ============================================================

import base64
import os
import socket
from flask import Flask, request, jsonify
from flask_cors import CORS
import google.generativeai as genai

app = Flask(__name__)
CORS(app)  # Flutter 앱에서 CORS 허용

def get_server_port():
    preferred_port = int(os.environ.get("PORT", "5000"))
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            sock.bind(("0.0.0.0", preferred_port))
            return preferred_port
        except OSError:
            sock.bind(("0.0.0.0", 0))
            return sock.getsockname()[1]

# API 키 설정 (.env 파일 또는 환경변수)
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "YOUR_GEMINI_API_KEY_HERE")
genai.configure(api_key=GEMINI_API_KEY)

model = genai.GenerativeModel("gemini-1.5-flash")

SYSTEM_PROMPT = """당신은 학생의 학습을 돕는 친절한 AI 助手입니다.
학생이 PDF 강의 자료를 읽다가 모르는 내용을 질문할 때 도움을 줍니다.
- 간결하고 명확하게 설명하세요 (300자 이내 권장)
- 어려운 개념은 쉬운 예시로 설명하세요
- 한국어로 답변하세요
- 학생을 격려하는 톤을 유지하세요"""


@app.route("/health", methods=["GET"])
def health():
    """서버 상태 확인"""
    return jsonify({"status": "ok", "model": "gemini-1.5-flash"})


@app.route("/ask", methods=["POST"])
def ask():
    """
    Flutter 앱에서 질문 수신 및 Gemini 응답 반환
    
    Request body (JSON):
    {
        "question": "질문 텍스트",
        "pdf_name": "파일명.pdf",
        "page_number": 3,
        "page_image": "base64_encoded_image"  // 선택사항
    }
    
    Response:
    {
        "answer": "Gemini의 답변",
        "page_number": 3
    }
    """
    data = request.get_json()
    if not data:
        return jsonify({"error": "JSON body required"}), 400

    question = data.get("question", "").strip()
    if not question:
        return jsonify({"error": "question is required"}), 400

    pdf_name = data.get("pdf_name", "강의 자료")
    page_number = data.get("page_number", 1)
    page_image_b64 = data.get("page_image")  # 선택사항

    # ── 프롬프트 구성 ──
    context_prompt = (
        f"{SYSTEM_PROMPT}\n\n"
        f"학생은 현재 《{pdf_name}》의 {page_number}페이지를 공부하고 있습니다.\n"
        f"학생의 질문: {question}"
    )

    # ── Gemini 호출 ──
    try:
        parts = [context_prompt]

        # 페이지 이미지가 있으면 멀티모달로 전송
        if page_image_b64:
            try:
                image_bytes = base64.b64decode(page_image_b64)
                parts.append({
                    "mime_type": "image/jpeg",
                    "data": image_bytes
                })
            except Exception as e:
                print(f"[Image decode error] {e}")
                # 이미지 디코드 실패해도 텍스트로만 진행

        response = model.generate_content(parts)
        answer = response.text

        return jsonify({
            "answer": answer,
            "page_number": page_number
        })

    except Exception as e:
        print(f"[Gemini Error] {e}")
        return jsonify({
            "error": str(e),
            "answer": f"죄송합니다, 응답을 생성하는 중 오류가 발생했습니다: {str(e)}"
        }), 500


@app.route("/summarize_page", methods=["POST"])
def summarize_page():
    """
    특정 페이지 자동 요약 (선택 기능)
    AI 간섭 기포에서 '도움받기' 클릭 시 사용 가능
    """
    data = request.get_json()
    pdf_name = data.get("pdf_name", "강의 자료")
    page_number = data.get("page_number", 1)
    page_image_b64 = data.get("page_image")

    prompt = (
        f"《{pdf_name}》 {page_number}페이지의 핵심 내용을 "
        f"3~5개의 bullet point로 간단히 요약해주세요. "
        f"학생이 이해하기 쉽도록 설명해주세요."
    )

    try:
        parts = [prompt]
        if page_image_b64:
            image_bytes = base64.b64decode(page_image_b64)
            parts.append({"mime_type": "image/jpeg", "data": image_bytes})

        response = model.generate_content(parts)
        return jsonify({"summary": response.text, "page_number": page_number})

    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    port = get_server_port()
    print("=" * 50)
    print("Gemini 학습 도우미 서버 시작")
    print(f"  주소: http://0.0.0.0:{port}")
    print(f"  API 키: {'설정됨' if GEMINI_API_KEY != 'YOUR_GEMINI_API_KEY_HERE' else '⚠️ 미설정'}")
    print("=" * 50)
    app.run(host="0.0.0.0", port=port, debug=False)
