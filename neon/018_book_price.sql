-- Kitoblar uchun narx (0 bo'lsa bepul/ochiq, >0 bo'lsa qulf).
alter table public.book_items
  add column if not exists price_uzs numeric(12, 2) not null default 0;
