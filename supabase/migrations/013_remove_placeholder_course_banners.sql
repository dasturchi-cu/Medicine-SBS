-- Sinov / chalkash placeholder reklamalar (Kanal yangiliklari kartochkalari)
-- Qo'lda qo'shilgan "test" kabi yozuvlarni olib tashlash — kerak bo'lsa shartni tahrirlang.
delete from public.course_banners
where lower(btrim(title)) in ('test', 'tes');
