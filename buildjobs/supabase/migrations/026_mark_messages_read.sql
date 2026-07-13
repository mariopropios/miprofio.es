-- Marcar mensajes como leídos vía RPC (evita fallos de RLS en updates masivos).

create or replace function public.mark_conversation_messages_read(
  p_conversation_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_updated integer;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1
    from public.conversations c
    where c.id = p_conversation_id
      and (
        c.user_id = v_uid
        or c.professional_id in (
          select p.id
          from public.professionals p
          where p.owner_id = v_uid
        )
      )
  ) then
    raise exception 'forbidden';
  end if;

  update public.messages m
  set read_at = now()
  where m.conversation_id = p_conversation_id
    and m.sender_id <> v_uid
    and m.read_at is null;

  get diagnostics v_updated = row_count;
  return v_updated;
end;
$$;

revoke all on function public.mark_conversation_messages_read(uuid) from public;
grant execute on function public.mark_conversation_messages_read(uuid) to authenticated;
