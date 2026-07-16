-- Avisos por email: mensajes + reseñas + respuestas (Resend vía Edge Function).
-- Preferencia: profiles.message_email_notifications

comment on column public.profiles.message_email_notifications is
  'Si true, envía email en mensajes nuevos, reseñas nuevas y respuestas a reseñas.';

-- Throttle genérico por tipo de evento (evita spam y dobles envíos cliente+trigger).
create table if not exists public.notification_email_throttle (
  event_key    text primary key,
  last_sent_at timestamptz not null default now()
);

alter table public.notification_email_throttle enable row level security;

-- Migrar throttle antiguo de mensajes si existe.
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'message_email_throttle'
  ) then
    insert into public.notification_email_throttle (event_key, last_sent_at)
    select
      'message:' || conversation_id::text || ':' || recipient_id::text,
      last_sent_at
    from public.message_email_throttle
    on conflict (event_key) do nothing;
  end if;
end $$;

-- Reserva un slot de envío. true = puedes enviar; false = throttled.
create or replace function public.try_claim_notification_throttle(
  p_event_key text,
  p_cooldown_minutes integer default 10
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_claimed boolean;
begin
  if p_event_key is null or length(trim(p_event_key)) = 0 then
    return false;
  end if;

  insert into public.notification_email_throttle as t (event_key, last_sent_at)
  values (p_event_key, now())
  on conflict (event_key) do update
    set last_sent_at = now()
    where t.last_sent_at < now() - make_interval(mins => greatest(p_cooldown_minutes, 0))
  returning true into v_claimed;

  return coalesce(v_claimed, false);
end;
$$;

revoke all on function public.try_claim_notification_throttle(text, integer) from public;
grant execute on function public.try_claim_notification_throttle(text, integer) to service_role;
grant execute on function public.try_claim_notification_throttle(text, integer) to authenticated;

-- Despacha notificación a la Edge Function si hay secretos en Vault:
--   app_notification_url  = https://<ref>.supabase.co/functions/v1/send-push-notification
--   app_notification_auth = Bearer <anon_o_service_role_jwt>
create or replace function public.dispatch_app_notification(payload jsonb)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_auth text;
  v_request_id bigint;
begin
  select ds.decrypted_secret into v_url
  from vault.decrypted_secrets ds
  where ds.name = 'app_notification_url'
  limit 1;

  select ds.decrypted_secret into v_auth
  from vault.decrypted_secrets ds
  where ds.name = 'app_notification_auth'
  limit 1;

  if v_url is null or length(trim(v_url)) = 0 then
    return null;
  end if;

  select net.http_post(
    url := trim(v_url),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', coalesce(nullif(trim(v_auth), ''), 'Bearer')
    ),
    body := payload,
    timeout_milliseconds := 5000
  ) into v_request_id;

  return v_request_id;
exception
  when others then
    raise warning 'dispatch_app_notification failed: %', sqlerrm;
    return null;
end;
$$;

revoke all on function public.dispatch_app_notification(jsonb) from public;
grant execute on function public.dispatch_app_notification(jsonb) to service_role;

-- ── Trigger: nuevo mensaje ────────────────────────────────────────────────────
create or replace function public.notify_on_new_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender_name text;
begin
  select coalesce(nullif(trim(p.full_name), ''), 'Alguien')
    into v_sender_name
  from public.profiles p
  where p.id = new.sender_id;

  perform public.dispatch_app_notification(jsonb_build_object(
    'type', 'message',
    'conversation_id', new.conversation_id,
    'sender_id', new.sender_id,
    'sender_name', coalesce(v_sender_name, 'Alguien'),
    'body', new.body
  ));

  return new;
end;
$$;

drop trigger if exists trg_notify_on_new_message on public.messages;
create trigger trg_notify_on_new_message
  after insert on public.messages
  for each row
  execute function public.notify_on_new_message();

-- ── Trigger: nueva reseña ─────────────────────────────────────────────────────
create or replace function public.notify_on_new_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reviewer_name text;
  v_prof_name text;
begin
  select coalesce(nullif(trim(p.full_name), ''), 'Un cliente')
    into v_reviewer_name
  from public.profiles p
  where p.id = new.user_id;

  select coalesce(nullif(trim(pr.name), ''), 'tu perfil')
    into v_prof_name
  from public.professionals pr
  where pr.id = new.professional_id;

  perform public.dispatch_app_notification(jsonb_build_object(
    'type', 'review',
    'review_id', new.id,
    'professional_id', new.professional_id,
    'reviewer_id', new.user_id,
    'reviewer_name', coalesce(v_reviewer_name, 'Un cliente'),
    'professional_name', coalesce(v_prof_name, 'tu perfil'),
    'rating', new.rating,
    'title', coalesce(new.title, ''),
    'body', coalesce(new.body, '')
  ));

  return new;
end;
$$;

drop trigger if exists trg_notify_on_new_review on public.reviews;
create trigger trg_notify_on_new_review
  after insert on public.reviews
  for each row
  execute function public.notify_on_new_review();

-- ── Trigger: respuesta del profesional a reseña ───────────────────────────────
create or replace function public.notify_on_review_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prof_name text;
begin
  if new.owner_reply is null or length(trim(new.owner_reply)) = 0 then
    return new;
  end if;

  if old.owner_reply is not distinct from new.owner_reply then
    return new;
  end if;

  select coalesce(nullif(trim(pr.name), ''), 'Un profesional')
    into v_prof_name
  from public.professionals pr
  where pr.id = new.professional_id;

  perform public.dispatch_app_notification(jsonb_build_object(
    'type', 'review_reply',
    'review_id', new.id,
    'professional_id', new.professional_id,
    'reviewer_id', new.user_id,
    'professional_name', coalesce(v_prof_name, 'Un profesional'),
    'reply', new.owner_reply,
    'rating', new.rating,
    'title', coalesce(new.title, '')
  ));

  return new;
end;
$$;

drop trigger if exists trg_notify_on_review_reply on public.reviews;
create trigger trg_notify_on_review_reply
  after update of owner_reply, owner_reply_at on public.reviews
  for each row
  execute function public.notify_on_review_reply();
