-- Bir martalik: mavjud video_progress dan user_ranks ni to‘ldirish.
-- Formula og‘irliklari backend/fastapi/app/services/ranking.py bilan mos kelishi kerak.

WITH agg AS (
  SELECT
    user_id,
    round((sum(watched_sec)::numeric / 3600.0), 2) AS hours,
    (count(*) FILTER (WHERE completed IS TRUE))::int AS completed_n
  FROM public.video_progress
  GROUP BY user_id
),
scored AS (
  SELECT
    user_id,
    hours,
    completed_n,
    round(hours * 10.0 + completed_n::numeric * 15.0, 2) AS watch_score
  FROM agg
)
INSERT INTO public.user_ranks (
  user_id,
  total_watched_hours,
  completed_lessons,
  total_score,
  quiz_minutes,
  test_points,
  updated_at
)
SELECT
  s.user_id,
  s.hours,
  s.completed_n,
  round(coalesce(ur.test_points, 0) + s.watch_score, 2),
  coalesce(ur.quiz_minutes, 0),
  coalesce(ur.test_points, 0),
  now()
FROM scored s
LEFT JOIN public.user_ranks ur ON ur.user_id = s.user_id
ON CONFLICT (user_id) DO UPDATE SET
  total_watched_hours = EXCLUDED.total_watched_hours,
  completed_lessons = EXCLUDED.completed_lessons,
  total_score = round(
    public.user_ranks.test_points
    + round(EXCLUDED.total_watched_hours * 10.0 + EXCLUDED.completed_lessons::numeric * 15.0, 2),
    2
  ),
  updated_at = now();
