from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from ..neon_client import Client

from ..schemas.banners import BannerCreate, BannerItem, BannerUpdate

logger = logging.getLogger(__name__)


def _to_item(row: dict[str, Any]) -> BannerItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()
    return BannerItem(
        id=str(row.get("id") or ""),
        title=str(row.get("title") or ""),
        message=str(row.get("message") or ""),
        image_url=str(row.get("image_url") or ""),
        price_label=str(row.get("price_label") or ""),
        course_id=row.get("course_id"),
        telegram=str(row.get("telegram") or "Mr_Xusanboy"),
        is_active=bool(row.get("is_active")),
        created_at=created,
    )


def list_banners(client: Client, *, active_only: bool = False) -> list[BannerItem]:
    try:
        query = client.table("course_banners").select("*").order("created_at", desc=True)
        if active_only:
            query = query.eq("is_active", True)
        rows = query.execute().data or []
        return [_to_item(row) for row in rows]
    except Exception as error:
        logger.warning("Failed to list banners from Supabase: %s", error)
        return []


def create_banner(client: Client, payload: BannerCreate) -> BannerItem:
    inserted = (
        client.table("course_banners")
        .insert(
            {
                "title": payload.title.strip(),
                "message": payload.message.strip(),
                "image_url": payload.image_url.strip(),
                "price_label": payload.price_label.strip(),
                "course_id": payload.course_id,
                "telegram": payload.telegram.replace("@", "").strip() or "Mr_Xusanboy",
                "is_active": payload.is_active,
            }
        )
        .execute()
    )
    row = (inserted.data or [None])[0]
    if not row:
        raise RuntimeError("Failed to create banner.")
    return _to_item(row)


def update_banner(client: Client, *, banner_id: str, payload: BannerUpdate) -> BannerItem:
    patch: dict[str, Any] = {}
    for key in ["title", "message", "image_url", "price_label", "is_active"]:
        value = getattr(payload, key)
        if value is not None:
            patch[key] = value.strip() if isinstance(value, str) else value
    if payload.course_id is not None:
        patch["course_id"] = payload.course_id
    if payload.telegram is not None:
        patch["telegram"] = payload.telegram.replace("@", "").strip() or "Mr_Xusanboy"
    updated = client.table("course_banners").update(patch).eq("id", banner_id).execute()
    row = (updated.data or [None])[0]
    if not row:
        raise RuntimeError("Banner not found.")
    return _to_item(row)


def delete_banner(client: Client, *, banner_id: str) -> None:
    client.table("course_banners").delete().eq("id", banner_id).execute()
