-- Kunlik/haftalik/oylik/yillik reyting uchun vaqt bo'yicha o'qish logi.
-- Har bir video ko'rish delta'si (qo'shimcha soniyalar) shu jadvalga yoziladi.
-- `user_ranks` faqat umumiy (jami) hisob uchun ishlatiladi; davrlar shu logdan hisoblanadi.

create table if not exists public.daily_study_log (
  id bigserial primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  -- Sana O'zbekiston vaqti (Asia/Tashkent, UTC+5) bo'yicha — kunlik chegara
  -- foydalanuvchi uchun to'g'ri bo'lishi uchun.
  study_date date not null default (now() at time zone 'Asia/Tashkent')::date,
  seconds integer not null,
  created_at timestamptz not null default now()
);

create index if not exists daily_study_log_user_date_idx
  on public.daily_study_log (user_id, study_date);

create index if not exists daily_study_log_date_idx
  on public.daily_study_log (study_date);

-- RLS: faqat backend (service_role) yozadi/o'qiydi; anon/authenticated kira olmaydi.
alter table public.daily_study_log enable row level security;

-- Davr bo'yicha reyting: p_since (kiritilgan sanadan) beri to'plangan soniyalar.
-- Top foydalanuvchilar seconds bo'yicha kamayish tartibida.
create or replace function public.ranking_by_period(p_since date, p_limit integer default 50)
returns table (
  user_id uuid,
  full_name text,
  seconds bigint,
  rnk bigint
)
language sql
stable
as $$
  select
    d.user_id,
    coalesce(u.full_name, 'Foydalanuvchi') as full_name,
    sum(d.seconds)::bigint as seconds,
    row_number() over (order by sum(d.seconds) desc) as rnk
  from public.daily_study_log d
  left join public.users u on u.id = d.user_id
  where d.study_date >= p_since
  group by d.user_id, u.full_name
  having sum(d.seconds) > 0
  order by seconds desc
  limit p_limit;
$$;
