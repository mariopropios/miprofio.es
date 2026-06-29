-- Bucket para imágenes enviadas en el chat
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values (
    'chat-images',
    'chat-images',
    true,
    10485760,  -- 10 MB
    array['image/jpeg','image/png','image/webp','image/gif']
  )
  on conflict (id) do nothing;

-- Cualquier usuario autenticado puede subir imágenes
create policy if not exists "chat_images_insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'chat-images');

-- Lectura pública (bucket ya es public, pero la policy es necesaria)
create policy if not exists "chat_images_select"
  on storage.objects for select
  to public
  using (bucket_id = 'chat-images');
