-- Categorías en las que el profesional desea aparecer al filtrar.
-- Ejemplo: ["reparaciones", "reformas"]
-- Se rellena durante el registro; por defecto vacío (sin filtro activo).
alter table public.professionals
  add column if not exists service_categories jsonb not null default '[]'::jsonb;

comment on column public.professionals.service_categories is
  'IDs de las categorías del catálogo en las que el profesional quiere aparecer (ej. ["reparaciones","reformas"]).';

create index if not exists professionals_service_categories_gin_idx
  on public.professionals using gin (service_categories);
