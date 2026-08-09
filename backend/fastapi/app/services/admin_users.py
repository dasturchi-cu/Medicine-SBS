from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from ..neon_client import Client

from .admin_comments import _course_title_display, _resolve_course_titles
from ..schemas.admin_users import (
    AdminUserItem,
    AdminUserUpdateRequest,
    UserEntitlementItem,
    UserOverviewMetrics,
    UserOverviewResponse,
    UserProgressItem,
    UserRecentCommentItem,
    UserRecentRatingItem,
)

logger = logging.getLogger(__name__)


def list_admin_users(client: Client) -> list[AdminUserItem]:
    try:
        rows = client.table("users").select("*").order("created_at", desc=False).execute().data or []
        user_ids = [str(row.get("id")) for row in rows if row.get("id")]
        sessions = (
            client.table("auth_sessions")
            .select("user_id")
            .in_("user_id", user_ids)
            .execute()
        ).data if user_ids else []
        devices = (
            client.table("user_devices")
            .select("user_id")
            .in_("user_id", user_ids)
            .execute()
        ).data if user_ids else []
        session_count_map: dict[str, int] = {}
        app_open_map: dict[str, int] = {}
        for row in sessions or []:
            key = str(row.get("user_id") or "")
            if not key:
                continue
            session_count_map[key] = session_count_map.get(key, 0) + 1
        for row in devices or []:
            key = str(row.get("user_id") or "")
            if not key:
                continue
            app_open_map[key] = app_open_map.get(key, 0) + 1
        items: list[AdminUserItem] = []
        for row in rows:
            created = str(row.get("created_at") or "")
            row_user_id = str(row.get("id") or "")
            items.append(
                AdminUserItem(
                    id=row_user_id,
                    name=str(row.get("full_name") or "Foydalanuvchi"),
                    email=str(row.get("phone") or ""),
                    registration_date=created[:10] if created else "",
                    login_count=int(row.get("login_count") or 0),
                    app_open_count=int(row.get("app_open_count") or 0),
                    is_blocked=bool(row.get("is_blocked")),
                )
            )
        return items
    except Exception as error:
        logger.warning("Failed to list admin users from Supabase: %s", error)
        return []


def set_user_blocked(client: Client, *, user_id: str, blocked: bool) -> None:
    client.table("users").update({"is_blocked": blocked, "updated_at": datetime.utcnow().isoformat()}).eq("id", user_id).execute()
    if blocked:
        client.table("auth_sessions").update(
            {
                "is_active": False,
                "invalidated_at": datetime.utcnow().isoformat(),
                "invalidated_reason": "blocked_by_admin",
            }
        ).eq("user_id", user_id).eq("is_active", True).execute()


def update_admin_user(client: Client, *, user_id: str, payload: AdminUserUpdateRequest) -> AdminUserItem:
    patch: dict[str, Any] = {"updated_at": datetime.utcnow().isoformat()}
    if payload.name is not None:
        patch["full_name"] = payload.name.strip()
    if payload.email is not None:
        patch["phone"] = payload.email.strip()
    if payload.is_blocked is not None:
        patch["is_blocked"] = payload.is_blocked
    if len(patch) == 1:
        raise RuntimeError("No fields to update.")

    result = client.table("users").update(patch).eq("id", user_id).select("*").execute()
    rows = result.data or []
    row = rows[0] if rows else None
    if not row:
        raise RuntimeError("User not found.")
    created = str(row.get("created_at") or "")
    return AdminUserItem(
        id=str(row.get("id") or ""),
        name=str(row.get("full_name") or "Foydalanuvchi"),
        email=str(row.get("phone") or ""),
        registration_date=created[:10] if created else "",
        login_count=0,
        app_open_count=0,
        is_blocked=bool(row.get("is_blocked")),
    )


def delete_admin_user(client: Client, *, user_id: str) -> None:
    client.table("users").delete().eq("id", user_id).execute()


