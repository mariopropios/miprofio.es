-- Plataforma del token FCM para enviar el payload correcto (p. ej. iOS PWA).

alter table public.profiles
  add column if not exists fcm_platform text;
