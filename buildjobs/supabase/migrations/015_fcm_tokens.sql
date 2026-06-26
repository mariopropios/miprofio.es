-- ── FCM tokens para notificaciones push ─────────────────────────────────────
-- Añade la columna fcm_token a la tabla profiles para guardar el token
-- de Firebase Cloud Messaging de cada usuario.

alter table public.profiles
  add column if not exists fcm_token text;

-- Índice para búsquedas rápidas por token (útil para debug)
create index if not exists profiles_fcm_token_idx
  on public.profiles (fcm_token)
  where fcm_token is not null;
