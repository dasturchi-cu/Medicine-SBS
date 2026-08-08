from __future__ import annotations

from datetime import datetime
from typing import Any

import psycopg
from ..neon_client import Client

from ..schemas.lesson_slides import LessonSlideCreate, LessonSlideItem, LessonSlideUpdate


def _to_item(row: dict[str, Any]) -> LessonSlideItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()
    return LessonSlideItem(
        id=str(row.get("id") or ""),
        lesson_id=str(row.get("lesson_id") or ""),
        title=str(row.get("title") or ""),
        body=str(row.get("body") or ""),
        image_url=str(row.get("image_url") or ""),
        order_no=int(row.get("order_no") or 1),
        is_active=bool(row.get("is_active")),
        created_at=created,
    )


def list_lesson_slides(client: Client, *, lesson_id: str, active_only: bool = True) -> list[LessonSlideItem]:
    query = client.table("lesson_slides").select("*").eq("lesson_id", lesson_id).order("order_no", desc=False)
    if active_only:
        query = query.eq("is_active", True)
    response = query.execute()
    return [_to_item(row) for row in (response.data or [])]


def _next_order_no(client: Client, *, lesson_id: str) -> int:
    rows = (
        client.table("lesson_slides")
        .select("order_no")
        .eq("lesson_id", lesson_id)
        .order("order_no", desc=True)
        .limit(1)
        .execute()
    ).data or []
    if not rows:
        return 1
    return int(rows[0].get("order_no") or 0) + 1


def create_lesson_slide(client: Client, payload: LessonSlideCreate) -> LessonSlideItem:
    base_row = {
        "lesson_id": payload.lesson_id,
        "title": payload.title.strip(),
        "body": payload.body.strip(),
        "image_url": payload.image_url.strip(),
    }
    order_no = payload.order_no
    for _ in range(3):
        try:
            inserted = client.table("lesson_slides").insert({**base_row, "order_no": order_no}).execute()
            row = (inserted.data or [None])[0]
            if not row:
                raise RuntimeError("Failed to create lesson slide.")
            return _to_item(row)
        except psycopg.errors.UniqueViolation:
            order_no = _next_order_no(client, lesson_id=payload.lesson_id)
            continue
    raise RuntimeError("Slayd qo'shishda order_no band bo'lib qoldi. Qayta urinib ko'ring.")


def update_lesson_slide(client: Client, *, slide_id: str, payload: LessonSlideUpdate) -> LessonSlideItem:
    patch: dict[str, Any] = {}
    for key in ["title", "body", "image_url", "order_no", "is_active"]:
        value = getattr(payload, key)
        if value is not None:
            patch[key] = value.strip() if isinstance(value, str) else value
    updated = client.table("lesson_slides").update(patch).eq("id", slide_id).execute()
    row = (updated.data or [None])[0]
    if not row:
        raise RuntimeError("Lesson slide not found.")
    return _to_item(row)


def delete_lesson_slide(client: Client, *, slide_id: str) -> None:
    client.table("lesson_slides").delete().eq("id", slide_id).execute()
