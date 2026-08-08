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
do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then
  null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.notification_deliveries;
exception when duplicate_object then
  null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.comments;
exception when duplicate_object then
  null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.ratings;
exception when duplicate_object then
  null;
end;
$$;
