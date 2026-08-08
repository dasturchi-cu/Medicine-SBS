  -- Slides + Tests + Rank extension

  create table if not exists public.home_slides (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    subtitle text not null default '',
    image_url text not null default '',
    button_text text not null default 'Boshlash',
    course_id uuid references public.courses(id) on delete set null,
    order_no int not null default 1,
    is_active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );

  create unique index if not exists home_slides_order_unique_idx
    on public.home_slides(order_no);

  create table if not exists public.quizzes (
    id uuid primary key default gen_random_uuid(),
    course_id uuid references public.courses(id) on delete set null,
    section_id uuid references public.course_sections(id) on delete set null,
  lesson_id text,
    title text not null,
    description text not null default '',
    estimated_minutes int not null default 10,
    is_active boolean not null default true,
    created_at timestamptz not null default now()
  );

alter table public.quizzes add column if not exists lesson_id text;
  create index if not exists quizzes_lesson_idx on public.quizzes(lesson_id);

  create table if not exists public.quiz_questions (
    id uuid primary key default gen_random_uuid(),
    quiz_id uuid not null references public.quizzes(id) on delete cascade,
    question_text text not null,
    option_a text not null,
    option_b text not null,
    option_c text not null,
    option_d text not null,
    correct_option text not null check (correct_option in ('A', 'B', 'C', 'D')),
    order_no int not null default 1,
    created_at timestamptz not null default now(),
    unique (quiz_id, order_no)
  );

  create table if not exists public.quiz_attempts (
    id uuid primary key default gen_random_uuid(),
    quiz_id uuid not null references public.quizzes(id) on delete cascade,
    user_id uuid not null references public.users(id) on delete cascade,
    score_percent numeric(5, 2) not null default 0,
    correct_count int not null default 0,
    total_questions int not null default 0,
    duration_minutes numeric(8, 2) not null default 0,
    created_at timestamptz not null default now()
  );

  create index if not exists quiz_attempts_user_idx
    on public.quiz_attempts(user_id, created_at desc);

  create table if not exists public.rank_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    event_type text not null,
    points numeric(10, 2) not null default 0,
    duration_minutes numeric(8, 2) not null default 0,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
  );

  alter table public.user_ranks add column if not exists quiz_minutes numeric(10, 2) not null default 0;
  alter table public.user_ranks add column if not exists test_points numeric(10, 2) not null default 0;

  drop trigger if exists trg_home_slides_touch_updated_at on public.home_slides;
  create trigger trg_home_slides_touch_updated_at
  before update on public.home_slides
  for each row execute function public.touch_updated_at();

  do $$
  begin
    alter publication supabase_realtime add table public.home_slides;
  exception when duplicate_object then
    null;
  end;
  $$;
