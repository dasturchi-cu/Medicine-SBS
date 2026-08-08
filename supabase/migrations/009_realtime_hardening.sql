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

do $$
begin
  alter publication supabase_realtime add table public.courses;
exception when duplicate_object then
  null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.lessons;
exception when duplicate_object then
  null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.user_entitlements;
exception when duplicate_object then
  null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.video_progress;
exception when duplicate_object then
  null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.app_ratings;
exception when duplicate_object then
  null;
end;
$$;
