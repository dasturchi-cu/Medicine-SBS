-- Deduped "opened course" impressions (mobile) for views alongside video watch progress.

create table if not exists public.course_catalog_views (
  course_id uuid not null references public.courses(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (course_id, user_id)
);

create index if not exists course_catalog_views_user_idx
  on public.course_catalog_views(user_id, viewed_at desc);
