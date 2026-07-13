-- Asegurar que marcar mensajes como leídos funciona con RLS (WITH CHECK explícito).
drop policy if exists "messages_update_read" on public.messages;
create policy "messages_update_read" on public.messages for update
  using (
    conversation_id in (
      select id from public.conversations
      where user_id = auth.uid()
        or professional_id in (
          select id from public.professionals where owner_id = auth.uid()
        )
    )
  )
  with check (
    conversation_id in (
      select id from public.conversations
      where user_id = auth.uid()
        or professional_id in (
          select id from public.professionals where owner_id = auth.uid()
        )
    )
  );
