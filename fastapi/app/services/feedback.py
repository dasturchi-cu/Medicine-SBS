import logging

from ..neon_client import Client

from .courses import _merged_rating_by_user

logger = logging.getLogger(__name__)


def get_feedback_stats(client: Client, *, content_key: str, user_id: str | None = None):
    comments_count = int(
        (
            client.table("app_comments")
            .select("id", count="exact")
            .eq("course_key", content_key)
            .execute()
        ).count
        or 0
    )
    app_rows = (
        client.table("app_ratings")
        .select("stars,user_id")
        .eq("content_key", content_key)
        .execute()
    ).data or []
    legacy_rows = (
        client.table("ratings")
        .select("stars,user_id")
        .eq("course_id", content_key)
        .execute()
    ).data or []
    by_user = _merged_rating_by_user(legacy_rows=legacy_rows, app_rows=app_rows)
    if not by_user:
        return comments_count, 0.0, 0, None
    stars_list = list(by_user.values())
    rating_count = len(stars_list)
    rating_avg = round(sum(stars_list) / rating_count, 2) if rating_count > 0 else 0.0
    my_rating = None
    uid = (user_id or "").strip()
    if uid:
        my_rating = by_user.get(uid)
        if my_rating == 0:
            my_rating = None
    return comments_count, rating_avg, rating_count, my_rating


def upsert_feedback_rating(client: Client, *, content_key: str, user_id: str, stars: int) -> None:
    client.table("app_ratings").upsert(
        {"content_key": content_key, "user_id": user_id, "stars": stars},
        on_conflict="content_key,user_id",
    ).execute()
    try:
        course_row = client.table("courses").select("id").eq("id", content_key).limit(1).execute().data or []
        if course_row:
            client.table("ratings").upsert(
                {"course_id": content_key, "user_id": user_id, "stars": stars},
                on_conflict="course_id,user_id",
            ).execute()
    except Exception as error:
        logger.warning("ratings mirror upsert failed (feedback rating): %s", error)
