-- CashRápido · licencias adquiridas por los usuarios (Supabase)
--
-- Una fila = una licencia emitida después de un pago confirmado. El código de
-- licencia (`license_code`) es el mismo que entrega el backend de QvaPay y es
-- único. `user_id` puede quedar nulo cuando la compra se hizo sin una sesión
-- de Supabase; en ese caso `client_id` identifica el dispositivo que la
-- adquirió y se puede enlazar con la cuenta más adelante.
--
-- Seguridad:
--   · El cliente solo puede leer sus propias licencias (RLS).
--   · Nadie con la clave pública puede insertar, actualizar ni borrar.
--   · Las altas y los cambios los hace el backend con `service_role` (que
--     omite RLS) o el panel de Supabase.
--
-- Ejecutar DESPUÉS de 20261106000000_cashrapido_cloud.sql. Es idempotente.

begin;

-- ---------------------------------------------------------------------------
-- Tabla de licencias
-- ---------------------------------------------------------------------------

create table if not exists public.licenses (
  id uuid primary key default gen_random_uuid(),

  -- Dueño de la licencia. Se puede dejar nulo si la compra fue anónima.
  user_id uuid references auth.users (id) on delete cascade,

  -- Identificador del dispositivo que creó el pedido (QvaPay `client_id`).
  client_id text,

  -- Código que se entrega al usuario y que valida la app.
  license_code text not null unique
    check (char_length(btrim(license_code)) > 0),

  -- Plan comprado. Los IDs coinciden con `LICENSE_PLANS` de la web
  -- (weekly_personal, monthly_pro, annual_enterprise, etc.).
  plan_id text not null check (char_length(btrim(plan_id)) > 0),
  plan_level text not null
    check (plan_level in ('free', 'personal', 'pro', 'enterprise')),
  plan_period text not null
    check (plan_period in ('weekly', 'monthly', 'annual', 'lifetime')),

  status text not null default 'active'
    check (status in ('pending', 'active', 'expired', 'revoked', 'refunded', 'cancelled')),

  provider text not null
    check (provider in (
      'qvapay', 'paypal', 'apklis', 'art_pay',
      'transfermovil', 'enzona', 'ads', 'test', 'manual', 'other'
    )),

  -- IDs del pedido y de la transacción en el proveedor. El segundo es el que
  -- permite que un webhook reintentado no duplique la licencia.
  provider_order_id text,
  provider_transaction_id text,

  amount numeric(10, 2) not null default 0 check (amount >= 0),
  currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),

  starts_at timestamptz not null default now(),
  expires_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object'),

  constraint licenses_owner_check
    check (user_id is not null or client_id is not null),

  constraint licenses_expiry_check
    check (expires_at is null or expires_at > starts_at)
);

comment on table public.licenses is
  'Licencias emitidas tras un pago confirmado. Lectura por usuario; escritura solo desde el backend.';
comment on column public.licenses.user_id is
  'Cuenta de Supabase que posee la licencia; puede ser nula en compras anónimas.';
comment on column public.licenses.client_id is
  'Identificador del dispositivo usado en la compra (client_id de QvaPay).';
comment on column public.licenses.license_code is
  'Código único de licencia entregado al usuario.';
comment on column public.licenses.plan_id is
  'ID del plan comprado; debe coincidir con LICENSE_PLANS de la web.';
comment on column public.licenses.plan_level is
  'Nivel del plan: free, personal, pro o enterprise.';
comment on column public.licenses.plan_period is
  'Duración del plan: weekly, monthly, annual o lifetime.';
comment on column public.licenses.provider_order_id is
  'ID del pedido en el proveedor; en QvaPay es remote_id/order_id.';
comment on column public.licenses.provider_transaction_id is
  'ID de la transacción en el proveedor; sirve para idempotencia.';
comment on column public.licenses.metadata is
  'Datos adicionales del pago o del proveedor (JSON libre).';

-- ---------------------------------------------------------------------------
-- Índices
-- ---------------------------------------------------------------------------

-- Un pedido y una transacción del proveedor solo pueden generar una licencia.
-- Los índices son parciales para permitir varias filas sin esos IDs.
create unique index if not exists licenses_provider_order_uidx
  on public.licenses (provider, provider_order_id)
  where provider_order_id is not null;

create unique index if not exists licenses_provider_tx_uidx
  on public.licenses (provider, provider_transaction_id)
  where provider_transaction_id is not null;

-- Historial de licencias y búsqueda de la licencia vigente.
create index if not exists licenses_user_created_idx
  on public.licenses (user_id, created_at desc);

create index if not exists licenses_user_active_idx
  on public.licenses (user_id, expires_at desc nulls first)
  where status = 'active';

-- Permite localizar compras hechas sin sesión de Supabase.
create index if not exists licenses_client_idx
  on public.licenses (client_id, created_at desc)
  where client_id is not null;

-- ---------------------------------------------------------------------------
-- `updated_at` automático
-- ---------------------------------------------------------------------------

create or replace function public.licenses_set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists licenses_set_updated_at on public.licenses;
create trigger licenses_set_updated_at
  before update on public.licenses
  for each row execute function public.licenses_set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS: lectura de las licencias propias; escritura solo del backend
-- ---------------------------------------------------------------------------

alter table public.licenses enable row level security;

revoke all on public.licenses from anon, authenticated;
grant select on public.licenses to authenticated;

-- El backend usa la clave `service_role` desde el servidor. Esta clave nunca
-- debe incluirse en la app ni en el navegador.
grant select, insert, update, delete on public.licenses to service_role;

drop policy if exists licenses_select_own on public.licenses;
create policy licenses_select_own on public.licenses
  for select to authenticated
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Licencia vigente del usuario
-- ---------------------------------------------------------------------------
-- Devuelve la mejor licencia activa del usuario autenticado o `null`.
-- Se usa desde la app con:
--   rpc('my_current_license')
--
-- Criterio: primero el nivel más alto y, si hay empate, la que vence más
-- tarde. Las licencias de por vida (`expires_at` nulo) van primero.

create or replace function public.my_current_license()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select to_jsonb(l)
  from public.licenses l
  where l.user_id = auth.uid()
    and l.status = 'active'
    and (l.expires_at is null or l.expires_at > now())
  order by
    case l.plan_level
      when 'enterprise' then 3
      when 'pro' then 2
      when 'personal' then 1
      else 0
    end desc,
    l.expires_at desc nulls first,
    l.created_at desc
  limit 1;
$$;

comment on function public.my_current_license() is
  'Devuelve la licencia activa de mayor nivel del usuario autenticado, o null.';

revoke all on function public.my_current_license() from public;
revoke all on function public.my_current_license() from anon;
grant execute on function public.my_current_license() to authenticated;

-- ---------------------------------------------------------------------------
-- Ejemplo de alta desde el backend (service_role)
-- ---------------------------------------------------------------------------
-- insert into public.licenses (
--   user_id, client_id, license_code, plan_id, plan_level, plan_period,
--   status, provider, provider_order_id, provider_transaction_id,
--   amount, currency, starts_at, expires_at, metadata
-- ) values (
--   null, 'uuid-del-dispositivo', 'CR-XXXX-XXXX', 'monthly_pro',
--   'pro', 'monthly', 'active', 'qvapay', 'order-id', 'transaction-uuid',
--   1.00, 'USD', now(), now() + interval '30 days',
--   '{"source": "webhook-qvapay"}'
-- )
-- on conflict (license_code) do nothing;

commit;
