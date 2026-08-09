from __future__ import annotations

from datetime import datetime
import secrets

from fastapi import HTTPException, status
from ..neon_client import Client

from ..schemas.auth import AuthUserResponse, MobileLoginRequest, MobileProfileUpdateRequest, UserStatusResponse


def _normalize_phone(phone: str) -> str:
    return "".join(ch for ch in phone if ch.isdigit())


def mobile_login(client: Client, payload: MobileLoginRequest, *, admin_contact: str = "Mr_Xusanboy") -> AuthUserResponse:
    phone = _normalize_phone(payload.phone)
    if not phone:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Telefon raqam noto'g'ri.")

    user_resp = client.table("users").select("*").eq("phone", phone).limit(1).execute()
    user = (user_resp.data or [None])[0]
    if user is None:
        inserted = (
            client.table("users")
            .insert(
                {
                    "phone": phone,
                    "full_name": payload.display_name.strip() or f"User {phone[-4:]}",
                }
            )
            .execute()
        )
        user = (inserted.data or [None])[0]
        if user is None:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="User yaratilmadi.")

    if bool(user.get("is_blocked")):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Siz admin tomonidan bloklangansiz. Admin: @{admin_contact}",
        )

    # Device lock: one account => one primary device
    user_id = str(user["id"])

    # Login sonini oshiramiz (aktivlik statistikasi).
    try:
        _lc = client.table("users").select("login_count").eq("id", user_id).limit(1).execute().data or []
        _n = int((_lc[0].get("login_count") if _lc else 0) or 0)
        client.table("users").update({"login_count": _n + 1}).eq("id", user_id).execute()
    except Exception:
        pass
    device_resp = (
        client.table("user_devices")
        .select("*")
        .eq("user_id", user_id)
        .eq("is_primary", True)
        .limit(1)
        .execute()
    )
    primary = (device_resp.data or [None])[0]
    fcm = (payload.fcm_token or "").strip() or None
    if primary is None:
        row: dict = {
            "user_id": user_id,
            "device_id": payload.device_id,
            "platform": payload.platform,
            "is_primary": True,
        }
        if fcm:
            row["fcm_token"] = fcm
        client.table("user_devices").insert(row).execute()
    else:
        if str(primary.get("device_id") or "") != payload.device_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bu raqam boshqa qurilmaga ulangan.",
            )
        updates: dict = {"last_seen_at": datetime.utcnow().isoformat()}
        if fcm:
            updates["fcm_token"] = fcm
        client.table("user_devices").update(updates).eq("id", primary["id"]).execute()

    if payload.display_name.strip() and payload.display_name.strip() != str(user.get("full_name") or ""):
        updated = (
            client.table("users")
            .update({"full_name": payload.display_name.strip()})
            .eq("id", user_id)
            .execute()
        )
        updated_row = (updated.data or [None])[0]
        if updated_row:
            user = updated_row

    # Ensure user has delivery rows for existing notifications.
    notifications = client.table("notifications").select("id").execute().data or []
    if notifications:
        existing_deliveries = (
            client.table("notification_deliveries")
            .select("notification_id")
            .eq("user_id", user_id)
            .execute()
        ).data or []
        existing_ids = {str(row.get("notification_id")) for row in existing_deliveries}
        missing = [
            {"notification_id": row["id"], "user_id": user_id}
            for row in notifications
            if str(row.get("id")) not in existing_ids
        ]
        if missing:
            client.table("notification_deliveries").insert(missing).execute()

    session_token = secrets.token_urlsafe(32)
    existing_sessions = (
        client.table("auth_sessions")
        .select("id")
        .eq("user_id", user_id)
        .eq("device_id", payload.device_id)
        .limit(1)
        .execute()
    ).data or []
    if existing_sessions:
        client.table("auth_sessions").update(
            {
                "session_token": session_token,
                "is_active": True,
                "invalidated_at": None,
                "invalidated_reason": "",
                "last_seen_at": datetime.utcnow().isoformat(),
            }
        ).eq("id", existing_sessions[0]["id"]).execute()
    else:
        client.table("auth_sessions").insert(
            {
                "user_id": user_id,
                "device_id": payload.device_id,
                "session_token": session_token,
                "is_active": True,
                "last_seen_at": datetime.utcnow().isoformat(),
            }
        ).execute()

    return AuthUserResponse(
        user_id=user_id,
        phone=phone,
        full_name=str(user.get("full_name") or ""),
        session_token=session_token,
    )


def update_mobile_profile(client: Client, payload: MobileProfileUpdateRequest) -> AuthUserResponse:
    uid = payload.user_id.strip()
    tok = payload.session_token.strip()
    name = payload.display_name.strip()
    sess = (
        client.table("auth_sessions")
        .select("id")
        .eq("user_id", uid)
        .eq("session_token", tok)
        .eq("is_active", True)
        .limit(1)
        .execute()
    ).data or []
    if not sess:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Sessiya topilmadi yoki yaroqsiz.")

    client.table("users").update({"full_name": name, "updated_at": datetime.utcnow().isoformat()}).eq("id", uid).execute()
    user_resp = client.table("users").select("phone,full_name").eq("id", uid).limit(1).execute()
    user_row = (user_resp.data or [None])[0]
    if not user_row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User topilmadi.")
    phone = str(user_row.get("phone") or "")
    full_name = str(user_row.get("full_name") or name)
    return AuthUserResponse(user_id=uid, phone=phone, full_name=full_name, session_token=tok)


def get_user_status(
    client: Client,
    *,
    user_id: str,
    admin_contact: str = "Mr_Xusanboy",
    session_token: str | None = None,
) -> UserStatusResponse:
    user_resp = client.table("users").select("id,is_blocked").eq("id", user_id).limit(1).execute()
    user = (user_resp.data or [None])[0]
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User topilmadi.")
    session_active = True
    if session_token and session_token.strip():
        session = (
            client.table("auth_sessions")
            .select("id,is_active")
            .eq("user_id", user_id)
            .eq("session_token", session_token.strip())
            .limit(1)
            .execute()
        ).data or []
        session_active = bool(session and session[0].get("is_active"))

    return UserStatusResponse(
        user_id=str(user.get("id") or user_id),
        is_blocked=bool(user.get("is_blocked")),
        admin_contact=admin_contact,
        session_active=session_active,
    )
