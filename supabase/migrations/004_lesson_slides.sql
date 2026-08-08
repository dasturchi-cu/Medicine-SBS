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

do $$
begin
  alter publication supabase_realtime add table public.lesson_slides;
exception when duplicate_object then
  null;
end;
$$;
