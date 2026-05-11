from __future__ import annotations

import base64
import json
import os
import time
from typing import Iterable, Optional

import requests


def load_dotenv(path: str = ".env") -> None:
	if not os.path.exists(path):
		return

	with open(path, "r", encoding="utf-8") as handle:
		for raw_line in handle:
			line = raw_line.strip()
			if not line or line.startswith("#"):
				continue
			if "=" not in line:
				continue
			key, value = line.split("=", 1)
			key = key.strip()
			value = value.strip().strip("\"'")
			if key and key not in os.environ:
				os.environ[key] = value


load_dotenv()


class StudentQuestionHandler:
	def __init__(
		self,
		api_key: Optional[str] = None,
		model: Optional[str] = None,
		timeout_sec: int = 30,
		max_retries: int = 3,
	) -> None:
		self.api_key = api_key or os.environ.get("GEMINI_API_KEY", "")
		self.model = model or os.environ.get("GEMINI_MODEL", "gemini-1.5-flash")
		self.timeout_sec = timeout_sec
		self.max_retries = max_retries

		if not self.api_key:
			raise ValueError("GEMINI_API_KEY is required")

	def handle(self, question: str, page: int, state: str) -> str:
		prompt = (
			"You are a helpful tutor. Answer the student's question briefly. "
			f"Current page: {page}. Student state: {state}. Question: {question}"
		)

		model_name = self._normalize_model(self.model)
		url = (
			"https://generativelanguage.googleapis.com/v1beta/models/"
			f"{model_name}:generateContent?key={self.api_key}"
		)
		payload = {
			"contents": [
				{
					"role": "user",
					"parts": [{"text": prompt}],
				}
			]
		}

		data = self._post_with_retry(url, payload)

		return _extract_text(data)

	def stream_with_image(
		self,
		question: str,
		page: int,
		state: str,
		image_bytes: Optional[bytes],
	) -> Iterable[str]:
		prompt = (
			"You are a helpful tutor. Answer the student's question briefly. "
			f"Current page: {page}. Student state: {state}. Question: {question}"
		)

		model_name = self._normalize_model(self.model)
		url = (
			"https://generativelanguage.googleapis.com/v1beta/models/"
			f"{model_name}:streamGenerateContent?key={self.api_key}"
		)
		parts = [{"text": prompt}]
		if image_bytes:
			encoded = base64.b64encode(image_bytes).decode("ascii")
			parts.append({
				"inline_data": {
					"mime_type": "image/png",
					"data": encoded,
				}
			})

		payload = {
			"contents": [
				{
					"role": "user",
					"parts": parts,
				}
			]
		}

		response = requests.post(
			url,
			json=payload,
			timeout=self.timeout_sec,
			stream=True,
		)
		response.raise_for_status()

		for line in response.iter_lines(decode_unicode=True):
			if not line:
				continue
			if line.startswith("data:"):
				line = line[len("data:"):].strip()
			if line == "[DONE]":
				break
			try:
				data = json.loads(line)
			except json.JSONDecodeError:
				continue
			chunk = _extract_text(data)
			if chunk:
				yield chunk

	@staticmethod
	def _normalize_model(model: str) -> str:
		return model.replace("models/", "", 1) if model.startswith("models/") else model

	def _post_with_retry(self, url: str, payload: dict) -> dict:
		last_error: Optional[Exception] = None
		for attempt in range(self.max_retries + 1):
			try:
				response = requests.post(url, json=payload, timeout=self.timeout_sec)
				if response.status_code in (429, 503, 504):
					raise requests.HTTPError(
						f"{response.status_code} Server is busy",
						response=response,
					)
				response.raise_for_status()
				return response.json()
			except requests.HTTPError as exc:
				last_error = exc
				status = getattr(exc.response, "status_code", None)
				if status not in (429, 503, 504):
					raise
				if attempt >= self.max_retries:
					break
				backoff = min(2 ** attempt, 8)
				time.sleep(backoff)
			except requests.RequestException as exc:
				last_error = exc
				if attempt >= self.max_retries:
					break
				backoff = min(2 ** attempt, 8)
				time.sleep(backoff)

		if last_error:
			raise last_error
		raise RuntimeError("LLM request failed after retries")


def _extract_text(data: dict) -> str:
	candidates = data.get("candidates") or []
	if not candidates:
		return "No response from model."

	content = candidates[0].get("content") or {}
	parts = content.get("parts") or []
	for part in parts:
		text = part.get("text")
		if text:
			return text
	return json.dumps(data, ensure_ascii=True)
