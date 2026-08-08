from __future__ import annotations

import json
import logging
from typing import Any

import firebase_admin
from firebase_admin import credentials, initialize_app, messaging

from ..config import get_settings

logger = logging.getLogger(__name__)

_app_initialized = False


def _ensure_firebase_app() -> bool:
    global _app_initialized
    if _app_initialized:
        return True
    try:
        firebase_admin.get_app()
        _app_initialized = True
        return True
    except ValueError:
        pass
    raw = (get_settings().firebase_credentials_json or "").strip()
    if not raw:
        logger.warning("FCM skipped: FIREBASE_CREDENTIALS_JSON is not set.")
        return False
    try:
        info = json.loads(raw)
        cred = credentials.Certificate(info)
        initialize_app(cred)
        _app_initialized = True
        return True
    except Exception as exc:
        logger.warning("FCM init failed: %s", exc)
        return False


def send_notification_multicast(
    *,
    tokens: list[str],
    title: str,
    body: str,
    data: dict[str, str],
) -> int:
    """Send FCM to up to 500 tokens per call. Returns count of successful sends."""
    if not tokens:
        return 0
    if not _ensure_firebase_app():
        return 0

    chunk_size = 500
    success = 0
    for i in range(0, len(tokens), chunk_size):
        chunk = [t for t in tokens[i : i + chunk_size] if t and len(t) > 10]
        if not chunk:
            continue
        msg = messaging.MulticastMessage(
            tokens=chunk,
            notification=messaging.Notification(title=title, body=body),
            data=data,
            android=messaging.AndroidConfig(priority="high"),
        )
        try:
            resp = messaging.send_each_for_multicast(msg)
            success += resp.success_count
            if resp.failure_count:
                logger.info(
                    "FCM batch partial failure: ok=%s fail=%s",
                    resp.success_count,
                    resp.failure_count,
                )
        except Exception as exc:
            logger.warning("FCM send_each_for_multicast failed: %s", exc)
    return success


def broadcast_notification_to_tokens(*, tokens: list[str], payload: dict[str, Any]) -> int:
    nid = str(payload.get("notification_id") or "")
    route = str(payload.get("route") or "/notifications")
    title = str(payload.get("title") or "")
    body = str(payload.get("body") or "")
    data = {
        "notification_id": nid,
        "route": route,
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
    }
    return send_notification_multicast(tokens=tokens, title=title, body=body, data=data)
