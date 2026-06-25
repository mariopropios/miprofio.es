-- =============================================================================
-- BuildJobs — Esquema inicial
-- Proyecto: BUILDJOBS
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run
-- =============================================================================

-- Extensiones
create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- 1. USUARIOS (profiles)
-- Extiende auth.users de Supabase Auth
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text not null,
  full_name   text,
  avatar_url  text,
  role        text not null default 'client'
                check (role in ('client', 'professional', 'admin')),
  city        text,
  review_count int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.profiles is 'Perfiles de usuarios registrados en BuildJobs';
comment on column public.profiles.role is 'client = usuario que deja reseñas; professional = dueño de ficha';

-- -----------------------------------------------------------------------------
-- 2. PROFESIONALES (empresas y autónomos del sector construcción)
-- -----------------------------------------------------------------------------
create table if not exists public.professionals (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid references public.profiles (id) on delete set null,
  name            text not null,
  type            text not null default 'company'
                    check (type in ('company', 'individual')),
  category        text not null,
  specialty       text,
  description     text,
  city            text not null,
  province        text,
  address         text,
  postal_code     text,
  phone           text,
  email           text,
  website         text,
  image_url       text,
  license_number  text,
  verified        boolean not null default false,
  rating          numeric(3, 2) not null default 0
                    check (rating >= 0 and rating <= 5),
  review_count    int not null default 0 check (review_count >= 0),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.professionals is 'Profesionales y empresas de construcción listados en BuildJobs';

create index if not exists idx_professionals_category on public.professionals (category);
create index if not exists idx_professionals_city on public.professionals (city);
create index if not exists idx_professionals_rating on public.professionals (rating desc);
create index if not exists idx_professionals_owner on public.professionals (owner_id);

-- -----------------------------------------------------------------------------
-- 3. RESEÑAS
-- -----------------------------------------------------------------------------
create table if not exists public.reviews (
  id              uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professionals (id) on delete cascade,
  user_id         uuid not null references public.profiles (id) on delete cascade,
  rating          int not null check (rating between 1 and 5),
  title           text not null check (char_length(title) >= 3),
  body            text not null check (char_length(body) >= 20),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (professional_id, user_id)
);

comment on table public.reviews is 'Reseñas de usuarios sobre profesionales';

create index if not exists idx_reviews_professional on public.reviews (professional_id);
create index if not exists idx_reviews_user on public.reviews (user_id);
create index if not exists idx_reviews_created_at on public.reviews (created_at desc);

-- -----------------------------------------------------------------------------
-- Row Level Security (RLS)
-- -----------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.professionals enable row level security;
alter table public.reviews enable row level security;

-- Profiles
drop policy if exists "profiles_select_public" on public.profiles;
create policy "profiles_select_public"
  on public.profiles for select using (true);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert with check (auth.uid() = id);

-- Professionals
drop policy if exists "professionals_select_public" on public.professionals;
create policy "professionals_select_public"
  on public.professionals for select using (true);

drop policy if exists "professionals_insert_authenticated" on public.professionals;
create policy "professionals_insert_authenticated"
  on public.professionals for insert
  with check (auth.uid() is not null);

drop policy if exists "professionals_update_owner" on public.professionals;
create policy "professionals_update_owner"
  on public.professionals for update
  using (auth.uid() = owner_id);

drop policy if exists "professionals_delete_owner" on public.professionals;
create policy "professionals_delete_owner"
  on public.professionals for delete
  using (auth.uid() = owner_id);

-- Reviews
drop policy if exists "reviews_select_public" on public.reviews;
create policy "reviews_select_public"
  on public.reviews for select using (true);

drop policy if exists "reviews_insert_own" on public.reviews;
create policy "reviews_insert_own"
  on public.reviews for insert
  with check (auth.uid() = user_id);

drop policy if exists "reviews_update_own" on public.reviews;
create policy "reviews_update_own"
  on public.reviews for update
  using (auth.uid() = user_id);

drop policy if exists "reviews_delete_own" on public.reviews;
create policy "reviews_delete_own"
  on public.reviews for delete
  using (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- Funciones y triggers
-- -----------------------------------------------------------------------------

-- Actualizar updated_at automáticamente
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists professionals_set_updated_at on public.professionals;
create trigger professionals_set_updated_at
  before update on public.professionals
  for each row execute function public.set_updated_at();

drop trigger if exists reviews_set_updated_at on public.reviews;
create trigger reviews_set_updated_at
  before update on public.reviews
  for each row execute function public.set_updated_at();

-- Crear perfil al registrarse un usuario
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'role', 'client')
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Recalcular rating y contador del profesional
create or replace function public.refresh_professional_stats(p_professional_id uuid)
returns void as $$
begin
  update public.professionals
  set
    rating = coalesce((
      select round(avg(r.rating)::numeric, 2)
      from public.reviews r
      where r.professional_id = p_professional_id
    ), 0),
    review_count = (
      select count(*)
      from public.reviews r
      where r.professional_id = p_professional_id
    )
  where id = p_professional_id;
end;
$$ language plpgsql security definer set search_path = public;

create or replace function public.on_review_changed()
returns trigger as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_professional_stats(old.professional_id);
    update public.profiles
    set review_count = greatest(review_count - 1, 0)
    where id = old.user_id;
    return old;
  else
    perform public.refresh_professional_stats(new.professional_id);
    if tg_op = 'INSERT' then
      update public.profiles
      set review_count = review_count + 1
      where id = new.user_id;
    end if;
    return new;
  end if;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_review_changed on public.reviews;
create trigger on_review_changed
  after insert or update or delete on public.reviews
  for each row execute function public.on_review_changed();

-- -----------------------------------------------------------------------------
-- Vista de compatibilidad (opcional, para consultas tipo "companies")
-- -----------------------------------------------------------------------------
create or replace view public.companies as
select
  id,
  name,
  category,
  city,
  description,
  address,
  phone,
  website,
  image_url,
  rating,
  review_count,
  created_at
from public.professionals;

-- -----------------------------------------------------------------------------
-- Datos de ejemplo (opcional — comenta este bloque en producción)
-- -----------------------------------------------------------------------------
insert into public.professionals (id, name, type, category, specialty, city, province, description, phone, verified, rating, review_count)
values
  ('11111111-1111-1111-1111-111111111101', 'Reformas García S.L.', 'company', 'Reformas', 'Reformas integrales', 'Madrid', 'Madrid',
   'Especialistas en reformas de viviendas y locales comerciales con más de 15 años de experiencia.',
   '+34 912 345 678', true, 4.70, 128),
  ('11111111-1111-1111-1111-111111111102', 'ElectroBuild Pro', 'company', 'Electricidad', 'Instalaciones eléctricas', 'Barcelona', 'Barcelona',
   'Instalaciones eléctricas domiciliarias e industriales certificadas.',
   '+34 933 111 222', true, 4.50, 89),
  ('11111111-1111-1111-1111-111111111103', 'Fontanería Express', 'individual', 'Fontanería', 'Urgencias 24h', 'Valencia', 'Valencia',
   'Servicio de fontanería rápida para averías y reformas de baños y cocinas.',
   '+34 961 444 555', false, 4.80, 203)
on conflict (id) do nothing;
