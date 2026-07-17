-- Profesionales borrados / cuentas eliminadas:
-- 1) Soft-delete (deleted_at) + archivo interno (professionals_archive).
-- 2) La web pública solo ve fichas con dueño y no borradas.
-- 3) Huérfanos actuales (owner_id null) se archivan y ocultan.

-- ── Columnas soft-delete ─────────────────────────────────────────────────────
alter table public.professionals
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_reason text;

create index if not exists professionals_active_idx
  on public.professionals (id)
  where deleted_at is null and owner_id is not null;

-- ── Archivo (no expuesto por API pública) ────────────────────────────────────
create table if not exists public.professionals_archive (
  id               uuid primary key default gen_random_uuid(),
  professional_id  uuid not null,
  former_owner_id  uuid,
  name             text,
  email            text,
  phone            text,
  city             text,
  snapshot         jsonb not null,
  reason           text not null default 'deleted',
  archived_at      timestamptz not null default now()
);

create index if not exists professionals_archive_professional_idx
  on public.professionals_archive (professional_id);

create index if not exists professionals_archive_owner_idx
  on public.professionals_archive (former_owner_id);

alter table public.professionals_archive enable row level security;

-- Sin políticas SELECT/INSERT para anon/authenticated → nadie del cliente lee el archivo.
-- Solo service_role / funciones security definer escriben.

-- ── Helper: copiar a archivo + marcar deleted_at ──────────────────────────────
create or replace function public.archive_professional(
  p_professional_id uuid,
  p_reason text default 'deleted'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.professionals%rowtype;
begin
  select * into v_row
  from public.professionals
  where id = p_professional_id;

  if not found then
    return;
  end if;

  -- Evitar duplicar archivo si ya estaba borrado (salvo re-archivo explícito).
  if v_row.deleted_at is not null and p_reason = 'already_deleted' then
    return;
  end if;

  insert into public.professionals_archive (
    professional_id,
    former_owner_id,
    name,
    email,
    phone,
    city,
    snapshot,
    reason
  ) values (
    v_row.id,
    v_row.owner_id,
    v_row.name,
    v_row.email,
    v_row.phone,
    v_row.city,
    to_jsonb(v_row),
    coalesce(nullif(trim(p_reason), ''), 'deleted')
  );

  update public.professionals
  set deleted_at = coalesce(deleted_at, now()),
      deleted_reason = coalesce(nullif(trim(p_reason), ''), deleted_reason, 'deleted'),
      updated_at = now()
  where id = p_professional_id;
end;
$$;

revoke all on function public.archive_professional(uuid, text) from public;
revoke all on function public.archive_professional(uuid, text) from authenticated;
-- Solo service_role y otras funciones security definer (triggers / soft_delete_my_professional).
grant execute on function public.archive_professional(uuid, text) to service_role;

-- ── Al quedar huérfano (borra cuenta → owner_id SET NULL) ────────────────────
create or replace function public.on_professional_owner_cleared()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.owner_id is not null and new.owner_id is null then
    -- Marcar borrado en el mismo UPDATE; archivo en after-trigger vía llamada.
    new.deleted_at := coalesce(new.deleted_at, now());
    new.deleted_reason := coalesce(new.deleted_reason, 'owner_deleted');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_professional_owner_cleared on public.professionals;
create trigger trg_professional_owner_cleared
  before update of owner_id on public.professionals
  for each row
  when (old.owner_id is distinct from new.owner_id)
  execute function public.on_professional_owner_cleared();

create or replace function public.after_professional_owner_cleared()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.owner_id is not null and new.owner_id is null then
    -- Insertar archivo sin volver a tocar deleted_at (ya marcado).
    insert into public.professionals_archive (
      professional_id,
      former_owner_id,
      name,
      email,
      phone,
      city,
      snapshot,
      reason
    ) values (
      new.id,
      old.owner_id,
      new.name,
      new.email,
      new.phone,
      new.city,
      to_jsonb(new),
      coalesce(new.deleted_reason, 'owner_deleted')
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_after_professional_owner_cleared on public.professionals;
create trigger trg_after_professional_owner_cleared
  after update of owner_id on public.professionals
  for each row
  when (old.owner_id is not null and new.owner_id is null)
  execute function public.after_professional_owner_cleared();

-- ── RPC: el usuario archiva/oculta su propia ficha (preparado para “Eliminar cuenta”) ─
create or replace function public.soft_delete_my_professional(
  p_reason text default 'user_requested'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select id into v_id
  from public.professionals
  where owner_id = auth.uid()
    and deleted_at is null
  limit 1;

  if v_id is null then
    return;
  end if;

  perform public.archive_professional(v_id, coalesce(nullif(trim(p_reason), ''), 'user_requested'));
end;
$$;

revoke all on function public.soft_delete_my_professional(text) from public;
grant execute on function public.soft_delete_my_professional(text) to authenticated;

-- ── RLS pública: solo fichas activas con dueño ───────────────────────────────
drop policy if exists "professionals_select_public" on public.professionals;
create policy "professionals_select_public"
  on public.professionals
  for select
  using (
    owner_id is not null
    and deleted_at is null
  );

-- El dueño siempre puede leer su ficha (edición / perfil propio).
drop policy if exists "professionals_select_owner" on public.professionals;
create policy "professionals_select_owner"
  on public.professionals
  for select
  using (auth.uid() = owner_id);

-- ── Backfill: archivar y ocultar huérfanos actuales ───────────────────────────
do $$
declare
  r record;
begin
  for r in
    select id
    from public.professionals
    where owner_id is null
      and deleted_at is null
  loop
    perform public.archive_professional(r.id, 'orphan_owner_null');
  end loop;
end $$;

-- Por si algún huérfano ya tenía deleted_at null tras archive fallido parcial:
update public.professionals
set deleted_at = now(),
    deleted_reason = coalesce(deleted_reason, 'orphan_owner_null'),
    updated_at = now()
where owner_id is null
  and deleted_at is null;

comment on table public.professionals_archive is
  'Copia interna de fichas profesionales al borrar/ocultar. No expuesto vía RLS al cliente.';
comment on column public.professionals.deleted_at is
  'Soft-delete: si no es null, la ficha no es pública.';
