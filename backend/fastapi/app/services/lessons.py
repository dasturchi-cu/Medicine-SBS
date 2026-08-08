from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from ..neon_client import Client

from ..schemas.lessons import LessonCreate, LessonItem, LessonUpdate

logger = logging.getLogger(__name__)


def _to_item(row: dict[str, Any]) -> LessonItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()
    return LessonItem(
        id=str(row.get("id") or ""),
        course_id=str(row.get("course_id") or ""),
        section_id=row.get("section_id"),
        title=str(row.get("title") or ""),
        video_url=str(row.get("video_url") or ""),
        order_no=int(row.get("order_no") or 1),
        is_free=bool(row.get("is_free")),
        created_at=created,
    )


def list_lessons(client: Client, *, course_id: str | None = None) -> list[LessonItem]:
    try:
        query = client.table("lessons").select("*").order("order_no", desc=False)
        if course_id:
            query = query.eq("course_id", course_id)
        rows = query.execute().data or []
        return [_to_item(row) for row in rows]
    except Exception as error:
        logger.warning("Failed to list lessons from Supabase: %s", error)
        return []


def create_lesson(client: Client, payload: LessonCreate) -> LessonItem:
    inserted = (
        client.table("lessons")
        .insert(
            {
                "course_id": payload.course_id,
                "section_id": payload.section_id,
                "title": payload.title.strip(),
                "video_url": payload.video_url.strip(),
                "order_no": payload.order_no,
                "is_free": payload.is_free,
            }
        )
        .execute()
    )
    row = (inserted.data or [None])[0]
    if not row:
        raise RuntimeError("Failed to create lesson.")
    return _to_item(row)


def update_lesson(client: Client, *, lesson_id: str, payload: LessonUpdate) -> LessonItem:
    patch: dict[str, Any] = {}
    for key in ["course_id", "section_id", "title", "video_url", "order_no", "is_free"]:
        value = getattr(payload, key)
        if value is not None:
            patch[key] = value.strip() if isinstance(value, str) else value
    updated = client.table("lessons").update(patch).eq("id", lesson_id).execute()
    row = (updated.data or [None])[0]
    if not row:
        raise RuntimeError("Lesson not found.")
    return _to_item(row)


def delete_lesson(client: Client, *, lesson_id: str) -> None:
    client.table("lessons").delete().eq("id", lesson_id).execute()
