-- Avisos por email cuando llega un mensaje nuevo (alternativa a push en iOS Safari).

alter table public.profiles
  add column if not exists message_email_notifications boolean not null default true;

comment on column public.profiles.message_email_notifications is
  'Si true, envía email al recibir mensajes nuevos (cuando no hay push).';

-- Evita bombardear el buzón: máx. 1 email / conversación / destinatario cada 10 min.
create table if not exists public.message_email_throttle (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  recipient_id    uuid not null references public.profiles (id) on delete cascade,
  last_sent_at    timestamptz not null default now(),
  primary key (conversation_id, recipient_id)
);

alter table public.message_email_throttle enable row level security;
