-- Permitir ver los profesionales guardados de cualquier usuario (perfil público).

drop policy if exists "saved_select_public" on public.saved_professionals;
create policy "saved_select_public"
  on public.saved_professionals for select
  using (true);
