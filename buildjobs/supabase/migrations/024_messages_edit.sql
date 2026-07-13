-- Edición de mensajes de texto propios durante 1 hora (estilo WhatsApp).

alter table public.messages
  add column if not exists edited_at timestamptz;

-- El remitente puede editar su mensaje de texto durante la primera hora.
drop policy if exists "messages_update_own" on public.messages;
create policy "messages_update_own" on public.messages for update
  using (
    sender_id = auth.uid()
    and created_at > (now() - interval '1 hour')
    and body not like '[image]%'
    and body not like '[audio]%'
  )
  with check (
    sender_id = auth.uid()
    and body not like '[image]%'
    and body not like '[audio]%'
    and char_length(body) > 0
  );

-- Actualizar vista previa de conversación si se edita el último mensaje.
create or replace function public.handle_message_updated()
returns trigger language plpgsql security definer as $$
begin
  if new.body is distinct from old.body then
    update public.conversations c
    set
      last_message = new.body,
      updated_at = now()
    where c.id = new.conversation_id
      and (
        select m.id
        from public.messages m
        where m.conversation_id = new.conversation_id
        order by m.created_at desc
        limit 1
      ) = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_message_updated on public.messages;
create trigger on_message_updated
  after update on public.messages
  for each row execute function public.handle_message_updated();
