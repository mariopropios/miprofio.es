-- ── Profesionales guardados (favoritos) ───────────────────────────────────────

create table if not exists public.saved_professionals (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles (id) on delete cascade,
  professional_id uuid not null references public.professionals (id) on delete cascade,
  created_at      timestamptz not null default now(),
  constraint saved_professionals_unique unique (user_id, professional_id)
);

create index if not exists saved_professionals_user_idx
  on public.saved_professionals (user_id, created_at desc);

create index if not exists saved_professionals_professional_idx
  on public.saved_professionals (professional_id);

alter table public.saved_professionals enable row level security;

drop policy if exists "saved_select_own" on public.saved_professionals;
create policy "saved_select_own"
  on public.saved_professionals for select
  using (auth.uid() = user_id);

drop policy if exists "saved_insert_own" on public.saved_professionals;
create policy "saved_insert_own"
  on public.saved_professionals for insert
  with check (auth.uid() = user_id);

drop policy if exists "saved_delete_own" on public.saved_professionals;
create policy "saved_delete_own"
  on public.saved_professionals for delete
  using (auth.uid() = user_id);
