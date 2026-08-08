alter table if exists public.courses
  add column if not exists description_uz text not null default '';
