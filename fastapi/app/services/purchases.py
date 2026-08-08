from __future__ import annotations

from datetime import datetime
from typing import Any

from ..neon_client import Client

from ..schemas.purchases import PurchaseCreateRequest, UserEntitlementItem


def _to_item(row: dict[str, Any]) -> UserEntitlementItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()
    return UserEntitlementItem(
        id=str(row.get("id") or ""),
        user_id=str(row.get("user_id") or ""),
        course_id=row.get("course_id"),
        section_id=row.get("section_id"),
        is_active=bool(row.get("is_active")),
        created_at=created,
    )


def create_purchase(client: Client, payload: PurchaseCreateRequest) -> UserEntitlementItem:
    now_iso = datetime.utcnow().isoformat()
    client.table("payments").insert(
        {
            "user_id": payload.user_id,
            "course_id": payload.course_id,
            "section_id": payload.section_id,
            "amount_uzs": payload.amount_uzs,
            "provider": payload.provider,
            "status": "paid",
            "paid_at": now_iso,
        }
    ).execute()

    existing_resp = (
        client.table("user_entitlements")
        .select("*")
        .eq("user_id", payload.user_id)
        .eq("course_id", payload.course_id)
        .eq("section_id", payload.section_id)
        .eq("is_active", True)
        .limit(1)
        .execute()
    )
    existing = (existing_resp.data or [None])[0]
    if existing:
        return _to_item(existing)

    inserted = (
        client.table("user_entitlements")
        .insert(
            {
                "user_id": payload.user_id,
                "course_id": payload.course_id,
                "section_id": payload.section_id,
                "source": "payment",
                "granted_by": "payment_flow",
                "is_active": True,
            }
        )
        .execute()
    )
    row = (inserted.data or [None])[0]
    if not row:
        raise RuntimeError("Entitlement yaratilmadi.")
    return _to_item(row)


def list_user_entitlements(client: Client, *, user_id: str) -> list[UserEntitlementItem]:
    response = (
        client.table("user_entitlements")
        .select("*")
        .eq("user_id", user_id)
        .eq("is_active", True)
        .order("created_at", desc=True)
        .execute()
    )
    return [_to_item(row) for row in (response.data or [])]
