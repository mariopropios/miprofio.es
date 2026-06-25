-- ── Habilitar Realtime en tablas de chat ──────────────────────────────────────
-- Ejecutar en el SQL Editor de Supabase

-- Añadir las tablas a la publicación de Realtime
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.conversations;

-- Asegurarse de que owner_id existe en professionals (por si la migración
-- inicial no lo incluía con ese nombre exacto)
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name   = 'professionals'
      and column_name  = 'owner_id'
  ) then
    alter table public.professionals add column owner_id uuid references auth.users(id);
    update public.professionals set owner_id = id where owner_id is null;
  end if;
end $$;
