-- Galería de fotos del profesional + bucket de storage
-- Ejecutar en: Supabase Dashboard → SQL Editor

alter table public.professionals
  add column if not exists gallery_photos jsonb not null default '[]'::jsonb;

comment on column public.professionals.gallery_photos is
  'URLs públicas de fotos de trabajos (array JSON)';

-- Bucket para fotos de perfil y galería
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-photos',
  'profile-photos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Lectura pública
drop policy if exists "profile_photos_public_read" on storage.objects;
create policy "profile_photos_public_read"
  on storage.objects for select
  using (bucket_id = 'profile-photos');

-- Subida por usuarios autenticados (solo en su carpeta userId/)
drop policy if exists "profile_photos_auth_upload" on storage.objects;
create policy "profile_photos_auth_upload"
  on storage.objects for insert
  with check (
    bucket_id = 'profile-photos'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "profile_photos_auth_update" on storage.objects;
create policy "profile_photos_auth_update"
  on storage.objects for update
  using (
    bucket_id = 'profile-photos'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "profile_photos_auth_delete" on storage.objects;
create policy "profile_photos_auth_delete"
  on storage.objects for delete
  using (
    bucket_id = 'profile-photos'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );
