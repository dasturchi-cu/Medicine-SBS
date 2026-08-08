from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from ..neon_client import Client

from ..schemas.courses import CourseCreate, CourseItem, CourseUpdate
from .ranking import sync_user_rank_from_video_progress

logger = logging.getLogger(__name__)


def _to_item(row: dict[str, Any]) -> CourseItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()

    return CourseItem(
        id=str(row.get("id") or ""),
        title_uz=str(row.get("title_uz") or ""),
        title_ru=str(row.get("title_ru") or ""),
        title_en=str(row.get("title_en") or ""),
        price_uzs=float(row.get("price_uzs") or 0),
        admin_telegram=str(row.get("admin_telegram") or "Mr_Xusanboy"),
        image_url=str(row.get("image_url") or ""),
        description_uz=str(row.get("description_uz") or ""),
        is_active=bool(row.get("is_active")),
        views=int(row.get("views") or 0),
        sales=int(row.get("sales") or 0),
        created_at=created,
    )


def list_courses(client: Client, *, active_only: bool = False) -> list[CourseItem]:
    query = client.table("courses").select("*").order("created_at", desc=True)
    if active_only:
        query = query.eq("is_active", True)
    rows = query.execute().data or []
    return [_to_item(row) for row in rows]


def create_course(client: Client, payload: CourseCreate) -> CourseItem:
    inserted = (
        client.table("courses")
        .insert(
            {
                "title_uz": payload.title_uz.strip(),
                "title_ru": payload.title_ru.strip(),
                "title_en": payload.title_en.strip(),
                "price_uzs": payload.price_uzs,
                "admin_telegram": payload.admin_telegram.replace("@", "").strip() or "Mr_Xusanboy",
                "image_url": payload.image_url.strip(),
                "description_uz": payload.description_uz.strip(),
            }
        )
        .execute()
    )
    row = (inserted.data or [None])[0]
    if not row:
        raise RuntimeError("Failed to create course.")
    return _to_item(row)


def update_course(client: Client, *, course_id: str, payload: CourseUpdate) -> CourseItem:
    patch: dict[str, Any] = {}
    for key in ["title_uz", "title_ru", "title_en", "price_uzs", "image_url", "description_uz", "is_active"]:
        value = getattr(payload, key)
        if value is not None:
            patch[key] = value.strip() if isinstance(value, str) else value
    if payload.admin_telegram is not None:
        patch["admin_telegram"] = payload.admin_telegram.replace("@", "").strip() or "Mr_Xusanboy"

    if not patch:
        raise RuntimeError("No fields to update.")

    updated = client.table("courses").update(patch).eq("id", course_id).execute()
    row = (updated.data or [None])[0]
    if not row:
        raise RuntimeError("Course not found.")
    return _to_item(row)


def delete_course(client: Client, *, course_id: str) -> None:
    client.table("courses").delete().eq("id", course_id).execute()


def get_course_enrolled_count(client: Client, *, course_id: str) -> int:
    response = (
        client.table("user_entitlements")
        .select("id", count="exact")
        .eq("course_id", course_id)
        .eq("is_active", True)
        .execute()
    )
    return int(response.count or 0)


def get_course_comments_count(client: Client, *, course_id: str) -> int:
    legacy = client.table("comments").select("id", count="exact").eq("course_id", course_id).execute()
    app = client.table("app_comments").select("id", count="exact").eq("course_key", course_id).execute()
    return int(legacy.count or 0) + int(app.count or 0)


def _merged_rating_by_user(
    *,
    legacy_rows: list[dict[str, Any]],
    app_rows: list[dict[str, Any]],
    legacy_user_key: str = "user_id",
    app_user_key: str = "user_id",
) -> dict[str, int]:
    """One stars value per user; higher wins if duplicates appear in legacy vs app tables."""
    by_user: dict[str, int] = {}
    for row in legacy_rows:
        uid = str(row.get(legacy_user_key) or "").strip()
        if not uid:
            continue
        s = int(row.get("stars") or 0)
        by_user[uid] = max(by_user.get(uid, 0), s)
    for row in app_rows:
        uid = str(row.get(app_user_key) or "").strip()
        if not uid:
            continue
        s = int(row.get("stars") or 0)
        by_user[uid] = max(by_user.get(uid, 0), s)
    return by_user


