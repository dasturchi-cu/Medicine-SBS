-- Bir xil trigger funksiyasi ikki xil jadval uchun ishlatilgan:
-- app_comment_likes qatorida parent_id yo'q, app_comments da esa comment_id yo'q.
-- NOTO'G'RI ustunlarga (NEW.parent_id / NEW.comment_id) murojaat qilish INSERT/DELETE ni buzgan.

create or replace function public.app_comments_sync_counters()
returns trigger
language plpgsql
as $$
declare
  target_id uuid;
  next_likes int;
  next_replies int;
begin
  if tg_table_name = 'app_comment_likes' then
    target_id := coalesce(new.comment_id, old.comment_id);
    if target_id is not null then
      select count(*)::int into next_likes
      from public.app_comment_likes where comment_id = target_id;

      update public.app_comments set likes_count = coalesce(next_likes, 0) where id = target_id;
    end if;
    return coalesce(new, old);
  end if;

  if tg_table_name = 'app_comments' then
    target_id := coalesce(new.parent_id, old.parent_id);
    if target_id is not null then
      select count(*)::int into next_replies
      from public.app_comments where parent_id = target_id;

      update public.app_comments set replies_count = coalesce(next_replies, 0) where id = target_id;
    end if;
    return coalesce(new, old);
  end if;

  return coalesce(new, old);
end;
$$;
