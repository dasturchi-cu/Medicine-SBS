from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from ..neon_client import Client

from ..schemas.notifications import NotificationCreate, NotificationFeedItem, NotificationItem
from .push_fcm import broadcast_notification_to_tokens

logger = logging.getLogger(__name__)


def _to_notification_item(row: dict[str, Any]) -> NotificationItem:
    recipients_count = int(row.get("recipients_count") or 0)
    viewed_count = int(row.get("viewed_count") or 0)
    clicked_count = int(row.get("clicked_count") or 0)
    sent_at = row.get("created_at")
    if isinstance(sent_at, str):
        sent_at_dt = datetime.fromisoformat(sent_at.replace("Z", "+00:00"))
    elif isinstance(sent_at, datetime):
        sent_at_dt = sent_at
    else:
        sent_at_dt = datetime.utcnow()

    return NotificationItem(
        id=row["id"],
        title=row["title"] or "",
        message=row["message"] or "",
        image_url=row.get("image_url") or "",
        sent_at=sent_at_dt,
        recipients_count=recipients_count,
        viewed_count=viewed_count,
        clicked_count=clicked_count,
    )


def list_notifications(client: Client, *, limit: int = 50) -> list[NotificationItem]:
    try:
        notifications_resp = (
            client.table("notifications")
            .select("id,title,message,image_url,created_at")
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        notifications = notifications_resp.data or []
        if not notifications:
            return []

        ids = [item["id"] for item in notifications]
        deliveries_resp = (
            client.table("notification_deliveries")
            .select("notification_id,viewed_at")
            .in_("notification_id", ids)
            .execute()
        )
        deliveries = deliveries_resp.data or []
        counts: dict[str, dict[str, int]] = {}
        for delivery in deliveries:
            key = str(delivery["notification_id"])
            if key not in counts:
                counts[key] = {"recipients_count": 0, "viewed_count": 0, "clicked_count": 0}
            counts[key]["recipients_count"] += 1
            if delivery.get("viewed_at"):
                counts[key]["viewed_count"] += 1

        click_resp = (
            client.table("notification_click_events")
            .select("notification_id")
            .in_("notification_id", ids)
            .execute()
        )
        for row in click_resp.data or []:
            key = str(row.get("notification_id") or "")
            if not key:
                continue
            if key not in counts:
                counts[key] = {"recipients_count": 0, "viewed_count": 0, "clicked_count": 0}
            counts[key]["clicked_count"] += 1

        merged: list[NotificationItem] = []
        for item in notifications:
            item_counts = counts.get(str(item["id"]), {"recipients_count": 0, "viewed_count": 0, "clicked_count": 0})
            merged.append(_to_notification_item({**item, **item_counts}))
        return merged
    except Exception as error:
        logger.warning("Failed to list notifications from Supabase: %s", error)
        return []


def create_notification(client: Client, payload: NotificationCreate) -> NotificationItem:
    inserted = (
        client.table("notifications")
        .insert(
            {
                "title": payload.title.strip(),
                "message": payload.message.strip(),
                "image_url": payload.image_url.strip(),
                "created_by": "admin_panel",
            }
        )
        .execute()
    )
    item = (inserted.data or [None])[0]
    if not item:
        raise RuntimeError("Failed to create notification.")

    users_resp = (
        client.table("users")
        .select("id")
        .eq("is_blocked", False)
        .execute()
    )
    users = users_resp.data or []
    user_ids: list[str] = []
    if users:
        deliveries = [{"notification_id": item["id"], "user_id": user["id"]} for user in users]
        client.table("notification_deliveries").insert(deliveries).execute()
        user_ids = [str(u["id"]) for u in users]

    tokens: list[str] = []
    if user_ids:
        devices_resp = (
            client.table("user_devices")
            .select("fcm_token")
            .in_("user_id", user_ids)
            .eq("is_primary", True)
            .execute()
        )
        for row in devices_resp.data or []:
            t = (row.get("fcm_token") or "").strip()
            if t:
                tokens.append(t)

    if tokens:
        try:
            broadcast_notification_to_tokens(
                tokens=tokens,
                payload={
                    "notification_id": str(item["id"]),
                    "route": "/notifications",
                    "title": payload.title.strip(),
                    "body": payload.message.strip(),
                },
            )
        except Exception as exc:
            logger.warning("FCM broadcast failed (notification still saved): %s", exc)

    return _to_notification_item(
        {
            **item,
            "recipients_count": len(users),
            "viewed_count": 0,
            "clicked_count": 0,
        }
    )


def list_user_notification_feed(client: Client, *, user_id: str, limit: int = 100) -> list[NotificationFeedItem]:
    try:
        deliveries = (
            client.table("notification_deliveries")
            .select("notification_id,viewed_at,delivered_at")
            .eq("user_id", user_id)
            .order("delivered_at", desc=True)
            .limit(limit)
            .execute()
        ).data or []
        if not deliveries:
            return []
        # Bildirishnoma tafsilotlarini alohida olamiz (PostgREST embed o'rniga).
        notif_ids = list({str(d.get("notification_id")) for d in deliveries if d.get("notification_id")})
        notif_by_id: dict[str, dict] = {}
        if notif_ids:
            nrows = (
                client.table("notifications")
                .select("id,title,message,image_url,created_at")
                .in_("id", notif_ids)
                .execute()
            ).data or []
            notif_by_id = {str(n.get("id")): n for n in nrows}

        result: list[NotificationFeedItem] = []
        for row in deliveries:
            notification = notif_by_id.get(str(row.get("notification_id")))
            if not isinstance(notification, dict):
                continue
            sent_at = notification.get("created_at")
            if isinstance(sent_at, str):
                sent_at_dt = datetime.fromisoformat(sent_at.replace("Z", "+00:00"))
            elif isinstance(sent_at, datetime):
                sent_at_dt = sent_at
            else:
                sent_at_dt = datetime.utcnow()
            result.append(
                NotificationFeedItem(
                    id=str(notification.get("id") or ""),
                    title=str(notification.get("title") or ""),
                    message=str(notification.get("message") or ""),
                    image_url=str(notification.get("image_url") or ""),
                    sent_at=sent_at_dt,
                    viewed=bool(row.get("viewed_at")),
                )
            )
        return result
    except Exception as error:
        logger.warning("Failed to list user notification feed from Supabase: %s", error)
        return []


def delete_notification(client: Client, notification_id: str) -> None:
    client.table("notifications").delete().eq("id", notification_id).execute()


def mark_notification_viewed(client: Client, *, notification_id: str, user_id: str) -> None:
    client.table("notification_deliveries").update({"viewed_at": datetime.utcnow().isoformat()}).eq(
        "notification_id", notification_id
    ).eq("user_id", user_id).is_("viewed_at", None).execute()


def mark_notification_clicked(client: Client, *, notification_id: str, user_id: str) -> None:
    existing = (
        client.table("notification_click_events")
        .select("id")
        .eq("notification_id", notification_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    ).data or []
    if existing:
        return
    client.table("notification_click_events").insert(
        {"notification_id": notification_id, "user_id": user_id}
    ).execute()
