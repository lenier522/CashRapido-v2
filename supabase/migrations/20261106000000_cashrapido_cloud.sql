-- CashRápido · esquema en la nube (Supabase)
--
-- Cada tabla corresponde a una colección local de Hive (la misma que ya
-- respalda la app). Una fila = un registro del usuario, con el JSON completo
-- del modelo en `data` para que la copia sea fiel y no dependa de migraciones
-- de columnas cuando la app añada campos.
--
-- El acceso queda aislado por usuario con RLS: `user_id` siempre debe ser
-- `auth.uid()`. La app sube y baja todo el paquete con las funciones
-- `cloud_replace_data` y `cloud_export_data`.
--
-- Ejecutar una sola vez en el SQL Editor del proyecto. Es idempotente.

begin;

-- ---------------------------------------------------------------------------
-- Perfil del usuario (se crea solo al entrar con Google)
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  full_name text,
  avatar_url text,
  locale text default 'es',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated using (auth.uid() = id);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);

grant select, insert, update on public.profiles to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Tablas de datos del usuario
-- ---------------------------------------------------------------------------

do $schema$
declare
  t text;
  tables text[] := array[
    -- Cartera
    'transactions', 'categories', 'cards', 'recurring_transactions',
    'notifications',
    -- Negocio
    'businesses', 'products', 'sales', 'business_expenses', 'closings',
    'product_categories', 'sellers', 'seller_inventory',
    -- Préstamos
    'loans', 'loan_payments', 'borrowers', 'loan_activities',
    -- Asistente
    'ai_chats'
  ];
begin
  foreach t in array tables loop
    execute format($f$
      create table if not exists public.%I (
        user_id uuid not null references auth.users (id) on delete cascade,
        id text not null,
        data jsonb not null default '{}'::jsonb,
        updated_at timestamptz not null default now(),
        primary key (user_id, id)
      );

      create index if not exists %I
        on public.%I (user_id, updated_at desc);

      alter table public.%I enable row level security;
      grant select, insert, update, delete on public.%I to authenticated;

      drop policy if exists %I on public.%I;
      create policy %I on public.%I
        for select to authenticated using (auth.uid() = user_id);

      drop policy if exists %I on public.%I;
      create policy %I on public.%I
        for insert to authenticated with check (auth.uid() = user_id);

      drop policy if exists %I on public.%I;
      create policy %I on public.%I
        for update to authenticated
        using (auth.uid() = user_id) with check (auth.uid() = user_id);

      drop policy if exists %I on public.%I;
      create policy %I on public.%I
        for delete to authenticated using (auth.uid() = user_id);
    $f$,
      t,
      t || '_user_updated_idx', t,
      t,
      t,
      t || '_select_own', t, t || '_select_own', t,
      t || '_insert_own', t, t || '_insert_own', t,
      t || '_update_own', t, t || '_update_own', t,
      t || '_delete_own', t, t || '_delete_own', t
    );
  end loop;
end;
$schema$;

-- ---------------------------------------------------------------------------
-- Subida: reemplaza el paquete del usuario en una sola transacción
-- ---------------------------------------------------------------------------
--
-- `payload` es un objeto { "transactions": [{ "id": "...", "data": {...} }] }.
-- Solo se tocan las tablas incluidas en el objeto: así un cliente antiguo no
-- borra colecciones que todavía no conoce.

create or replace function public.cloud_replace_data(payload jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $fn$
declare
  uid uuid := auth.uid();
  t text;
  rows jsonb;
  tables text[] := array[
    'transactions', 'categories', 'cards', 'recurring_transactions',
    'notifications',
    'businesses', 'products', 'sales', 'business_expenses', 'closings',
    'product_categories', 'sellers', 'seller_inventory',
    'loans', 'loan_payments', 'borrowers', 'loan_activities',
    'ai_chats'
  ];
begin
  if uid is null then
    raise exception 'No autenticado';
  end if;

  foreach t in array tables loop
    if payload ? t then
      rows := coalesce(payload -> t, '[]'::jsonb);

      execute format('delete from public.%I where user_id = $1', t)
        using uid;

      execute format($q$
        insert into public.%I (user_id, id, data)
        select $1, r.id, coalesce(r.data, '{}'::jsonb)
        from jsonb_to_recordset($2) as r(id text, data jsonb)
        where r.id is not null
      $q$, t)
        using uid, rows;
    end if;
  end loop;
end;
$fn$;

grant execute on function public.cloud_replace_data(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Descarga: devuelve todo el paquete del usuario en una sola llamada
-- ---------------------------------------------------------------------------

create or replace function public.cloud_export_data()
returns jsonb
language plpgsql
security invoker
set search_path = public
as $fn$
declare
  uid uuid := auth.uid();
  t text;
  rows jsonb;
  result jsonb := '{}'::jsonb;
  tables text[] := array[
    'transactions', 'categories', 'cards', 'recurring_transactions',
    'notifications',
    'businesses', 'products', 'sales', 'business_expenses', 'closings',
    'product_categories', 'sellers', 'seller_inventory',
    'loans', 'loan_payments', 'borrowers', 'loan_activities',
    'ai_chats'
  ];
begin
  if uid is null then
    raise exception 'No autenticado';
  end if;

  foreach t in array tables loop
    execute format($q$
      select coalesce(
        jsonb_agg(jsonb_build_object('id', id, 'data', data)),
        '[]'::jsonb
      )
      from public.%I
      where user_id = $1
    $q$, t)
      into rows
      using uid;

    result := result || jsonb_build_object(t, rows);
  end loop;

  return result;
end;
$fn$;

grant execute on function public.cloud_export_data() to authenticated;

commit;
