from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

import psycopg
from ..neon_client import Client

from ..schemas.slides import SlideCreate, SlideItem, SlideUpdate

logger = logging.getLogger(__name__)


def _to_item(row: dict[str, Any]) -> SlideItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()
    return SlideItem(
        id=str(row.get("id") or ""),
        title=str(row.get("title") or ""),
        subtitle=str(row.get("subtitle") or ""),
        image_url=str(row.get("image_url") or ""),
        button_text=str(row.get("button_text") or "Boshlash"),
        course_id=row.get("course_id"),
        order_no=int(row.get("order_no") or 1),
        is_active=bool(row.get("is_active")),
        created_at=created,
    )


def list_slides(client: Client, *, active_only: bool = False) -> list[SlideItem]:
    try:
        query = client.table("home_slides").select("*").order("order_no", desc=False)
        if active_only:
            query = query.eq("is_active", True)
        response = query.execute()
        return [_to_item(row) for row in (response.data or [])]
    except Exception as error:
        logger.warning("Failed to list slides from Supabase: %s", error)
        return []


def create_slide(client: Client, payload: SlideCreate) -> SlideItem:
    def next_order_no() -> int:
        rows = (
            client.table("home_slides")
            .select("order_no")
            .order("order_no", desc=True)
            .limit(1)
            .execute()
        ).data or []
        if not rows:
            return 1
        return int(rows[0].get("order_no") or 0) + 1

    row = {
        "title": payload.title.strip(),
        "subtitle": payload.subtitle.strip(),
        "image_url": payload.image_url.strip(),
        "button_text": payload.button_text.strip() or "Boshlash",
        "course_id": payload.course_id,
    }
    order_no = payload.order_no
    for _ in range(3):
        try:
            inserted = client.table("home_slides").insert({**row, "order_no": order_no}).execute()
            item = (inserted.data or [None])[0]
            if not item:
                raise RuntimeError("Failed to create slide.")
            return _to_item(item)
        except psycopg.errors.UniqueViolation:
            order_no = next_order_no()
            continue
    raise RuntimeError("Home reklama tartib raqami band. Qayta urinib ko'ring.")


def update_slide(client: Client, *, slide_id: str, payload: SlideUpdate) -> SlideItem:
    patch: dict[str, Any] = {}
    for key in ["title", "subtitle", "image_url", "button_text", "order_no", "is_active"]:
        value = getattr(payload, key)
        if value is not None:
            patch[key] = value.strip() if isinstance(value, str) else value
    if payload.course_id is not None:
        patch["course_id"] = payload.course_id

    updated = client.table("home_slides").update(patch).eq("id", slide_id).execute()
    item = (updated.data or [None])[0]
    if not item:
        raise RuntimeError("Slide not found.")
    return _to_item(item)


def delete_slide(client: Client, *, slide_id: str) -> None:
    client.table("home_slides").delete().eq("id", slide_id).execute()
