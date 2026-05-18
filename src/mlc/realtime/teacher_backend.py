from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional
from uuid import UUID

from flask import Flask, jsonify, request

try:
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover - optional dependency
    load_dotenv = None

try:
    from supabase import Client, create_client
except ImportError:  # pragma: no cover - optional dependency
    Client = None
    create_client = None


@dataclass
class CourseSummary:
    course_id: str
    name: str
    total_students: int
    active_students: int
    avg_focus: int
    is_live: bool


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _parse_ts(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _create_supabase_client() -> Optional["Client"]:
    url = os.environ.get("SUPABASE_URL", "").strip()
    key = os.environ.get("SUPABASE_KEY", "").strip()
    if not url or not key or create_client is None:
        return None
    return create_client(url, key)


def _mock_dashboard() -> Dict[str, Any]:
    courses = [
        {
            "course_id": "course-ml-1",
            "name": "머신러닝 기초",
            "total_students": 28,
            "active_students": 15,
            "avg_focus": 78,
            "is_live": True,
        },
        {
            "course_id": "course-dl-1",
            "name": "딥러닝 심화",
            "total_students": 32,
            "active_students": 24,
            "avg_focus": 85,
            "is_live": True,
        },
        {
            "course_id": "course-nlp-1",
            "name": "자연어 처리",
            "total_students": 26,
            "active_students": 18,
            "avg_focus": 88,
            "is_live": True,
        },
        {
            "course_id": "course-cv-1",
            "name": "컴퓨터 비전",
            "total_students": 30,
            "active_students": 0,
            "avg_focus": 0,
            "is_live": False,
        },
    ]

    total_students = sum(course["total_students"] for course in courses)
    active_students = sum(course["active_students"] for course in courses)
    live_courses = [course for course in courses if course["is_live"]]
    avg_focus = (
        round(sum(course["avg_focus"] for course in live_courses) / len(live_courses))
        if live_courses
        else 0
    )

    return {
        "teacher": {"name": "이수민 선생님"},
        "stats": {
            "total_courses": len(courses),
            "total_students": total_students,
            "active_students": active_students,
            "avg_focus": avg_focus,
        },
        "courses": courses,
    }


def _fetch_courses(client: "Client", teacher_id: str) -> List[Dict[str, Any]]:
    try:
        course_links = (
            client.table("course_teachers")
            .select("course_id")
            .eq("teacher_id", teacher_id)
            .execute()
        )
        course_ids = [row["course_id"] for row in (course_links.data or [])]
        if not course_ids:
            return []
        courses = (
            client.table("courses")
            .select("id,name")
            .in_("id", course_ids)
            .execute()
        )
        return courses.data or []
    except Exception:
        return []


def _fetch_course_students(
    client: "Client",
    course_id: str,
    teacher_id: str,
) -> List[str]:
    try:
        links = (
            client.table("course_students")
            .select("student_id")
            .eq("course_id", course_id)
            .execute()
        )
        return [row["student_id"] for row in (links.data or [])]
    except Exception:
        pass

    try:
        UUID(teacher_id)
    except ValueError:
        return []

    links = (
        client.table("teacher_students")
        .select("student_id")
        .eq("teacher_id", teacher_id)
        .execute()
    )
    return [row["student_id"] for row in (links.data or [])]


def _fetch_latest_metrics(
    client: "Client",
    student_ids: List[str],
    window_seconds: int,
) -> List[Dict[str, Any]]:
    if not student_ids:
        return []
    cutoff = (_now_utc() - timedelta(seconds=window_seconds)).isoformat()
    metrics = (
        client.table("engagement_metrics")
        .select("student_id,engagement,confusion,frustration,boredom,samples,pdf_page,pdf_name,timestamp")
        .in_("student_id", student_ids)
        .gte("timestamp", cutoff)
        .execute()
    )
    return metrics.data or []


def _summarize_course(
    course_id: str,
    name: str,
    metrics: List[Dict[str, Any]],
    student_count: int,
) -> CourseSummary:
    by_student: Dict[str, Dict[str, Any]] = {}
    for row in metrics:
        sid = row["student_id"]
        ts = _parse_ts(row["timestamp"])
        prev = by_student.get(sid)
        if prev is None or ts > prev["_ts"]:
            row_copy = dict(row)
            row_copy["_ts"] = ts
            by_student[sid] = row_copy

    active_students = len(by_student)
    avg_focus = 0
    if active_students:
        avg_focus = round(
            sum((row.get("engagement") or 0) for row in by_student.values())
            / active_students
            * 100
        )

    return CourseSummary(
        course_id=course_id,
        name=name,
        total_students=student_count,
        active_students=active_students,
        avg_focus=avg_focus,
        is_live=active_students > 0,
    )


def create_teacher_app() -> Flask:
    if load_dotenv is not None:
        load_dotenv()
    app = Flask(__name__)
    client = _create_supabase_client()

    @app.route("/")
    def index() -> Any:
        return (
            "<!doctype html>"
            "<html lang='en'>"
            "<head>"
            "<meta charset='utf-8'>"
            "<meta name='viewport' content='width=device-width, initial-scale=1'>"
            "<title>Teacher Backend</title>"
            "<style>"
            "body{font-family:Arial,Helvetica,sans-serif;background:#f5f7fb;color:#1f2a44;margin:0;padding:24px;}"
            "h1{font-size:20px;margin:0 0 12px 0;}"
            "code{background:#eef1f6;padding:2px 6px;border-radius:6px;}"
            "ul{padding-left:20px;}"
            "li{margin:6px 0;}"
            "</style>"
            "</head>"
            "<body>"
            "<h1>Teacher Backend is running</h1>"
            "<p>Try these endpoints (replace IDs):</p>"
            "<ul>"
            "<li><code>/api/health</code></li>"
            "<li><code>/api/teacher/demo-teacher/dashboard</code> (mock)</li>"
            "<li><code>/api/teacher/demo-teacher/courses/course-ml-1/live</code> (mock)</li>"
            "<li><code>/api/teacher/demo-teacher/courses/course-ml-1/heatmap</code> (mock)</li>"
            "<li><code>/api/teacher/&lt;teacher_uuid&gt;/courses/&lt;course_uuid&gt;/live</code></li>"
            "</ul>"
            "</body>"
            "</html>"
        )

    @app.route("/api/health")
    def health() -> Any:
        return jsonify({"ok": True, "supabase": client is not None})

    @app.route("/api/teacher/<teacher_id>/dashboard")
    def teacher_dashboard(teacher_id: str) -> Any:
        if client is None:
            return jsonify(_mock_dashboard())

        courses = _fetch_courses(client, teacher_id)
        if not courses:
            return jsonify(_mock_dashboard())

        summaries: List[Dict[str, Any]] = []
        total_students = 0
        active_students = 0
        avg_focus_values: List[int] = []

        for course in courses:
            course_id = course["id"]
            name = course["name"]
            student_ids = _fetch_course_students(client, course_id, teacher_id)
            total_students += len(student_ids)
            metrics = _fetch_latest_metrics(client, student_ids, window_seconds=60)
            summary = _summarize_course(course_id, name, metrics, len(student_ids))
            summaries.append(
                {
                    "course_id": summary.course_id,
                    "name": summary.name,
                    "total_students": summary.total_students,
                    "active_students": summary.active_students,
                    "avg_focus": summary.avg_focus,
                    "is_live": summary.is_live,
                }
            )
            active_students += summary.active_students
            if summary.is_live:
                avg_focus_values.append(summary.avg_focus)

        avg_focus = round(sum(avg_focus_values) / len(avg_focus_values)) if avg_focus_values else 0

        return jsonify(
            {
                "teacher": {"id": teacher_id},
                "stats": {
                    "total_courses": len(summaries),
                    "total_students": total_students,
                    "active_students": active_students,
                    "avg_focus": avg_focus,
                },
                "courses": summaries,
            }
        )

    @app.route("/api/teacher/<teacher_id>/courses/<course_id>/live")
    def course_live(teacher_id: str, course_id: str) -> Any:
        if client is None:
            return jsonify({"error": "SUPABASE_URL/SUPABASE_KEY not set"}), 400

        if teacher_id == "demo-teacher":
            return jsonify(
                {
                    "course_id": course_id,
                    "students": [
                        {"student_id": "demo-01", "name": "학생 A", "focus_score": 82},
                        {"student_id": "demo-02", "name": "학생 B", "focus_score": 55},
                        {"student_id": "demo-03", "name": "학생 C", "focus_score": 38},
                    ],
                    "summary": {"total_students": 3, "focused": 1, "normal": 1, "attention": 1},
                }
            )

        student_ids = _fetch_course_students(client, course_id, teacher_id)
        metrics = _fetch_latest_metrics(client, student_ids, window_seconds=90)
        by_student: Dict[str, Dict[str, Any]] = {}
        for row in metrics:
            sid = row["student_id"]
            ts = _parse_ts(row["timestamp"])
            prev = by_student.get(sid)
            if prev is None or ts > prev["_ts"]:
                row_copy = dict(row)
                row_copy["_ts"] = ts
                by_student[sid] = row_copy

        student_rows = []
        for sid in student_ids:
            row = by_student.get(sid)
            focus_score = round((row.get("engagement") or 0) * 100) if row else 0
            student_rows.append(
                {
                    "student_id": sid,
                    "name": sid,
                    "focus_score": focus_score,
                }
            )

        focused = len([s for s in student_rows if s["focus_score"] >= 70])
        normal = len([s for s in student_rows if 50 <= s["focus_score"] < 70])
        attention = len([s for s in student_rows if s["focus_score"] < 50])

        return jsonify(
            {
                "course_id": course_id,
                "students": student_rows,
                "summary": {
                    "total_students": len(student_rows),
                    "focused": focused,
                    "normal": normal,
                    "attention": attention,
                },
            }
        )

    @app.route("/api/teacher/<teacher_id>/courses/<course_id>/heatmap")
    def course_heatmap(teacher_id: str, course_id: str) -> Any:
        if client is None:
            return jsonify({"marks": []})

        if teacher_id == "demo-teacher":
            return jsonify(
                {
                    "marks": [
                        {"topic": "Page 10", "minute": 2, "count": 3},
                        {"topic": "Page 12", "minute": 5, "count": 2},
                    ]
                }
            )

        student_ids = _fetch_course_students(client, course_id, teacher_id)
        metrics = _fetch_latest_metrics(client, student_ids, window_seconds=600)
        if not metrics:
            return jsonify({"marks": []})

        base_ts = min(_parse_ts(row["timestamp"]) for row in metrics)
        marks = []
        for row in metrics:
            if (row.get("confusion") or 0) < 0.2:
                continue
            ts = _parse_ts(row["timestamp"])
            minute = max(int((ts - base_ts).total_seconds() // 60), 0)
            marks.append(
                {
                    "topic": f"Page {row.get('pdf_page', '-')}",
                    "minute": minute,
                    "count": 1,
                }
            )

        return jsonify({"marks": marks[:10]})

    return app


if __name__ == "__main__":
    flask_app = create_teacher_app()
    port = int(os.environ.get("TEACHER_API_PORT", "7001"))
    flask_app.run(host="0.0.0.0", port=port, debug=False)
