-- =============================================================================
-- BuildJobs — Tabla de profesionales
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run
--
-- Campos:
--   name          → Nombre del profesional o empresa
--   profession    → Oficio (Albañil, Fontanero, Pladurista, etc.)
--   description   → Descripción de servicios
--   profile_photo → URL de la foto de perfil
--   city          → Ciudad
--   rating        → Puntuación media (0–5, se recalcula con reseñas)
--   review_count  → Número total de reseñas
-- =============================================================================

create extension if not exists "pgcrypto";

-- Si ya existía la tabla con columnas antiguas, renombrarlas
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'professionals' and column_name = 'category'
  ) then
    alter table public.professionals rename column category to profession;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'professionals' and column_name = 'image_url'
  ) then
    alter table public.professionals rename column image_url to profile_photo;
  end if;
end $$;

-- Crear tabla (instalación nueva)
create table if not exists public.professionals (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  profession    text not null,
  description   text,
  profile_photo text,
  city          text not null,
  rating        numeric(3, 2) not null default 0
                  check (rating >= 0 and rating <= 5),
  review_count  int not null default 0 check (review_count >= 0),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Añadir columnas que falten (si la tabla venía de una versión anterior más completa)
alter table public.professionals add column if not exists profession    text;
alter table public.professionals add column if not exists profile_photo text;
alter table public.professionals add column if not exists description   text;
alter table public.professionals add column if not exists rating        numeric(3,2) not null default 0;
alter table public.professionals add column if not exists review_count  int not null default 0;

comment on table  public.professionals               is 'Profesionales del sector construcción';
comment on column public.professionals.name          is 'Nombre del profesional o empresa';
comment on column public.professionals.profession    is 'Oficio: Albañil, Fontanero, Pladurista, etc.';
comment on column public.professionals.description     is 'Descripción de servicios y experiencia';
comment on column public.professionals.profile_photo is 'URL de la foto de perfil';
comment on column public.professionals.city          is 'Ciudad donde opera';
comment on column public.professionals.rating        is 'Puntuación media (calculada desde reseñas)';

-- Índices
create index if not exists idx_professionals_profession on public.professionals (profession);
create index if not exists idx_professionals_city       on public.professionals (city);
create index if not exists idx_professionals_rating     on public.professionals (rating desc);

-- RLS
alter table public.professionals enable row level security;

drop policy if exists "professionals_select_public" on public.professionals;
create policy "professionals_select_public"
  on public.professionals for select using (true);

drop policy if exists "professionals_insert_authenticated" on public.professionals;
create policy "professionals_insert_authenticated"
  on public.professionals for insert with check (auth.uid() is not null);

drop policy if exists "professionals_update_authenticated" on public.professionals;
create policy "professionals_update_authenticated"
  on public.professionals for update using (auth.uid() is not null);

-- Trigger updated_at
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists professionals_set_updated_at on public.professionals;
create trigger professionals_set_updated_at
  before update on public.professionals
  for each row execute function public.set_updated_at();

-- Storage para fotos de perfil
insert into storage.buckets (id, name, public)
values ('profile-photos', 'profile-photos', true)
on conflict (id) do nothing;

drop policy if exists "profile_photos_public_read" on storage.objects;
create policy "profile_photos_public_read"
  on storage.objects for select
  using (bucket_id = 'profile-photos');

drop policy if exists "profile_photos_auth_upload" on storage.objects;
create policy "profile_photos_auth_upload"
  on storage.objects for insert
  with check (bucket_id = 'profile-photos' and auth.uid() is not null);

-- Datos de ejemplo
insert into public.professionals (id, name, profession, description, city, rating, review_count)
values
  (
    '11111111-1111-1111-1111-111111111101',
    'Carlos Mendoza',
    'Albañil',
    'Albañil con 12 años de experiencia en reformas integrales, tabiques y alicatados.',
    'Madrid', 4.80, 47
  ),
  (
    '11111111-1111-1111-1111-111111111102',
    'Fontanería Rápida López',
    'Fontanero',
    'Fontanero autónomo. Reparación de averías, instalaciones de baños y cocinas.',
    'Barcelona', 4.60, 83
  ),
  (
    '11111111-1111-1111-1111-111111111103',
    'Pladur Pro Valencia',
    'Pladurista',
    'Especialistas en pladur: tabiques, falsos techos, aislamiento acústico y térmico.',
    'Valencia', 4.90, 112
  ),
  (
    '11111111-1111-1111-1111-111111111104',
    'Electricidad Martín',
    'Electricista',
    'Instalaciones eléctricas domiciliarias, boletines y cuadros eléctricos.',
    'Sevilla', 4.50, 31
  ),
  (
    '11111111-1111-1111-1111-111111111105',
    'Pinturas del Norte',
    'Pintor',
    'Pintura interior y exterior, alisados y empapelado.',
    'Bilbao', 4.70, 56
  )
on conflict (id) do update set
  name         = excluded.name,
  profession   = excluded.profession,
  description  = excluded.description,
  city         = excluded.city,
  rating       = excluded.rating,
  review_count = excluded.review_count,
  updated_at   = now();
