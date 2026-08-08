from __future__ import annotations

from datetime import datetime
from typing import Any

from ..neon_client import Client

from ..schemas.tests import (
    QuizAttemptCreate,
    QuizAttemptResponse,
    QuizCreate,
    QuizItem,
    QuizQuestionCreate,
    QuizQuestionItem,
    QuizQuestionUpdate,
)
from .ranking import compute_watch_score, ensure_user_rank_row


def _to_quiz_item(row: dict[str, Any], question_count: int = 0) -> QuizItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()
    return QuizItem(
        id=str(row.get("id") or ""),
        title=str(row.get("title") or ""),
        description=str(row.get("description") or ""),
        course_id=row.get("course_id"),
        section_id=row.get("section_id"),
        lesson_id=row.get("lesson_id"),
        estimated_minutes=int(row.get("estimated_minutes") or 10),
        is_active=bool(row.get("is_active")),
        question_count=question_count,
        created_at=created,
    )


def _to_question_item(row: dict[str, Any]) -> QuizQuestionItem:
    return QuizQuestionItem(
        id=str(row.get("id") or ""),
        quiz_id=str(row.get("quiz_id") or ""),
        question_text=str(row.get("question_text") or ""),
        option_a=str(row.get("option_a") or ""),
        option_b=str(row.get("option_b") or ""),
        option_c=str(row.get("option_c") or ""),
        option_d=str(row.get("option_d") or ""),
        correct_option=str(row.get("correct_option") or "A"),
        order_no=int(row.get("order_no") or 1),
    )


def list_quizzes(client: Client, *, lesson_id: str | None = None) -> list[QuizItem]:
    query = client.table("quizzes").select("*").order("created_at", desc=True)
    if lesson_id:
        query = query.eq("lesson_id", lesson_id)
    quizzes_resp = query.execute()
    quizzes = quizzes_resp.data or []
    if not quizzes:
        return []

    ids = [q["id"] for q in quizzes]
    questions_resp = client.table("quiz_questions").select("quiz_id").in_("quiz_id", ids).execute()
    counts: dict[str, int] = {}
    for q in questions_resp.data or []:
        key = str(q.get("quiz_id"))
        counts[key] = counts.get(key, 0) + 1
    return [_to_quiz_item(row, counts.get(str(row.get("id")), 0)) for row in quizzes]


def create_quiz(client: Client, payload: QuizCreate) -> QuizItem:
    inserted = (
        client.table("quizzes")
        .insert(
            {
                "title": payload.title.strip(),
                "description": payload.description.strip(),
                "course_id": payload.course_id,
                "section_id": payload.section_id,
                "lesson_id": payload.lesson_id,
                "estimated_minutes": payload.estimated_minutes,
            }
        )
        .execute()
    )
    row = (inserted.data or [None])[0]
    if not row:
        raise RuntimeError("Failed to create quiz.")
    return _to_quiz_item(row, 0)


def get_quiz(client: Client, *, quiz_id: str) -> QuizItem | None:
    row_resp = client.table("quizzes").select("*").eq("id", quiz_id).limit(1).execute()
    row = (row_resp.data or [None])[0]
    if not row:
        return None
    question_count_resp = client.table("quiz_questions").select("id").eq("quiz_id", quiz_id).execute()
    count = len(question_count_resp.data or [])
    return _to_quiz_item(row, count)


def delete_quiz(client: Client, *, quiz_id: str) -> None:
    client.table("quizzes").delete().eq("id", quiz_id).execute()


def list_questions(client: Client, *, quiz_id: str) -> list[QuizQuestionItem]:
    response = client.table("quiz_questions").select("*").eq("quiz_id", quiz_id).order("order_no", desc=False).execute()
    return [_to_question_item(row) for row in (response.data or [])]


def add_question(client: Client, *, quiz_id: str, payload: QuizQuestionCreate) -> QuizQuestionItem:
    inserted = (
        client.table("quiz_questions")
        .insert(
            {
                "quiz_id": quiz_id,
                "question_text": payload.question_text.strip(),
                "option_a": payload.option_a.strip(),
                "option_b": payload.option_b.strip(),
                "option_c": payload.option_c.strip(),
                "option_d": payload.option_d.strip(),
                "correct_option": payload.correct_option,
                "order_no": payload.order_no,
            }
        )
        .execute()
    )
    row = (inserted.data or [None])[0]
    if not row:
        raise RuntimeError("Failed to add question.")
    return _to_question_item(row)


def update_question(client: Client, *, question_id: str, payload: QuizQuestionUpdate) -> QuizQuestionItem:
    patch: dict[str, Any] = {}
    for key in ["question_text", "option_a", "option_b", "option_c", "option_d", "correct_option", "order_no"]:
        value = getattr(payload, key)
        if value is not None:
            patch[key] = value.strip() if isinstance(value, str) else value
    if not patch:
        raise RuntimeError("No fields to update.")
    updated = client.table("quiz_questions").update(patch).eq("id", question_id).execute()
    row = (updated.data or [None])[0]
    if not row:
        raise RuntimeError("Question not found.")
    return _to_question_item(row)


def delete_question(client: Client, *, question_id: str) -> None:
    client.table("quiz_questions").delete().eq("id", question_id).execute()


def create_attempt(client: Client, *, quiz_id: str, payload: QuizAttemptCreate) -> QuizAttemptResponse:
    client.table("quiz_attempts").insert(
        {
            "quiz_id": quiz_id,
            "user_id": payload.user_id,
            "score_percent": payload.score_percent,
            "correct_count": payload.correct_count,
            "total_questions": payload.total_questions,
            "duration_minutes": payload.duration_minutes,
        }
    ).execute()

    # Testda o'tgan vaqt reytingga qo'shilmaydi; faqat test natijasi (score_percent).
    points = round(float(payload.score_percent), 2)
    rank = ensure_user_rank_row(client, user_id=payload.user_id)
    new_quiz_minutes = float(rank.get("quiz_minutes") or 0)
    new_test_points = round(float(rank.get("test_points") or 0) + points, 2)
    hours = float(rank.get("total_watched_hours") or 0)
    completed_n = int(rank.get("completed_lessons") or 0)
    watch_score = compute_watch_score(total_watched_hours=hours, completed_lessons=completed_n)
    new_total = round(new_test_points + watch_score, 2)

    client.table("user_ranks").update(
        {
            "total_score": new_total,
            "quiz_minutes": new_quiz_minutes,
            "test_points": new_test_points,
            "updated_at": datetime.utcnow().isoformat(),
        }
    ).eq("user_id", payload.user_id).execute()

    client.table("rank_events").insert(
        {
            "user_id": payload.user_id,
            "event_type": "quiz_attempt",
            "points": points,
            "duration_minutes": payload.duration_minutes,
            "metadata": {
                "quiz_id": quiz_id,
                "score_percent": payload.score_percent,
                "correct_count": payload.correct_count,
                "total_questions": payload.total_questions,
            },
        }
    ).execute()

    return QuizAttemptResponse(
        points_added=points,
        total_score=new_total,
        quiz_minutes=new_quiz_minutes,
    )
