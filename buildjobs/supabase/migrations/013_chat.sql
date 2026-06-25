-- ── Chat: conversaciones y mensajes ──────────────────────────────────────────

create table if not exists public.conversations (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id)      on delete cascade,
  professional_id uuid not null references public.professionals(id) on delete cascade,
  last_message    text,
  last_message_at timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint conversations_unique unique (user_id, professional_id)
);

create table if not exists public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id       uuid not null references public.profiles(id)      on delete cascade,
  body            text not null check (char_length(body) > 0),
  read_at         timestamptz,
  created_at      timestamptz not null default now()
);

-- Índices de rendimiento
create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at);

create index if not exists conversations_user_idx
  on public.conversations (user_id, updated_at desc);

create index if not exists conversations_professional_idx
  on public.conversations (professional_id, updated_at desc);

-- Trigger: actualizar updated_at + last_message en conversations al insertar mensaje
create or replace function public.handle_new_message()
returns trigger language plpgsql security definer as $$
begin
  update public.conversations
  set
    last_message    = new.body,
    last_message_at = new.created_at,
    updated_at      = new.created_at
  where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists on_new_message on public.messages;
create trigger on_new_message
  after insert on public.messages
  for each row execute function public.handle_new_message();

-- ── RLS ───────────────────────────────────────────────────────────────────────

alter table public.conversations enable row level security;
alter table public.messages      enable row level security;

-- El usuario ve sus propias conversaciones.
-- El profesional ve las conversaciones sobre su perfil.
drop policy if exists "conversations_select" on public.conversations;
create policy "conversations_select" on public.conversations for select
  using (
    auth.uid() = user_id
    or professional_id in (
      select id from public.professionals where owner_id = auth.uid()
    )
  );

drop policy if exists "conversations_insert" on public.conversations;
create policy "conversations_insert" on public.conversations for insert
  with check (auth.uid() = user_id);

-- Mensajes: cualquiera de los dos participantes puede leer/escribir
drop policy if exists "messages_select" on public.messages;
create policy "messages_select" on public.messages for select
  using (
    conversation_id in (
      select id from public.conversations
      where user_id = auth.uid()
        or professional_id in (
          select id from public.professionals where owner_id = auth.uid()
        )
    )
  );

drop policy if exists "messages_insert" on public.messages;
create policy "messages_insert" on public.messages for insert
  with check (
    auth.uid() = sender_id
    and conversation_id in (
      select id from public.conversations
      where user_id = auth.uid()
        or professional_id in (
          select id from public.professionals where owner_id = auth.uid()
        )
    )
  );

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
  );
