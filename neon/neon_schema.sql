-- =====================================================================
-- Medicine:SBS — NEON (toza Postgres) schema
-- Supabase migratsiyalaridan avtomatik yasalgan; realtime/RLS/storage QISMLARSIZ.
-- Neon SQL Editor'da bir marta to'liq Run qiling.
-- Xavfsizlik: backend Neon'ga to'g'ridan (to'liq huquq) ulanadi; RLS shart emas.
-- =====================================================================

-- ---------- 001_initial ----------
-- Initial schema for real backend transition (FastAPI + Supabase Postgres)
-- Focus: auth/device control, course access, notifications, view tracking.

create extension if not exists "pgcrypto";

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  phone text not null unique,
  full_name text not null default '',
  is_blocked boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  device_id text not null,
  platform text not null default 'android',
  is_primary boolean not null default true,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (user_id, device_id)
);

create unique index if not exists user_devices_primary_one_per_user_idx
  on public.user_devices (user_id)
  where is_primary = true;

create table if not exists public.courses (
  id uuid primary key default gen_random_uuid(),
  title_uz text not null,
  title_ru text not null default '',
  title_en text not null default '',
  price_uzs numeric(12, 2) not null default 0,
  admin_telegram text not null default 'Mr_Xusanboy',
  image_url text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.course_sections (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  title text not null,
  order_no int not null default 1,
  price_uzs numeric(12, 2) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (course_id, order_no)
);

create table if not exists public.lessons (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  section_id uuid references public.course_sections(id) on delete set null,
  title text not null,
  video_url text not null,
  duration_sec int not null default 0,
  order_no int not null default 1,
  is_free boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists lessons_course_idx on public.lessons(course_id);
create index if not exists lessons_section_idx on public.lessons(section_id);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  course_id uuid references public.courses(id) on delete set null,
  section_id uuid references public.course_sections(id) on delete set null,
  amount_uzs numeric(12, 2) not null,
  provider text not null default 'manual',
  status text not null default 'pending',
  transaction_ref text not null default '',
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.user_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  course_id uuid references public.courses(id) on delete cascade,
  section_id uuid references public.course_sections(id) on delete cascade,
  source text not null default 'admin_grant',
  granted_by text not null default 'system',
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists user_entitlements_unique_active_idx
  on public.user_entitlements (user_id, course_id, section_id)
  where is_active = true;

create table if not exists public.video_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  watched_sec int not null default 0,
  completed boolean not null default false,
  updated_at timestamptz not null default now(),
  unique (user_id, lesson_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  parent_id uuid references public.comments(id) on delete cascade,
  text text not null,
  hearts_count int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.comment_reactions (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (comment_id, user_id)
);

create table if not exists public.ratings (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  stars int not null check (stars between 1 and 5),
  created_at timestamptz not null default now(),
  unique (course_id, user_id)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  message text not null,
  image_url text not null default '',
  created_by text not null default 'admin',
  created_at timestamptz not null default now()
);

create table if not exists public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  delivered_at timestamptz not null default now(),
  viewed_at timestamptz,
  unique (notification_id, user_id)
);

create index if not exists notification_deliveries_user_idx
  on public.notification_deliveries(user_id, delivered_at desc);

create table if not exists public.user_ranks (
  user_id uuid primary key references public.users(id) on delete cascade,
  total_watched_hours numeric(10, 2) not null default 0,
  completed_lessons int not null default 0,
  total_score numeric(10, 2) not null default 0,
  updated_at timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_users_touch_updated_at on public.users;
create trigger trg_users_touch_updated_at
before update on public.users
for each row execute function public.touch_updated_at();

drop trigger if exists trg_courses_touch_updated_at on public.courses;
create trigger trg_courses_touch_updated_at
before update on public.courses
for each row execute function public.touch_updated_at();

-- Realtime for key admin<->app entities

-- ---------- 002_add_course_description ----------
alter table if exists public.courses
  add column if not exists description_uz text not null default '';

-- ---------- 002_slides_tests_and_rank ----------
-- Slides + Tests + Rank extension

  create table if not exists public.home_slides (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    subtitle text not null default '',
    image_url text not null default '',
    button_text text not null default 'Boshlash',
    course_id uuid references public.courses(id) on delete set null,
    order_no int not null default 1,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );

  create unique index if not exists home_slides_order_unique_idx
    on public.home_slides(order_no);

  create table if not exists public.quizzes (
    id uuid primary key default gen_random_uuid(),
    course_id uuid references public.courses(id) on delete set null,
    section_id uuid references public.course_sections(id) on delete set null,
  lesson_id text,
    title text not null,
    description text not null default '',
    estimated_minutes int not null default 10,
    is_active boolean not null default true,
    created_at timestamptz not null default now()
  );

alter table public.quizzes add column if not exists lesson_id text;
  create index if not exists quizzes_lesson_idx on public.quizzes(lesson_id);

  create table if not exists public.quiz_questions (
    id uuid primary key default gen_random_uuid(),
    quiz_id uuid not null references public.quizzes(id) on delete cascade,
    question_text text not null,
    option_a text not null,
    option_b text not null,
    option_c text not null,
    option_d text not null,
    correct_option text not null check (correct_option in ('A', 'B', 'C', 'D')),
    order_no int not null default 1,
    created_at timestamptz not null default now(),
    unique (quiz_id, order_no)
  );

  create table if not exists public.quiz_attempts (
    id uuid primary key default gen_random_uuid(),
    quiz_id uuid not null references public.quizzes(id) on delete cascade,
    user_id uuid not null references public.users(id) on delete cascade,
    score_percent numeric(5, 2) not null default 0,
    correct_count int not null default 0,
    total_questions int not null default 0,
    duration_minutes numeric(8, 2) not null default 0,
    created_at timestamptz not null default now()
  );

  create index if not exists quiz_attempts_user_idx
    on public.quiz_attempts(user_id, created_at desc);

  create table if not exists public.rank_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    event_type text not null,
    points numeric(10, 2) not null default 0,
    duration_minutes numeric(8, 2) not null default 0,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
  );

  alter table public.user_ranks add column if not exists quiz_minutes numeric(10, 2) not null default 0;
  alter table public.user_ranks add column if not exists test_points numeric(10, 2) not null default 0;

  drop trigger if exists trg_home_slides_touch_updated_at on public.home_slides;
  create trigger trg_home_slides_touch_updated_at
  before update on public.home_slides
  for each row execute function public.touch_updated_at();

-- ---------- 003_app_comments_and_likes ----------
-- App comments and likes with text course keys (compatible with current Flutter IDs)

create table if not exists public.app_comments (
  id uuid primary key default gen_random_uuid(),
  course_key text not null,
  user_id text not null,
  author_name text not null default '',
  text text not null,
  likes_count int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists app_comments_course_idx
  on public.app_comments(course_key, created_at desc);

create table if not exists public.app_comment_likes (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.app_comments(id) on delete cascade,
  user_id text not null,
  created_at timestamptz not null default now(),
  unique (comment_id, user_id)
);

-- ---------- 004_lesson_slides ----------
-- Lesson-level slides

create table if not exists public.lesson_slides (
  id uuid primary key default gen_random_uuid(),
  lesson_id text not null,
  title text not null,
  body text not null default '',
  image_url text not null default '',
  order_no int not null default 1,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists lesson_slides_unique_order_idx
  on public.lesson_slides(lesson_id, order_no);

create index if not exists lesson_slides_lesson_idx
  on public.lesson_slides(lesson_id, created_at desc);

-- ---------- 005_courses_and_banners_admin ----------
-- Admin panel real CRUD support for courses and banners

alter table public.courses
  add column if not exists views int not null default 0;

alter table public.courses
  add column if not exists sales int not null default 0;

create table if not exists public.course_banners (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  message text not null default '',
  image_url text not null default '',
  price_label text not null default '',
  course_id uuid references public.courses(id) on delete set null,
  telegram text not null default 'Mr_Xusanboy',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_course_banners_touch_updated_at on public.course_banners;
create trigger trg_course_banners_touch_updated_at
before update on public.course_banners
for each row execute function public.touch_updated_at();

-- ---------- 006_app_comment_threads_and_view_tracking ----------
alter table if exists public.app_comments
  add column if not exists parent_id uuid references public.app_comments(id) on delete cascade;

alter table if exists public.app_comments
  add column if not exists replies_count int not null default 0;

create index if not exists app_comments_parent_idx
  on public.app_comments(parent_id, created_at asc);

-- ---------- 007_course_catalog_views ----------
-- Deduped "opened course" impressions (mobile) for views alongside video watch progress.

create table if not exists public.course_catalog_views (
  course_id uuid not null references public.courses(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (course_id, user_id)
);

create index if not exists course_catalog_views_user_idx
  on public.course_catalog_views(user_id, viewed_at desc);

-- ---------- 008_app_ratings ----------
create table if not exists public.app_ratings (
  id uuid primary key default gen_random_uuid(),
  content_key text not null,
  user_id text not null,
  stars int not null check (stars between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (content_key, user_id)
);

create index if not exists app_ratings_content_idx
  on public.app_ratings(content_key);

-- ---------- 009_realtime_hardening ----------
-- Realtime hardening for admin <-> app sync.
-- Ensures key entities are part of realtime publication and have reliable updated_at values.

alter table if exists public.app_comments
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.lessons
  add column if not exists updated_at timestamptz not null default now();

alter table if exists public.video_progress
  add column if not exists created_at timestamptz not null default now();

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_app_comments_touch_updated_at on public.app_comments;
create trigger trg_app_comments_touch_updated_at
before update on public.app_comments
for each row execute function public.touch_updated_at();

drop trigger if exists trg_lessons_touch_updated_at on public.lessons;
create trigger trg_lessons_touch_updated_at
before update on public.lessons
for each row execute function public.touch_updated_at();

drop trigger if exists trg_app_ratings_touch_updated_at on public.app_ratings;
create trigger trg_app_ratings_touch_updated_at
before update on public.app_ratings
for each row execute function public.touch_updated_at();

-- ---------- 010_security_rls_content ----------
-- Security, RLS, analytics, and content modules foundation.

create extension if not exists "pgcrypto";

create table if not exists public.auth_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  device_id text not null,
  session_token text not null unique,
  is_active boolean not null default true,
  invalidated_at timestamptz,
  invalidated_reason text not null default '',
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index if not exists auth_sessions_user_active_idx
  on public.auth_sessions(user_id, is_active);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_type text not null default 'system',
  actor_id text not null default '',
  action text not null,
  entity_type text not null,
  entity_id text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_logs_entity_idx
  on public.audit_logs(entity_type, entity_id, created_at desc);

create table if not exists public.notification_click_events (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  clicked_at timestamptz not null default now(),
  unique (notification_id, user_id)
);

create index if not exists notification_click_events_by_notification_idx
  on public.notification_click_events(notification_id, clicked_at desc);

create table if not exists public.book_items (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  cover_image_url text not null default '',
  file_url text not null default '',
  file_mime text not null default 'application/pdf',
  page_count int not null default 0,
  course_id uuid references public.courses(id) on delete set null,
  lesson_id uuid references public.lessons(id) on delete set null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.book_progress (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.book_items(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  page_no int not null default 1,
  progress_percent numeric(5,2) not null default 0,
  updated_at timestamptz not null default now(),
  unique (book_id, user_id)
);

create index if not exists book_progress_user_idx
  on public.book_progress(user_id, updated_at desc);

create table if not exists public.lesson_assets (
  id uuid primary key default gen_random_uuid(),
  course_id uuid references public.courses(id) on delete cascade,
  lesson_id uuid references public.lessons(id) on delete cascade,
  title text not null,
  description text not null default '',
  file_url text not null,
  file_type text not null check (file_type in ('pdf', 'ppt')),
  order_no int not null default 1,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (lesson_id, order_no)
);

create index if not exists lesson_assets_course_idx
  on public.lesson_assets(course_id, created_at desc);

drop trigger if exists trg_book_items_touch_updated_at on public.book_items;
create trigger trg_book_items_touch_updated_at
before update on public.book_items
for each row execute function public.touch_updated_at();

drop trigger if exists trg_lesson_assets_touch_updated_at on public.lesson_assets;
create trigger trg_lesson_assets_touch_updated_at
before update on public.lesson_assets
for each row execute function public.touch_updated_at();

create or replace function public.invalidate_user_sessions()
returns trigger
language plpgsql
as $$
begin
  if new.is_blocked = true and coalesce(old.is_blocked, false) = false then
    update public.auth_sessions
      set is_active = false,
          invalidated_at = now(),
          invalidated_reason = 'blocked_by_admin'
      where user_id = new.id and is_active = true;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_users_invalidate_sessions on public.users;
create trigger trg_users_invalidate_sessions
after update on public.users
for each row execute function public.invalidate_user_sessions();

create or replace function public.app_comments_sync_counters()
returns trigger
language plpgsql
as $$
declare
  target_id uuid;
  next_likes int;
  next_replies int;
begin
  target_id := coalesce(new.comment_id, old.comment_id);
  if target_id is not null then
    select count(*)::int into next_likes
    from public.app_comment_likes where comment_id = target_id;

    update public.app_comments set likes_count = coalesce(next_likes, 0) where id = target_id;
  end if;

  target_id := coalesce(new.parent_id, old.parent_id);
  if target_id is not null then
    select count(*)::int into next_replies
    from public.app_comments where parent_id = target_id;

    update public.app_comments set replies_count = coalesce(next_replies, 0) where id = target_id;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_app_comment_likes_sync_counts on public.app_comment_likes;
create trigger trg_app_comment_likes_sync_counts
after insert or delete on public.app_comment_likes
for each row execute function public.app_comments_sync_counters();

drop trigger if exists trg_app_comments_sync_reply_counts on public.app_comments;
create trigger trg_app_comments_sync_reply_counts
after insert or delete on public.app_comments
for each row execute function public.app_comments_sync_counters();

-- ---------- 011_books_and_slides_hardening ----------
create table if not exists public.book_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_at timestamptz not null default now()
);

alter table if exists public.book_items
  add column if not exists author text not null default '',
  add column if not exists category_id uuid references public.book_categories(id) on delete set null;

create index if not exists book_items_category_idx
  on public.book_items(category_id, created_at desc);

alter table if exists public.lesson_assets
  add column if not exists preview_image_url text not null default '';

create table if not exists public.slide_progress (
  id uuid primary key default gen_random_uuid(),
  lesson_asset_id uuid not null references public.lesson_assets(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  page_no int not null default 1,
  progress_percent numeric(5,2) not null default 0,
  updated_at timestamptz not null default now(),
  unique (lesson_asset_id, user_id)
);

create index if not exists slide_progress_user_idx
  on public.slide_progress(user_id, updated_at desc);

-- ---------- 013_remove_placeholder_course_banners ----------
-- Sinov / chalkash placeholder reklamalar (Kanal yangiliklari kartochkalari)
-- Qo'lda qo'shilgan "test" kabi yozuvlarni olib tashlash — kerak bo'lsa shartni tahrirlang.
delete from public.course_banners
where lower(btrim(title)) in ('test', 'tes');

-- ---------- 014_user_devices_fcm ----------
-- FCM device tokens for push notifications (admin broadcasts).

alter table public.user_devices
  add column if not exists fcm_token text;

comment on column public.user_devices.fcm_token is 'Firebase Cloud Messaging registration token for this device; updated on mobile login.';

-- ---------- 015_user_ranks_backfill_from_video ----------
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

-- ---------- 016_fix_app_comments_sync_counters_trigger ----------
-- Bir xil trigger funksiyasi ikki xil jadval uchun ishlatilgan:
-- app_comment_likes qatorida parent_id yo'q, app_comments da esa comment_id yo'q.
-- NOTO'G'RI ustunlarga (NEW.parent_id / NEW.comment_id) murojaat qilish INSERT/DELETE ni buzgan.

create or replace function public.app_comments_sync_counters()
returns trigger
language plpgsql
as $$
declare
  target_id uuid;
  next_likes int;
  next_replies int;
begin
  if tg_table_name = 'app_comment_likes' then
    target_id := coalesce(new.comment_id, old.comment_id);
    if target_id is not null then
      select count(*)::int into next_likes
      from public.app_comment_likes where comment_id = target_id;

      update public.app_comments set likes_count = coalesce(next_likes, 0) where id = target_id;
    end if;
    return coalesce(new, old);
  end if;

  if tg_table_name = 'app_comments' then
    target_id := coalesce(new.parent_id, old.parent_id);
    if target_id is not null then
      select count(*)::int into next_replies
      from public.app_comments where parent_id = target_id;

      update public.app_comments set replies_count = coalesce(next_replies, 0) where id = target_id;
    end if;
    return coalesce(new, old);
  end if;

  return coalesce(new, old);
end;
$$;

-- ---------- 017_daily_study_log ----------
-- Kunlik/haftalik/oylik/yillik reyting uchun vaqt bo'yicha o'qish logi.
-- Har bir video ko'rish delta'si (qo'shimcha soniyalar) shu jadvalga yoziladi.
-- `user_ranks` faqat umumiy (jami) hisob uchun ishlatiladi; davrlar shu logdan hisoblanadi.

create table if not exists public.daily_study_log (
  id bigserial primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  -- Sana O'zbekiston vaqti (Asia/Tashkent, UTC+5) bo'yicha — kunlik chegara
  -- foydalanuvchi uchun to'g'ri bo'lishi uchun.
  study_date date not null default (now() at time zone 'Asia/Tashkent')::date,
  seconds integer not null,
  created_at timestamptz not null default now()
);

create index if not exists daily_study_log_user_date_idx
  on public.daily_study_log (user_id, study_date);

create index if not exists daily_study_log_date_idx
  on public.daily_study_log (study_date);

-- RLS: faqat backend (service_role) yozadi/o'qiydi; anon/authenticated kira olmaydi.

-- Davr bo'yicha reyting: p_since (kiritilgan sanadan) beri to'plangan soniyalar.
-- Top foydalanuvchilar seconds bo'yicha kamayish tartibida.
create or replace function public.ranking_by_period(p_since date, p_limit integer default 50)
returns table (
  user_id uuid,
  full_name text,
  seconds bigint,
  rnk bigint
)
language sql
stable
as $$
  select
    d.user_id,
    coalesce(u.full_name, 'Foydalanuvchi') as full_name,
    sum(d.seconds)::bigint as seconds,
    row_number() over (order by sum(d.seconds) desc) as rnk
  from public.daily_study_log d
  left join public.users u on u.id = d.user_id
  where d.study_date >= p_since
  group by d.user_id, u.full_name
  having sum(d.seconds) > 0
  order by seconds desc
  limit p_limit;
$$;

