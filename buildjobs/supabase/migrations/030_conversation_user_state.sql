-- Estado por usuario de cada conversación (archivar / ocultar para mí).
-- No borra el hilo del otro interlocutor.

create table if not exists public.conversation_user_state (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  archived_at     timestamptz,
  hidden_at       timestamptz,
  updated_at      timestamptz not null default now(),
  primary key (conversation_id, user_id),
  constraint conversation_user_state_one_flag check (
    archived_at is null or hidden_at is null
  )
);

create index if not exists conversation_user_state_user_idx
  on public.conversation_user_state (user_id);

alter table public.conversation_user_state enable row level security;

drop policy if exists conversation_user_state_select on public.conversation_user_state;
create policy conversation_user_state_select
  on public.conversation_user_state
  for select
  using (auth.uid() = user_id);

drop policy if exists conversation_user_state_insert on public.conversation_user_state;
create policy conversation_user_state_insert
  on public.conversation_user_state
  for insert
  with check (auth.uid() = user_id);

drop policy if exists conversation_user_state_update on public.conversation_user_state;
create policy conversation_user_state_update
  on public.conversation_user_state
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists conversation_user_state_delete on public.conversation_user_state;
create policy conversation_user_state_delete
  on public.conversation_user_state
  for delete
  using (auth.uid() = user_id);

-- Al llegar un mensaje nuevo: reactivar el chat para el destinatario
-- (desarchivar + desocultar), estilo WhatsApp.
create or replace function public.clear_recipient_conversation_state()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client_id uuid;
  v_pro_owner uuid;
  v_recipient uuid;
begin
  select c.user_id, p.owner_id
    into v_client_id, v_pro_owner
  from public.conversations c
  join public.professionals p on p.id = c.professional_id
  where c.id = new.conversation_id;

  if v_client_id is null then
    return new;
  end if;

  if new.sender_id = v_client_id then
    v_recipient := v_pro_owner;
  elsif new.sender_id = v_pro_owner then
    v_recipient := v_client_id;
  else
    return new;
  end if;

  if v_recipient is null or v_recipient = new.sender_id then
    return new;
  end if;

  update public.conversation_user_state
  set archived_at = null,
      hidden_at = null,
      updated_at = now()
  where conversation_id = new.conversation_id
    and user_id = v_recipient
    and (archived_at is not null or hidden_at is not null);

  return new;
end;
$$;

drop trigger if exists trg_clear_recipient_conversation_state on public.messages;
create trigger trg_clear_recipient_conversation_state
  after insert on public.messages
  for each row
  execute function public.clear_recipient_conversation_state();

-- Upsert helpers vía RPC (evita race conditions en el cliente).
create or replace function public.set_conversation_archived(p_conversation_id uuid, p_archived boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  -- Verificar participación
  if not exists (
    select 1
    from public.conversations c
    left join public.professionals p on p.id = c.professional_id
    where c.id = p_conversation_id
      and (c.user_id = auth.uid() or p.owner_id = auth.uid())
  ) then
    raise exception 'not a participant';
  end if;

  insert into public.conversation_user_state as s
    (conversation_id, user_id, archived_at, hidden_at, updated_at)
  values (
    p_conversation_id,
    auth.uid(),
    case when p_archived then now() else null end,
    null,
    now()
  )
  on conflict (conversation_id, user_id) do update
  set archived_at = case when p_archived then now() else null end,
      hidden_at = null,
      updated_at = now();
end;
$$;

create or replace function public.set_conversation_hidden(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1
    from public.conversations c
    left join public.professionals p on p.id = c.professional_id
    where c.id = p_conversation_id
      and (c.user_id = auth.uid() or p.owner_id = auth.uid())
  ) then
    raise exception 'not a participant';
  end if;

  insert into public.conversation_user_state as s
    (conversation_id, user_id, archived_at, hidden_at, updated_at)
  values (p_conversation_id, auth.uid(), null, now(), now())
  on conflict (conversation_id, user_id) do update
  set hidden_at = now(),
      archived_at = null,
      updated_at = now();
end;
$$;

revoke all on function public.set_conversation_archived(uuid, boolean) from public;
revoke all on function public.set_conversation_hidden(uuid) from public;
grant execute on function public.set_conversation_archived(uuid, boolean) to authenticated;
grant execute on function public.set_conversation_hidden(uuid) to authenticated;

-- Realtime para que lista/archivados se actualicen al cambiar estado.
do $$
begin
  alter publication supabase_realtime add table public.conversation_user_state;
exception
  when duplicate_object then null;
end $$;