def get_course_rating_summary(client: Client, *, course_id: str, user_id: str | None = None) -> tuple[float, int, int | None]:
    legacy_rows = client.table("ratings").select("stars,user_id").eq("course_id", course_id).execute().data or []
    app_rows = (
        client.table("app_ratings").select("stars,user_id").eq("content_key", course_id).execute().data or []
    )
    by_user = _merged_rating_by_user(legacy_rows=legacy_rows, app_rows=app_rows)
    if not by_user:
        return 0.0, 0, None
    stars_list = list(by_user.values())
    rating_count = len(stars_list)
    avg = round(sum(stars_list) / rating_count, 2) if rating_count > 0 else 0.0
    my_rating: int | None = None
    uid = (user_id or "").strip()
    if uid:
        my_rating = by_user.get(uid)
        if my_rating == 0:
            my_rating = None
    return avg, rating_count, my_rating


def upsert_course_rating(client: Client, *, course_id: str, user_id: str, stars: int) -> None:
    try:
        client.table("ratings").upsert(
            {"course_id": course_id, "user_id": user_id, "stars": stars},
            on_conflict="course_id,user_id",
        ).execute()
    except Exception as error:
        logger.warning("ratings upsert failed, falling back to manual update: %s", error)
        existing = (
            client.table("ratings")
            .select("id")
            .eq("course_id", course_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        ).data or []
        if existing:
            client.table("ratings").update({"stars": stars}).eq("course_id", course_id).eq("user_id", user_id).execute()
        else:
            client.table("ratings").insert({"course_id": course_id, "user_id": user_id, "stars": stars}).execute()
    try:
        client.table("app_ratings").upsert(
            {"content_key": course_id, "user_id": user_id, "stars": stars},
            on_conflict="content_key,user_id",
        ).execute()
    except Exception as error:
        logger.warning("app_ratings mirror upsert failed (course rating): %s", error)


def recompute_course_views(client: Client, *, course_id: str) -> int:
    """Unique viewers = users who opened the course (catalog) OR watched >=30s of any lesson."""
    lesson_rows = client.table("lessons").select("id").eq("course_id", course_id).execute().data or []
    lesson_ids = [str(row.get("id") or "") for row in lesson_rows if row.get("id")]
    video_users: set[str] = set()
    if lesson_ids:
        rows = (
            client.table("video_progress")
            .select("user_id")
            .in_("lesson_id", lesson_ids)
            .gte("watched_sec", 30)
            .execute()
        ).data or []
        video_users = {str(row.get("user_id") or "") for row in rows if row.get("user_id")}

    catalog_users: set[str] = set()
    try:
        catalog_rows = (
            client.table("course_catalog_views").select("user_id").eq("course_id", course_id).execute().data or []
        )
        catalog_users = {str(row.get("user_id") or "") for row in catalog_rows if row.get("user_id")}
    except Exception as error:
        logger.warning("course_catalog_views not available (run migrations?): %s", error)

    viewers = video_users | catalog_users
    views = len(viewers)
    client.table("courses").update({"views": views}).eq("id", course_id).execute()
    return views


def record_catalog_view(client: Client, *, course_id: str, user_id: str) -> int:
    try:
        client.table("course_catalog_views").upsert(
            {"course_id": course_id, "user_id": user_id},
            on_conflict="course_id,user_id",
        ).execute()
    except Exception as error:
        logger.warning("record_catalog_view upsert failed: %s", error)
    return recompute_course_views(client, course_id=course_id)


def track_course_view(
    client: Client,
    *,
    course_id: str,
    lesson_id: str,
    user_id: str,
    watched_sec: int,
    completed: bool,
) -> int:
    lesson = (
        client.table("lessons")
        .select("id,course_id")
        .eq("id", lesson_id)
        .eq("course_id", course_id)
        .limit(1)
        .execute()
    ).data or []
    if not lesson:
        raise RuntimeError("Lesson does not belong to this course.")

    existing = (
        client.table("video_progress")
        .select("id,watched_sec,completed")
        .eq("lesson_id", lesson_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    ).data or []
    next_watched_sec = watched_sec
    next_completed = completed
    prev_watched_sec = 0
    if existing:
        current = existing[0]
        prev_watched_sec = int(current.get("watched_sec") or 0)
        next_watched_sec = max(prev_watched_sec, watched_sec)
        next_completed = bool(current.get("completed")) or completed
        client.table("video_progress").update(
            {"watched_sec": next_watched_sec, "completed": next_completed}
        ).eq("lesson_id", lesson_id).eq("user_id", user_id).execute()
    else:
        client.table("video_progress").insert(
            {"lesson_id": lesson_id, "user_id": user_id, "watched_sec": next_watched_sec, "completed": next_completed}
        ).execute()

    # Kunlik/haftalik/oylik/yillik reyting uchun qo'shimcha ko'rilgan vaqt (delta) logga yoziladi.
    delta_sec = next_watched_sec - prev_watched_sec
    if delta_sec > 0:
        try:
            client.table("daily_study_log").insert(
                {"user_id": user_id, "seconds": delta_sec}
            ).execute()
        except Exception:
            logger.exception("courses.view daily_study_log insert failed user_id=%s", user_id)

    views = recompute_course_views(client, course_id=course_id)
    logger.info(
        "courses.view tracked course_id=%s lesson_id=%s user_id=%s watched_sec=%s completed=%s views=%s",
        course_id,
        lesson_id,
        user_id,
        next_watched_sec,
        next_completed,
        views,
    )
    sync_user_rank_from_video_progress(client, user_id=user_id)
    return views


def list_user_video_progress(
    client: Client,
    *,
    user_id: str,
    course_id: str | None = None,
    lesson_id: str | None = None,
) -> list[dict[str, Any]]:
    query = client.table("video_progress").select("lesson_id,watched_sec,completed").eq("user_id", user_id)
    if lesson_id:
        query = query.eq("lesson_id", lesson_id)
    rows = query.execute().data or []
    if not rows:
        return []
    lesson_ids = [str(row.get("lesson_id") or "") for row in rows if row.get("lesson_id")]
    if not lesson_ids:
        return []
    lesson_query = client.table("lessons").select("id,course_id").in_("id", lesson_ids)
    if course_id:
        lesson_query = lesson_query.eq("course_id", course_id)
    lesson_rows = lesson_query.execute().data or []
    course_by_lesson = {
        str(row.get("id") or ""): str(row.get("course_id") or "")
        for row in lesson_rows
        if row.get("id") and row.get("course_id")
    }
    items: list[dict[str, Any]] = []
    for row in rows:
        lid = str(row.get("lesson_id") or "")
        cid = course_by_lesson.get(lid)
        if not cid:
            continue
        items.append(
            {
                "course_id": cid,
                "lesson_id": lid,
                "watched_sec": int(row.get("watched_sec") or 0),
                "completed": bool(row.get("completed")),
            }
        )
    return items


def list_section_progress(
    client: Client,
    *,
    course_id: str,
    user_id: str,
) -> list[dict[str, Any]]:
    sections = (
        client.table("course_sections")
        .select("id")
        .eq("course_id", course_id)
        .order("order_no", desc=False)
        .execute()
    ).data or []
    section_ids = [str(row.get("id") or "") for row in sections if row.get("id")]
    if not section_ids:
        return []
    lesson_rows = (
        client.table("lessons")
        .select("id,section_id")
        .eq("course_id", course_id)
        .in_("section_id", section_ids)
        .execute()
    ).data or []
    lessons_by_section: dict[str, list[str]] = {}
    for row in lesson_rows:
        sid = str(row.get("section_id") or "")
        lid = str(row.get("id") or "")
        if not sid or not lid:
            continue
        lessons_by_section.setdefault(sid, []).append(lid)
    completed_lesson_ids = {
        str(row.get("lesson_id") or "")
        for row in (
            client.table("video_progress")
            .select("lesson_id")
            .eq("user_id", user_id)
            .eq("completed", True)
            .execute()
        ).data
        or []
        if row.get("lesson_id")
    }
    items: list[dict[str, Any]] = []
    for sid in section_ids:
        lesson_ids = lessons_by_section.get(sid, [])
        total = len(lesson_ids)
        completed = len([lesson_id for lesson_id in lesson_ids if lesson_id in completed_lesson_ids])
        percent = round((completed / total) * 100, 2) if total > 0 else 0.0
        items.append(
            {
                "section_id": sid,
                "total_lessons": total,
                "completed_lessons": completed,
                "progress_percent": percent,
            }
        )
    return items
