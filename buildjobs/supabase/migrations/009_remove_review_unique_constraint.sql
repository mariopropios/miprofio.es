-- Eliminar restricción de una reseña por usuario por profesional
-- para permitir múltiples reseñas del mismo usuario.
-- Ejecutar en: Supabase Dashboard → SQL Editor

alter table public.reviews
  drop constraint if exists reviews_professional_id_user_id_key;
