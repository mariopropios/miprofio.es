-- Radio de desplazamiento del profesional (km)
-- Indica hasta qué distancia está dispuesto a desplazarse para realizar trabajos.
alter table public.professionals
  add column if not exists service_radius_km integer not null default 25;

comment on column public.professionals.service_radius_km is
  'Radio máximo de desplazamiento desde la ciudad base (km). Por defecto 25 km.';
