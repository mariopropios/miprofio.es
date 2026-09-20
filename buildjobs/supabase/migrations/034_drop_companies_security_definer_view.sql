-- Vista legacy de compatibilidad; la app usa public.professionals.
-- SECURITY DEFINER / security_invoker=false disparaba el Security Advisor.
-- No hay clientes que consulten .from('companies').

drop view if exists public.companies;
