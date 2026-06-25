-- Verificación SMS por OTP (usada desde Edge Function phone-otp)
create table if not exists public.phone_otp_requests (
  id            uuid primary key default gen_random_uuid(),
  phone_e164    text not null,
  code_hash     text not null,
  expires_at    timestamptz not null,
  verified_at   timestamptz,
  attempt_count int not null default 0,
  created_at    timestamptz not null default now()
);

create index if not exists phone_otp_requests_phone_created_idx
  on public.phone_otp_requests (phone_e164, created_at desc);

alter table public.phone_otp_requests enable row level security;

comment on table public.phone_otp_requests is
  'Códigos OTP para verificar teléfonos en registro. Solo accesible vía service role (Edge Functions).';
