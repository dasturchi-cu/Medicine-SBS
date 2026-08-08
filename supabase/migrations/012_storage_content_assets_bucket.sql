-- Storage: content-assets bucket va minimal policylar (public o‘qish + anon/authenticated upload).
-- Admin panel brauzerda anon JWT bilan ishlaydi; mobil/public URL lar uchun SELECT ochiq bo‘lishi kerak.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'content-assets',
  'content-assets',
  true,
  52428800,
  null
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = coalesce(storage.buckets.file_size_limit, excluded.file_size_limit);

drop policy if exists "content_assets_public_read" on storage.objects;
drop policy if exists "content_assets_insert_anon_auth" on storage.objects;
drop policy if exists "content_assets_update_anon_auth" on storage.objects;
drop policy if exists "content_assets_delete_anon_auth" on storage.objects;

create policy "content_assets_public_read"
on storage.objects
for select
to public
using (bucket_id = 'content-assets');

create policy "content_assets_insert_anon_auth"
on storage.objects
for insert
to anon, authenticated
with check (bucket_id = 'content-assets');

create policy "content_assets_update_anon_auth"
on storage.objects
for update
to anon, authenticated
using (bucket_id = 'content-assets')
with check (bucket_id = 'content-assets');

create policy "content_assets_delete_anon_auth"
on storage.objects
for delete
to anon, authenticated
using (bucket_id = 'content-assets');