def grant_user_course(client: Client, *, user_id: str, course_id: str) -> None:
    existing = (
        client.table("user_entitlements")
        .select("id")
        .eq("user_id", user_id)
        .eq("course_id", course_id)
        .is_("section_id", None)
        .eq("is_active", True)
        .limit(1)
        .execute()
    ).data or []
    if existing:
        return
    client.table("user_entitlements").insert(
        {
            "user_id": user_id,
            "course_id": course_id,
            "section_id": None,
            "source": "admin_grant",
            "granted_by": "admin_panel",
            "is_active": True,
        }
    ).execute()


def list_user_entitlements(client: Client, *, user_id: str) -> list[UserEntitlementItem]:
    rows = (
        client.table("user_entitlements")
        .select("id,course_id,starts_at,created_at,is_active")
        .eq("user_id", user_id)
        .is_("section_id", None)
        .order("created_at", desc=True)
        .execute()
    ).data or []
    course_ids = [str(row.get("course_id")) for row in rows if row.get("course_id")]
    courses = (
        client.table("courses")
        .select("id,title_uz")
        .in_("id", course_ids)
        .execute()
    ).data if course_ids else []
    course_map = {str(row.get("id")): str(row.get("title_uz") or row.get("id") or "") for row in (courses or [])}
    items: list[UserEntitlementItem] = []
    for row in rows:
        course_id = str(row.get("course_id") or "")
        items.append(
            UserEntitlementItem(
                id=str(row.get("id") or ""),
                course_id=course_id,
                course_title=course_map.get(course_id, course_id),
                purchased_at=str(row.get("starts_at") or row.get("created_at") or ""),
                is_active=bool(row.get("is_active")),
            )
        )
    return items


def revoke_user_course(client: Client, *, user_id: str, course_id: str) -> None:
    # Kurs bo'yicha barcha entitlementlar (bo'lim xaridlari bilan) — aks holda qisman faol qolib ketadi.
    client.table("user_entitlements").update({"is_active": False}).eq("user_id", user_id).eq(
        "course_id", course_id
    ).execute()


