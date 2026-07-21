-- Incluir message_id en el payload de notificación para deduplicar push
-- (cliente + trigger ya no deben doble-disparar; esto es red de seguridad).

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
    'message_id', new.id,
    'conversation_id', new.conversation_id,
    'sender_id', new.sender_id,
    'sender_name', coalesce(v_sender_name, 'Alguien'),
    'body', new.body
  ));

  return new;
end;
$$;
