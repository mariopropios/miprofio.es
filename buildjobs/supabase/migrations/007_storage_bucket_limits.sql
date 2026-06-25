-- Ampliar límites del bucket profile-photos (formatos libres + 20 MB)
update storage.buckets
set
  file_size_limit = 20971520,
  allowed_mime_types = null
where id = 'profile-photos';
