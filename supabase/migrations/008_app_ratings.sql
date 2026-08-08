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
