-- Realtime: actualizar contador de guardados en el perfil al instante.
alter publication supabase_realtime add table public.saved_professionals;
alter publication supabase_realtime add table public.professionals;
