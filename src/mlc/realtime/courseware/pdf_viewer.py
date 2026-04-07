from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np

try:
    import fitz
except ImportError:  # pragma: no cover
    fitz = None


class PdfCoursewareViewer:
    def __init__(self, pdf_path: str, window_name: str) -> None:
        self.window_name = window_name
        self.pdf_path = Path(pdf_path)
        self._doc = None
        self._page_index = 0

        if fitz is not None and self.pdf_path.exists():
            self._doc = fitz.open(self.pdf_path)

    @property
    def is_available(self) -> bool:
        return self._doc is not None

    @property
    def current_page_number(self) -> int:
        return self._page_index + 1

    def next_page(self) -> None:
        if self._doc is None:
            return
        self._page_index = min(self._page_index + 1, len(self._doc) - 1)

    def prev_page(self) -> None:
        if self._doc is None:
            return
        self._page_index = max(self._page_index - 1, 0)

    def show(self) -> None:
        frame = self._render_current_page()
        cv2.imshow(self.window_name, frame)

    def close(self) -> None:
        if self._doc is not None:
            self._doc.close()
        try:
            cv2.destroyWindow(self.window_name)
        except Exception:
            pass

    def _render_current_page(self):
        if self._doc is None:
            frame = np.zeros((360, 640, 3), dtype=np.uint8)
            cv2.putText(
                frame,
                "PDF unavailable. Put file path in config.pdf_path",
                (20, 170),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.5,
                (0, 180, 255),
                1,
            )
            cv2.putText(
                frame,
                "Install pymupdf and ensure file exists.",
                (20, 195),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.5,
                (0, 180, 255),
                1,
            )
            return frame

        page = self._doc.load_page(self._page_index)
        pix = page.get_pixmap(matrix=fitz.Matrix(1.2, 1.2), alpha=False)

        img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, pix.n)
        if pix.n == 4:
            img = cv2.cvtColor(img, cv2.COLOR_RGBA2BGR)
        else:
            img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)

        cv2.putText(
            img,
            f"Page {self.current_page_number}",
            (20, 30),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (0, 0, 255),
            2,
        )
        return img
