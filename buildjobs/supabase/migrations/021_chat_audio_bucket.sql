-- Bucket para audios enviados en el chat
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values (
    'chat-audio',
    'chat-audio',
    true,
    10485760,  -- 10 MB
    array['audio/wav','audio/mp4','audio/mpeg','audio/ogg','audio/webm']
  )
  on conflict (id) do nothing;

create policy if not exists "chat_audio_insert"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'chat-audio');

create policy if not exists "chat_audio_select"
  on storage.objects for select
  to public
  using (bucket_id = 'chat-audio');
