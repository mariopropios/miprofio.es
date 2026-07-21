-- Borradores de registro pendientes de confirmar email.
-- Se guardan vía Edge Function (service role) porque aún no hay sesión.
-- Tras confirmar, el usuario autenticado puede leer/borrar el suyo.

create table if not exists public.signup_drafts (
  user_id uuid primary key references auth.users (id) on delete cascade,
  kind text not null check (kind in ('professional', 'client')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.signup_drafts is
  'Borrador de registro (profesional/cliente) hasta confirmar email. Cross-browser.';

create index if not exists signup_drafts_kind_idx
  on public.signup_drafts (kind);

alter table public.signup_drafts enable row level security;

drop policy if exists "signup_drafts_select_own" on public.signup_drafts;
create policy "signup_drafts_select_own"
  on public.signup_drafts
  for select
  using (auth.uid() = user_id);

drop policy if exists "signup_drafts_delete_own" on public.signup_drafts;
create policy "signup_drafts_delete_own"
  on public.signup_drafts
  for delete
  using (auth.uid() = user_id);

-- Sin INSERT/UPDATE para usuarios: solo service_role (Edge Function).
