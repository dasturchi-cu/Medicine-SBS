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

alter table public.users enable row level security;
alter table public.user_devices enable row level security;
alter table public.user_entitlements enable row level security;
alter table public.video_progress enable row level security;
alter table public.app_comments enable row level security;
alter table public.app_comment_likes enable row level security;
alter table public.app_ratings enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_deliveries enable row level security;
alter table public.notification_click_events enable row level security;
alter table public.lesson_assets enable row level security;
alter table public.book_items enable row level security;
alter table public.book_progress enable row level security;
alter table public.auth_sessions enable row level security;
alter table public.audit_logs enable row level security;

drop policy if exists users_self_select on public.users;
create policy users_self_select on public.users
for select using (auth.uid() = id);

drop policy if exists users_service_all on public.users;
create policy users_service_all on public.users
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists user_devices_self_rw on public.user_devices;
create policy user_devices_self_rw on public.user_devices
for all using (auth.uid() = user_id or auth.role() = 'service_role')
with check (auth.uid() = user_id or auth.role() = 'service_role');

drop policy if exists entitlements_self_read on public.user_entitlements;
create policy entitlements_self_read on public.user_entitlements
for select using (auth.uid() = user_id or auth.role() = 'service_role');

drop policy if exists entitlements_service_write on public.user_entitlements;
create policy entitlements_service_write on public.user_entitlements
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists video_progress_self_rw on public.video_progress;
create policy video_progress_self_rw on public.video_progress
for all using (auth.uid() = user_id or auth.role() = 'service_role')
with check (auth.uid() = user_id or auth.role() = 'service_role');

drop policy if exists app_comments_public_read on public.app_comments;
create policy app_comments_public_read on public.app_comments
for select using (true);

drop policy if exists app_comments_owner_write on public.app_comments;
create policy app_comments_owner_write on public.app_comments
for all using (auth.uid()::text = user_id or auth.role() = 'service_role')
with check (auth.uid()::text = user_id or auth.role() = 'service_role');

drop policy if exists app_comment_likes_owner_rw on public.app_comment_likes;
create policy app_comment_likes_owner_rw on public.app_comment_likes
for all using (auth.uid()::text = user_id or auth.role() = 'service_role')
with check (auth.uid()::text = user_id or auth.role() = 'service_role');

drop policy if exists app_ratings_public_read on public.app_ratings;
create policy app_ratings_public_read on public.app_ratings
for select using (true);

drop policy if exists app_ratings_owner_write on public.app_ratings;
create policy app_ratings_owner_write on public.app_ratings
for all using (auth.uid()::text = user_id or auth.role() = 'service_role')
with check (auth.uid()::text = user_id or auth.role() = 'service_role');

drop policy if exists notifications_public_read on public.notifications;
create policy notifications_public_read on public.notifications
for select using (true);

drop policy if exists notifications_service_write on public.notifications;
create policy notifications_service_write on public.notifications
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists deliveries_self_read on public.notification_deliveries;
create policy deliveries_self_read on public.notification_deliveries
for select using (auth.uid() = user_id or auth.role() = 'service_role');

drop policy if exists deliveries_self_update on public.notification_deliveries;
create policy deliveries_self_update on public.notification_deliveries
for update using (auth.uid() = user_id or auth.role() = 'service_role')
with check (auth.uid() = user_id or auth.role() = 'service_role');

drop policy if exists deliveries_service_insert on public.notification_deliveries;
create policy deliveries_service_insert on public.notification_deliveries
for insert with check (auth.role() = 'service_role');

drop policy if exists notification_clicks_self_rw on public.notification_click_events;
create policy notification_clicks_self_rw on public.notification_click_events
for all using (auth.uid() = user_id or auth.role() = 'service_role')
with check (auth.uid() = user_id or auth.role() = 'service_role');

drop policy if exists lesson_assets_public_read on public.lesson_assets;
create policy lesson_assets_public_read on public.lesson_assets
for select using (is_active = true or auth.role() = 'service_role');

drop policy if exists lesson_assets_service_write on public.lesson_assets;
create policy lesson_assets_service_write on public.lesson_assets
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists book_items_public_read on public.book_items;
create policy book_items_public_read on public.book_items
for select using (is_active = true or auth.role() = 'service_role');

drop policy if exists book_items_service_write on public.book_items;
create policy book_items_service_write on public.book_items
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists book_progress_self_rw on public.book_progress;
create policy book_progress_self_rw on public.book_progress
for all using (auth.uid() = user_id or auth.role() = 'service_role')
with check (auth.uid() = user_id or auth.role() = 'service_role');

drop policy if exists auth_sessions_self_read on public.auth_sessions;
create policy auth_sessions_self_read on public.auth_sessions
for select using (auth.uid() = user_id or auth.role() = 'service_role');

drop policy if exists auth_sessions_service_write on public.auth_sessions;
create policy auth_sessions_service_write on public.auth_sessions
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists audit_logs_service_all on public.audit_logs;
create policy audit_logs_service_all on public.audit_logs
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

do $$
begin
  alter publication supabase_realtime add table public.auth_sessions;
exception when duplicate_object then
  null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.book_items;
exception when duplicate_object then
  null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.book_progress;
exception when duplicate_object then
  null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.lesson_assets;
exception when duplicate_object then
  null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.notification_click_events;
exception when duplicate_object then
  null;
end;
$$;
