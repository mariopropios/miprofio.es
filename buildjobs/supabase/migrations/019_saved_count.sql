-- Contador desnormalizado de guardados por profesional.
-- Evita COUNT(*) en cada consulta; se mantiene mediante trigger.

alter table public.professionals
  add column if not exists saved_count integer not null default 0;

-- Rellenar conteos actuales
update public.professionals p
set saved_count = (
  select count(*)::integer
  from public.saved_professionals sp
  where sp.professional_id = p.id
);

-- Función que incrementa / decrementa el contador
create or replace function public.fn_update_saved_count()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  if TG_OP = 'INSERT' then
    update public.professionals
      set saved_count = saved_count + 1
      where id = NEW.professional_id;
  elsif TG_OP = 'DELETE' then
    update public.professionals
      set saved_count = greatest(saved_count - 1, 0)
      where id = OLD.professional_id;
  end if;
  return null;
end;
$$;

-- Trigger sobre saved_professionals
drop trigger if exists trg_update_saved_count on public.saved_professionals;
create trigger trg_update_saved_count
  after insert or delete on public.saved_professionals
  for each row execute function public.fn_update_saved_count();

comment on column public.professionals.saved_count
  is 'N\u00famero de usuarios que han guardado este profesional (mantenido por trigger)';
