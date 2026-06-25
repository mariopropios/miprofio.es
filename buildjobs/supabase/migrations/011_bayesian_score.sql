-- Columna generada: media bayesiana para un ranking más justo
-- Fórmula: (C*m + n*avg) / (C+n)  con C=5 (prior), m=4.0 (nota neutra por defecto)
-- Ejemplo:  500 reseñas ×4.7 → 4.69  |  1 reseña ×5.0 → 4.17
alter table public.professionals
  add column if not exists bayesian_score numeric generated always as (
    (20.0 + coalesce(review_count, 0) * coalesce(rating, 0.0))
    / (5.0 + coalesce(review_count, 0))
  ) stored;

comment on column public.professionals.bayesian_score is
  'Media bayesiana (C=5, m=4). Penaliza a profesionales con pocas reseñas.';

-- Índice para que el ORDER BY sea rápido
create index if not exists professionals_bayesian_score_idx
  on public.professionals (bayesian_score desc);
