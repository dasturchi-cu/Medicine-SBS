alter table if exists public.app_comments
  add column if not exists parent_id uuid references public.app_comments(id) on delete cascade;

alter table if exists public.app_comments
  add column if not exists replies_count int not null default 0;

create index if not exists app_comments_parent_idx
  on public.app_comments(parent_id, created_at asc);
