-- Fotos en reseñas + respuesta del profesional
-- Ejecutar en: Supabase Dashboard → SQL Editor

-- ── Columnas nuevas en reviews ──────────────────────────────────────────────
alter table public.reviews
  add column if not exists photo_urls  jsonb       not null default '[]'::jsonb,
  add column if not exists owner_reply text,
  add column if not exists owner_reply_at timestamptz;

comment on column public.reviews.photo_urls     is 'URLs públicas de fotos adjuntas a la reseña (array JSON)';
comment on column public.reviews.owner_reply    is 'Respuesta pública del profesional a esta reseña';
comment on column public.reviews.owner_reply_at is 'Fecha en que el profesional respondió';

-- ── RLS: el profesional puede actualizar SOLO owner_reply / owner_reply_at ──
-- (el UPDATE existente solo permite al autor; este añade al dueño del perfil)
drop policy if exists "review_professional_reply" on public.reviews;
create policy "review_professional_reply"
  on public.reviews for update
  using (
    professional_id in (
      select id from public.professionals
      where owner_id = auth.uid()
    )
  )
  with check (
    professional_id in (
      select id from public.professionals
      where owner_id = auth.uid()
    )
  );

-- ── Bucket de fotos de reseñas (reutiliza profile-photos con subcarpeta) ────
-- Las fotos se suben a: profile-photos/{userId}/reviews/{timestamp}.ext
-- Las políticas del bucket profile-photos ya permiten subida en {userId}/*
-- No se necesita un bucket nuevo.
