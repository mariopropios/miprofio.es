-- Coordenadas geográficas para filtrar profesionales por cercanía.

alter table public.professionals
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

-- Profesionales legacy sin dirección: usar ciudad como mínimo hasta que editen su ficha.
update public.professionals
set address = city
where address is null or trim(address) = '';

alter table public.professionals
  alter column address set not null;

alter table public.professionals
  alter column address set default '';

create index if not exists professionals_geo_idx
  on public.professionals (latitude, longitude)
  where latitude is not null and longitude is not null;

comment on column public.professionals.latitude is 'Latitud geocodificada de la dirección del profesional';
comment on column public.professionals.longitude is 'Longitud geocodificada de la dirección del profesional';
comment on column public.professionals.address is 'Dirección postal obligatoria para filtrado por cercanía';
