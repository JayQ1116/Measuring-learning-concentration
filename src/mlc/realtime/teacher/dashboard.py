from __future__ import annotations

from collections import defaultdict
from typing import Dict, List

from ...config import PipelineConfig
from ..model import classify_state

# Simulated server-side class state. Replace with DB/Redis in production.
GLOBAL_CLASS_DATA: Dict[str, Dict[str, object]] = {}


def update_server_state(payload: Dict[str, object]) -> None:
    student_id = str(payload["student_id"])
    GLOBAL_CLASS_DATA[student_id] = payload


def generate_teacher_report(config: PipelineConfig) -> None:
    if not GLOBAL_CLASS_DATA:
        print("\n[Teacher Dashboard] Waiting for students...")
        return

    page_summary: Dict[int, List[float]] = defaultdict(list)
    at_risk_students: List[str] = []
    low_focus_pages: set[int] = set()
    high_confusion_pages: set[int] = set()

    print("\n" + "=" * 45)
    print("   [TEACHER REAL-TIME DASHBOARD]")
    print(f"   Connected students: {len(GLOBAL_CLASS_DATA)}")

    for student_id, data in GLOBAL_CLASS_DATA.items():
        score = float(data["focus_score"])
        page = int(data["page"])
        confusion_count = int(data.get("confusion_count_on_page", 0))
        state = classify_state(score, config)

        if score <= config.slight_distracted_threshold:
            at_risk_students.append(f"{student_id}({state})")
            low_focus_pages.add(page)

        if confusion_count >= config.confusion_high_threshold:
            high_confusion_pages.add(page)

        page_summary[page].append(score)
        print(
            f"   - Student[{student_id}]: score {score:.2f} | state {state} "
            f"| confusion(page) {confusion_count}"
        )

    print("\n   [Page Heatmap]")
    for page, scores in page_summary.items():
        avg_score = sum(scores) / len(scores)
        if avg_score > config.focused_threshold:
            color = "Green"
        elif avg_score > config.slight_distracted_threshold:
            color = "Yellow"
        else:
            color = "Red"
        print(f"     Page {page}: avg {avg_score:.2f} -> {color}")

    if at_risk_students:
        print(f"\n   Warning students: {at_risk_students}")

    print("\n   [Teaching Attention Pages]")
    print(f"   - Low focus pages: {sorted(low_focus_pages) if low_focus_pages else []}")
    print(
        "   - High confusion pages: "
        f"{sorted(high_confusion_pages) if high_confusion_pages else []}"
    )

    print("=" * 45)
