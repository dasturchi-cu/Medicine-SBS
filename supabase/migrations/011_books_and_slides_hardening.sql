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

alter table public.book_categories enable row level security;
alter table public.slide_progress enable row level security;

drop policy if exists book_categories_public_read on public.book_categories;
create policy book_categories_public_read on public.book_categories
for select using (true);

drop policy if exists book_categories_service_write on public.book_categories;
create policy book_categories_service_write on public.book_categories
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists slide_progress_self_rw on public.slide_progress;
create policy slide_progress_self_rw on public.slide_progress
for all using (auth.uid() = user_id or auth.role() = 'service_role')
with check (auth.uid() = user_id or auth.role() = 'service_role');

do $$
begin
  alter publication supabase_realtime add table public.book_categories;
exception when duplicate_object then
  null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.slide_progress;
exception when duplicate_object then
  null;
end;
$$;
