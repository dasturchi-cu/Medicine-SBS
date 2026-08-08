from __future__ import annotations

from datetime import datetime
from typing import Any

from ..neon_client import Client

from ..schemas.admin_ads import AdminAdCreate, AdminAdItem, AdminAdUpdate


def _raise_ad_write_error(error: Exception) -> None:
    message = str(error).lower()
    if "foreign key" in message or "violates foreign key" in message:
        raise RuntimeError(
            "Bog‘langan kurs bazada yo‘q — kurs tanlamasdan saqlang yoki to‘g‘ri kursni tanlang."
        ) from error
    if "invalid input syntax for type uuid" in message:
        raise RuntimeError(
            "Noto‘g‘ri kurs identifikatori — maydonni bo‘sh qoldiring yoki to‘g‘ri UUID kiriting."
        ) from error
    raise RuntimeError(f"Reklama saqlanmadi: {error}") from error


def _to_item(row: dict[str, Any]) -> AdminAdItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()
    cid = row.get("course_id")
    return AdminAdItem(
        id=str(row.get("id") or ""),
        title=str(row.get("title") or ""),
        message=str(row.get("message") or ""),
        image_url=str(row.get("image_url") or ""),
        price_label=str(row.get("price_label") or ""),
        course_id=str(cid).strip() if cid else None,
        telegram=str(row.get("telegram") or "Mr_Xusanboy"),
        is_active=bool(row.get("is_active")),
        created_at=created,
    )


def list_ads(client: Client) -> list[AdminAdItem]:
    rows = (
        client.table("course_banners")
        .select("*")
        .order("created_at", desc=True)
        .execute()
    ).data or []
    return [_to_item(row) for row in rows]


def create_ad(client: Client, payload: AdminAdCreate) -> AdminAdItem:
    course_key = (payload.course_id or "").strip() or None
    insert_row = {
        "title": payload.title.strip(),
        "message": payload.message.strip(),
        "image_url": payload.image_url.strip(),
        "price_label": payload.price_label.strip(),
        "course_id": course_key,
        "telegram": payload.telegram.replace("@", "").strip() or "Mr_Xusanboy",
        "is_active": payload.is_active,
    }
    try:
        inserted = client.table("course_banners").insert(insert_row).execute()
    except Exception as error:
        _raise_ad_write_error(error)
    row = (inserted.data or [None])[0]
    if not row:
        raise RuntimeError("Reklama qo'shilmadi — server javobida yozuv yo'q.")
    return _to_item(row)


def update_ad(client: Client, *, ad_id: str, payload: AdminAdUpdate) -> AdminAdItem:
    raw = payload.model_dump(exclude_unset=True)
    patch: dict[str, Any] = {}
    for key in ["title", "message", "image_url", "price_label", "is_active", "course_id"]:
        if key not in raw:
            continue
        value = raw[key]
        if isinstance(value, str):
            patch[key] = value.strip()
        else:
            patch[key] = value
    if "course_id" in patch:
        cid = patch.get("course_id")
        if cid is None or cid == "":
            patch["course_id"] = None
        elif isinstance(cid, str):
            patch["course_id"] = cid.strip() or None
    if "telegram" in raw:
        t = raw["telegram"]
        patch["telegram"] = (
            t.replace("@", "").strip() if isinstance(t, str) else str(t or "")
        ) or "Mr_Xusanboy"

    try:
        updated = client.table("course_banners").update(patch).eq("id", ad_id).execute()
    except Exception as error:
        _raise_ad_write_error(error)
    row = (updated.data or [None])[0]
    if not row:
        raise RuntimeError("Reklama topilmadi.")
    return _to_item(row)


def delete_ad(client: Client, *, ad_id: str) -> None:
    client.table("course_banners").delete().eq("id", ad_id).execute()
