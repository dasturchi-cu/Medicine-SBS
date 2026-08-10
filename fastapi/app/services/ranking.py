from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Any

from ..neon_client import Client

from ..schemas.ranking import RankingItem

# Video va yakunlangan darslar uchun umumiy ball (test ballari — alohida `test_points`).
_WATCH_HOURS_WEIGHT = 10.0
_COMPLETED_LESSON_BONUS = 15.0


def compute_watch_score(*, total_watched_hours: float, completed_lessons: int) -> float:
    return round(total_watched_hours * _WATCH_HOURS_WEIGHT + completed_lessons * _COMPLETED_LESSON_BONUS, 2)


def ensure_user_rank_row(client: Client, *, user_id: str) -> dict[str, Any]:
    row_resp = client.table("user_ranks").select("*").eq("user_id", user_id).limit(1).execute()
    existing = (row_resp.data or [None])[0]
    if existing:
        return existing
    inserted = (
        client.table("user_ranks")
        .insert(
            {
                "user_id": user_id,
                "total_watched_hours": 0,
                "completed_lessons": 0,
                "total_score": 0,
                "quiz_minutes": 0,
                "test_points": 0,
            }
        )
        .execute()
    )
    return (inserted.data or [None])[0] or {}


def sync_user_rank_from_video_progress(client: Client, *, user_id: str) -> None:
    """video_progress dan soatlar/yakunlar yoziladi; total_score = test_points + video formula."""
    rows = (
        client.table("video_progress").select("watched_sec,completed").eq("user_id", user_id).execute()
    ).data or []
    total_sec = sum(int(r.get("watched_sec") or 0) for r in rows)
    completed_n = sum(1 for r in rows if r.get("completed"))
    hours = round(total_sec / 3600.0, 2)
    rank = ensure_user_rank_row(client, user_id=user_id)
    tp = float(rank.get("test_points") or 0)
    watch_score = compute_watch_score(total_watched_hours=hours, completed_lessons=completed_n)
    total = round(tp + watch_score, 2)
    client.table("user_ranks").update(
        {
            "total_watched_hours": hours,
            "completed_lessons": completed_n,
            "total_score": total,
            "updated_at": datetime.utcnow().isoformat(),
        }
    ).eq("user_id", user_id).execute()


_VALID_PERIODS = {"daily", "weekly", "monthly", "yearly", "overall"}

_SCHEMA_ENSURED = False


def _ensure_ranking_schema(client: Client) -> None:
    """daily_study_log.source ustuni + ranking_by_period(p_source bilan) mavjudligini
    kafolatlaydi. Shunday qilib Pomodoro reytingi FAQAT pomodoro sessiyalarini,
    video reytingi faqat videoni hisoblaydi (source bo'yicha filtr)."""
    global _SCHEMA_ENSURED
    if _SCHEMA_ENSURED:
        return
    try:
        client.execute_sql(
            "ALTER TABLE public.daily_study_log ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'video'"
        )
        client.execute_sql("DROP FUNCTION IF EXISTS public.ranking_by_period(date, integer, text)")
        client.execute_sql(
            """
            CREATE FUNCTION public.ranking_by_period(p_since date, p_limit integer, p_source text)
            RETURNS TABLE (user_id uuid, full_name text, seconds bigint, rnk bigint)
            LANGUAGE sql STABLE AS $func$
              SELECT d.user_id,
                     coalesce(u.full_name, 'Foydalanuvchi') AS full_name,
                     sum(d.seconds)::bigint AS seconds,
                     row_number() over (order by sum(d.seconds) desc) AS rnk
              FROM public.daily_study_log d
              LEFT JOIN public.users u ON u.id = d.user_id
              WHERE d.study_date >= p_since
                AND (p_source IS NULL OR d.source = p_source)
              GROUP BY d.user_id, u.full_name
              HAVING sum(d.seconds) > 0
              ORDER BY seconds DESC
              LIMIT p_limit;
            $func$
            """
        )
    except Exception:
        pass
    finally:
        _SCHEMA_ENSURED = True


def _period_start(period: str) -> date | None:
    """Davr boshlanish sanasi (Asia/Tashkent, UTC+5). `overall` uchun None (butun tarix)."""
    today = (datetime.utcnow() + timedelta(hours=5)).date()
    if period == "daily":
        return today
    if period == "weekly":
        return today - timedelta(days=today.weekday())  # joriy haftaning dushanbasi
    if period == "monthly":
        return today.replace(day=1)
    if period == "yearly":
        return today.replace(month=1, day=1)
    return None


def record_study_seconds(client: Client, *, user_id: str, seconds: int, source: str = "video") -> None:
    """O'qish vaqtini daily_study_log'ga qo'shadi. source: 'video' yoki 'pomodoro'."""
    if seconds <= 0:
        return
    client.table("daily_study_log").insert(
        {"user_id": user_id, "seconds": int(seconds), "source": source}
    ).execute()


def _list_ranking_period(
    client: Client, *, since: date, limit: int, source: str | None = None
) -> list[RankingItem]:
    params: dict[str, Any] = {"p_since": since.isoformat(), "p_limit": limit}
    if source:
        params["p_source"] = source
    resp = client.rpc("ranking_by_period", params).execute()
    rows = resp.data or []
    items: list[RankingItem] = []
    for row in rows:
        seconds = float(row.get("seconds") or 0)
        items.append(
            RankingItem(
                user_id=str(row.get("user_id") or ""),
                full_name=str(row.get("full_name") or "Foydalanuvchi"),
                total_score=seconds,
                # Reyting sahifasida faqat o'qish vaqti ko'rsatiladi (minut).
                quiz_minutes=round(seconds / 60.0),
                rank=int(row.get("rnk") or 0),
            )
        )
    return items


def list_ranking(
    client: Client, *, limit: int = 50, period: str = "overall", source: str | None = None
) -> list[RankingItem]:
    _ensure_ranking_schema(client)
    period = period if period in _VALID_PERIODS else "overall"
    since = _period_start(period)
    # overall + source (masalan Pomodoro): butun tarixni daily_study_log'dan, source bo'yicha
    # o'qiymiz — aks holda user_ranks (faqat video) qaytib, pomodoro reytingiga video qo'shilardi.
    if since is None and source:
        since = date(1970, 1, 1)
    if since is not None:
        return _list_ranking_period(client, since=since, limit=limit, source=source)
    ranks_resp = (
        client.table("user_ranks")
        .select("user_id,total_score,total_watched_hours")
        .order("total_score", desc=True)
        .limit(limit)
        .execute()
    )
    ranks = ranks_resp.data or []
    if not ranks:
        return []
    user_ids = [row["user_id"] for row in ranks]
    users_resp = client.table("users").select("id,full_name").in_("id", user_ids).execute()
    names = {str(row.get("id")): str(row.get("full_name") or "Foydalanuvchi") for row in (users_resp.data or [])}
    items: list[RankingItem] = []
    for idx, row in enumerate(ranks, start=1):
        uid = str(row.get("user_id") or "")
        watch_hours = float(row.get("total_watched_hours") or 0)
        # Reyting sahifasida faqat video ko'rish vaqti ko'rsatiladi.
        study_minutes = round(watch_hours * 60.0)
        items.append(
            RankingItem(
                user_id=uid,
                full_name=names.get(uid, "Foydalanuvchi"),
                total_score=float(row.get("total_score") or 0),
                quiz_minutes=float(study_minutes),
                rank=idx,
            )
        )
    return items
