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

do $$
begin
  alter publication supabase_realtime add table public.app_comments;
exception when duplicate_object then
  null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.app_comment_likes;
exception when duplicate_object then
  null;
end;
$$;
