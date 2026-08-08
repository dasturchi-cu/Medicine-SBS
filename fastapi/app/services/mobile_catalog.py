from __future__ import annotations

import logging
from ..neon_client import Client

from ..schemas.mobile_catalog import MobileCatalogResponse, MobileCourse, MobileLesson, MobileSection

logger = logging.getLogger(__name__)


def get_mobile_catalog(client: Client) -> MobileCatalogResponse:
    try:
        courses_rows = (
            client.table("courses")
            .select("id,title_uz,title_ru,title_en,admin_telegram,price_uzs,image_url,description_uz")
            .eq("is_active", True)
            .order("created_at", desc=False)
            .execute()
        ).data or []

        sections_rows = (
            client.table("course_sections")
            .select("id,course_id,title,order_no")
            .eq("is_active", True)
            .order("order_no", desc=False)
            .execute()
        ).data or []

        lessons_rows = (
            client.table("lessons")
            .select("id,course_id,section_id,title,video_url,duration_sec,order_no,is_free")
            .order("order_no", desc=False)
            .execute()
        ).data or []

        ratings_rows = client.table("ratings").select("course_id,stars,user_id").execute().data or []
        app_rating_rows = client.table("app_ratings").select("content_key,stars,user_id").execute().data or []
        stars_by_course_user: dict[str, dict[str, int]] = {}
        for row in ratings_rows:
            course_id = str(row.get("course_id") or "")
            uid = str(row.get("user_id") or "").strip()
            if not course_id or not uid:
                continue
            s = int(row.get("stars") or 0)
            inner = stars_by_course_user.setdefault(course_id, {})
            inner[uid] = max(inner.get(uid, 0), s)
        for row in app_rating_rows:
            course_id = str(row.get("content_key") or "")
            uid = str(row.get("user_id") or "").strip()
            if not course_id or not uid:
                continue
            s = int(row.get("stars") or 0)
            inner = stars_by_course_user.setdefault(course_id, {})
            inner[uid] = max(inner.get(uid, 0), s)
        ratings_map: dict[str, list[int]] = {
            cid: list(users.values()) for cid, users in stars_by_course_user.items() if users
        }

        lessons_by_section: dict[str, list[MobileLesson]] = {}
        root_lessons_by_course: dict[str, list[MobileLesson]] = {}
        for row in lessons_rows:
            lesson = MobileLesson(
                id=str(row.get("id") or ""),
                title=str(row.get("title") or ""),
                video_url=str(row.get("video_url") or ""),
                duration_sec=int(row.get("duration_sec") or 0),
                order_no=int(row.get("order_no") or 1),
                is_free=bool(row.get("is_free")),
            )
            section_id = str(row.get("section_id") or "")
            course_id = str(row.get("course_id") or "")
            if section_id:
                lessons_by_section.setdefault(section_id, []).append(lesson)
            elif course_id:
                root_lessons_by_course.setdefault(course_id, []).append(lesson)

        sections_by_course: dict[str, list[MobileSection]] = {}
        for row in sections_rows:
            course_id = str(row.get("course_id") or "")
            if not course_id:
                continue
            section_id = str(row.get("id") or "")
            sections_by_course.setdefault(course_id, []).append(
                MobileSection(
                    id=section_id,
                    title=str(row.get("title") or ""),
                    order_no=int(row.get("order_no") or 1),
                    lessons=lessons_by_section.get(section_id, []),
                )
            )

        items: list[MobileCourse] = []
        for row in courses_rows:
            course_id = str(row.get("id") or "")
            sections = list(sections_by_course.get(course_id, []))
            root_lessons = root_lessons_by_course.get(course_id, [])
            if root_lessons:
                sections.insert(
                    0,
                    MobileSection(
                        id=f"{course_id}_root",
                        title="Asosiy darslar",
                        order_no=0,
                        lessons=sorted(root_lessons, key=lambda item: item.order_no),
                    ),
                )
            items.append(
                # Ratings are resolved on backend to keep mobile/admin in sync.
                MobileCourse(
                    id=course_id,
                    title_uz=str(row.get("title_uz") or ""),
                    title_ru=str(row.get("title_ru") or ""),
                    title_en=str(row.get("title_en") or ""),
                    admin_telegram=str(row.get("admin_telegram") or ""),
                    price_uzs=float(row.get("price_uzs") or 0),
                    image_url=str(row.get("image_url") or ""),
                    description_uz=str(row.get("description_uz") or ""),
                    rating_avg=round(sum(ratings_map.get(course_id, [])) / len(ratings_map.get(course_id, [])), 2)
                    if ratings_map.get(course_id)
                    else 0,
                    rating_count=len(ratings_map.get(course_id, [])),
                    sections=sections,
                )
            )
        return MobileCatalogResponse(items=items)
    except Exception as error:
        logger.warning("Failed to load mobile catalog from Supabase: %s", error)
        return MobileCatalogResponse(items=[])
