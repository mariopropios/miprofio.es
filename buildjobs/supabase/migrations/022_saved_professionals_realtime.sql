-- Realtime: actualizar contador de guardados en el perfil al instante.
-- Idempotente: no falla si la tabla ya está en la publicación.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'saved_professionals'
  ) then
    alter publication supabase_realtime add table public.saved_professionals;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'professionals'
  ) then
    alter publication supabase_realtime add table public.professionals;
  end if;
end $$;