def get_user_overview(client: Client, *, user_id: str) -> UserOverviewResponse:
    entitlements = (
        client.table("user_entitlements")
        .select("id,course_id,is_active")
        .eq("user_id", user_id)
        .execute()
    ).data or []
    active_courses = {str(row.get("course_id") or "") for row in entitlements if row.get("is_active") and row.get("course_id")}
    total_entitlements = len(
        [row for row in entitlements if row.get("course_id") and row.get("is_active")]
    )

    ratings_total = client.table("ratings").select("id", count="exact").eq("user_id", user_id).execute()
    app_ratings_total = (
        client.table("app_ratings").select("id", count="exact").eq("user_id", user_id).execute()
    )
    ratings = (
        client.table("ratings")
        .select("course_id,stars,created_at")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(40)
        .execute()
    ).data or []
    app_rating_rows = (
        client.table("app_ratings")
        .select("content_key,stars,created_at")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(40)
        .execute()
    ).data or []
    comments_total = (
        client.table("app_comments")
        .select("id", count="exact")
        .eq("user_id", user_id)
        .is_("parent_id", None)
        .execute()
    )
    legacy_comments_total = (
        client.table("comments")
        .select("id", count="exact")
        .eq("user_id", user_id)
        .is_("parent_id", None)
        .execute()
    )
    replies_total = (
        client.table("app_comments")
        .select("id", count="exact")
        .eq("user_id", user_id)
        .not_.is_("parent_id", None)
        .execute()
    )
    legacy_replies_total = (
        client.table("comments")
        .select("id", count="exact")
        .eq("user_id", user_id)
        .not_.is_("parent_id", None)
        .execute()
    )
    comments = (
        client.table("app_comments")
        .select("id,course_key,text,likes_count,replies_count,created_at,user_id")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(20)
        .execute()
    ).data or []
    likes = client.table("app_comment_likes").select("id", count="exact").eq("user_id", user_id).execute()
    legacy_likes = client.table("comment_reactions").select("id", count="exact").eq("user_id", user_id).execute()

    progress_rows = (
        client.table("video_progress")
        .select("lesson_id,watched_sec,completed,updated_at")
        .eq("user_id", user_id)
        .order("updated_at", desc=True)
        .limit(5000)
        .execute()
    ).data or []
    # lesson -> course_id xaritasi (PostgREST embed o'rniga alohida olamiz).
    _lesson_ids = list({str(r.get("lesson_id")) for r in progress_rows if r.get("lesson_id")})
    _course_by_lesson: dict[str, str] = {}
    if _lesson_ids:
        _lrows = client.table("lessons").select("id,course_id").in_("id", _lesson_ids).execute().data or []
        _course_by_lesson = {str(l.get("id")): str(l.get("course_id") or "") for l in _lrows}
    for _r in progress_rows:
        _cid = _course_by_lesson.get(str(_r.get("lesson_id")))
        if _cid:
            _r["lessons"] = {"course_id": _cid}
    watched_lessons_count = len({str(row.get("lesson_id") or "") for row in progress_rows if row.get("lesson_id")})
    completed_lessons_count = len([row for row in progress_rows if row.get("completed")])
    watched_seconds_total = sum(int(row.get("watched_sec") or 0) for row in progress_rows)

    payments = (
        client.table("payments")
        .select("id,amount_uzs,status,user_id")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(200)
        .execute()
    ).data or []
    paid_payments = [row for row in payments if str(row.get("status") or "").lower() in {"paid", "success"}]
    purchases_count = len(paid_payments)
    paid_total_uzs = float(sum(float(row.get("amount_uzs") or 0) for row in paid_payments))
    active_entitlement_course_ids = {
        str(row.get("course_id") or "")
        for row in entitlements
        if row.get("is_active") and row.get("course_id")
    }
    purchases_count = max(purchases_count, len(active_entitlement_course_ids))

    course_ids_from_ratings = [str(row.get("course_id")) for row in ratings if row.get("course_id")]
    course_ids_from_app_ratings = [
        str(row.get("content_key") or "") for row in app_rating_rows if row.get("content_key")
    ]
    course_ids_from_progress = [str((row.get("lessons") or {}).get("course_id")) for row in progress_rows if (row.get("lessons") or {}).get("course_id")]
    course_ids = list(
        {
            *course_ids_from_ratings,
            *course_ids_from_app_ratings,
            *course_ids_from_progress,
            *list(active_courses),
            *list(active_entitlement_course_ids),
        }
    )
    courses_map: dict[str, str] = {}
    course_price_map: dict[str, float] = {}
    if course_ids:
        courses_rows = client.table("courses").select("id,title_uz,price_uzs").in_("id", course_ids).execute().data or []
        courses_map = {str(row.get("id")): str(row.get("title_uz") or row.get("id") or "") for row in courses_rows}
        course_price_map = {str(row.get("id")): float(row.get("price_uzs") or 0) for row in courses_rows}

    comment_keys_unique = list(
        dict.fromkeys(
            str(row.get("course_key") or "").strip()
            for row in comments
            if str(row.get("course_key") or "").strip()
        )
    )
    if comment_keys_unique:
        for ck, title in _resolve_course_titles(client, comment_keys_unique).items():
            if title:
                courses_map[ck] = title

    if paid_total_uzs <= 0 and active_entitlement_course_ids:
        paid_total_uzs = float(sum(course_price_map.get(course_id, 0.0) for course_id in active_entitlement_course_ids))

    merged_rating_rows: list[tuple[str, str, int, str]] = []
    for row in ratings:
        cid = str(row.get("course_id") or "")
        created_at = str(row.get("created_at") or "")
        merged_rating_rows.append((created_at, cid, int(row.get("stars") or 0), created_at))
    for row in app_rating_rows:
        cid = str(row.get("content_key") or "")
        created_at = str(row.get("created_at") or "")
        merged_rating_rows.append((created_at, cid, int(row.get("stars") or 0), created_at))
    merged_rating_rows.sort(key=lambda item: item[0], reverse=True)

    recent_ratings = [
        UserRecentRatingItem(
            course_id=cid,
            course_title=_course_title_display(cid.strip(), courses_map.get(cid.strip(), "")),
            stars=stars,
            created_at=created_at,
        )
        for _, cid, stars, created_at in merged_rating_rows[:20]
    ]
    lesson_ids = [str(row.get("lesson_id") or "") for row in progress_rows if row.get("lesson_id")]
    lessons_map: dict[str, str] = {}
    if lesson_ids:
        lesson_rows = client.table("lessons").select("id,title").in_("id", lesson_ids).execute().data or []
        lessons_map = {str(row.get("id")): str(row.get("title") or row.get("id") or "") for row in lesson_rows}

    recent_comments = [
        UserRecentCommentItem(
            id=str(row.get("id") or ""),
            course_key=str(row.get("course_key") or ""),
            course_title=_course_title_display(
                str(row.get("course_key") or "").strip(),
                courses_map.get(str(row.get("course_key") or "").strip(), ""),
            ),
            lesson_title="",
            text=str(row.get("text") or ""),
            likes_count=int(row.get("likes_count") or 0),
            replies_count=int(row.get("replies_count") or 0),
            created_at=str(row.get("created_at") or ""),
        )
        for row in comments
    ] + [
        UserRecentCommentItem(
            id=str(row.get("id") or ""),
            course_key=str(row.get("course_id") or ""),
            course_title=_course_title_display(
                str(row.get("course_id") or "").strip(),
                courses_map.get(str(row.get("course_id") or "").strip(), ""),
            ),
            lesson_title="",
            text=str(row.get("text") or ""),
            likes_count=int(row.get("hearts_count") or 0),
            replies_count=0,
            created_at=str(row.get("created_at") or ""),
        )
        for row in (
            client.table("comments")
            .select("id,course_id,text,hearts_count,created_at")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(20)
            .execute()
        ).data
        or []
    ]
    recent_comments.sort(key=lambda row: row.created_at, reverse=True)
    recent_comments = recent_comments[:20]
    progress_items = [
        UserProgressItem(
            lesson_id=str(row.get("lesson_id") or ""),
            course_id=str((row.get("lessons") or {}).get("course_id") or ""),
            course_title=_course_title_display(
                str((row.get("lessons") or {}).get("course_id") or "").strip(),
                courses_map.get(str((row.get("lessons") or {}).get("course_id") or "").strip(), ""),
            ),
            lesson_title=lessons_map.get(str(row.get("lesson_id") or ""), str(row.get("lesson_id") or "")),
            watched_sec=int(row.get("watched_sec") or 0),
            completed=bool(row.get("completed")),
            updated_at=str(row.get("updated_at") or ""),
        )
        for row in progress_rows
    ]

    return UserOverviewResponse(
        user_id=user_id,
        metrics=UserOverviewMetrics(
            active_courses=len(active_courses),
            total_entitlements=total_entitlements,
            ratings_count=int(ratings_total.count or 0) + int(app_ratings_total.count or 0),
            comments_count=int(comments_total.count or 0) + int(legacy_comments_total.count or 0),
            likes_given_count=int(likes.count or 0) + int(legacy_likes.count or 0),
            replies_count=int(replies_total.count or 0) + int(legacy_replies_total.count or 0),
            watched_lessons_count=watched_lessons_count,
            completed_lessons_count=completed_lessons_count,
            watched_seconds_total=watched_seconds_total,
            purchases_count=purchases_count,
            paid_total_uzs=paid_total_uzs,
        ),
        recent_ratings=recent_ratings,
        recent_comments=recent_comments,
        progress_items=progress_items,
    )
