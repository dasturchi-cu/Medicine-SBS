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
