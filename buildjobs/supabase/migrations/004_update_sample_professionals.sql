-- =============================================================================
-- BuildJobs — Actualizar profesionales de ejemplo
-- Ejecutar en Supabase → SQL Editor si los datos siguen siendo los antiguos
-- (Reformas García, Fontanería Express, etc.)
-- =============================================================================

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
