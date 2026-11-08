-- CashRápido · chat de soporte y campañas (Supabase)
--
-- Un hilo por cliente: `support_conversations.user_id` es único, así que cada
-- persona tiene un historial continuo con soporte (como un WhatsApp con la
-- empresa). Los mensajes van en `support_messages`.
--
-- El soporte se identifica por el correo del JWT contra `support_admins`, que
-- arranca con leniercruz02@gmail.com. Se pueden añadir más correos de soporte
-- con un simple insert; no hay que tocar las políticas.
--
-- Reglas:
--   · El cliente solo lee su hilo y solo escribe en él.
--   · El soporte lee todos los hilos, responde a cualquiera y puede enviar
--     campañas a todos los perfiles o a un usuario concreto por su id.
--   · Todas las escrituras pasan por funciones `security definer` para que el
--     contador de no leídos y el resumen del hilo queden siempre coherentes.
--
-- Ejecutar DESPUÉS de 20261106000000_cashrapido_cloud.sql. Es idempotente.
--
-- Uso desde la app:
--   rpc('support_ensure_conversation')            -> id de mi hilo
--   rpc('support_send_message', {p_body})         -> envío del cliente
--   rpc('support_send_message', {p_body, p_conversation_id}) -> respuesta de soporte
--   rpc('support_mark_read', {p_conversation_id}) -> marcar leído
--   rpc('support_set_status', {p_conversation_id, p_closed}) -> abrir/cerrar
--   rpc('support_send_campaign', {p_title, p_body})          -> a todos
--   rpc('support_send_campaign', {p_title, p_body, p_target_user_id}) -> a uno
--   rpc('support_inbox')                          -> bandeja del soporte
--   select * from support_messages where conversation_id = ...  (tiempo real)
--
-- `support_messages` y `support_conversations` se añaden a Realtime para que el
-- chat se actualice sin recargar.

begin;

-- ---------------------------------------------------------------------------
-- Quién es soporte
-- ---------------------------------------------------------------------------

create table if not exists public.support_admins (
  email text primary key,
  note text,
  created_at timestamptz not null default now()
);

insert into public.support_admins (email, note)
values ('leniercruz02@gmail.com', 'Soporte principal')
on conflict (email) do nothing;

alter table public.support_admins enable row level security;
-- Sin políticas: nadie la lee desde la API; solo las funciones definer.

revoke all on public.support_admins from anon, authenticated;

-- `true` si quien llama está autenticado con un correo de soporte.
create or replace function public.support_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.support_admins a
    where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

-- ---------------------------------------------------------------------------
-- Hilos y mensajes
-- ---------------------------------------------------------------------------

create table if not exists public.support_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  subject text,
  status text not null default 'open' check (status in ('open', 'closed')),
  last_message_preview text,
  last_message_role text check (last_message_role in ('user', 'support', 'system')),
  last_message_at timestamptz,
  unread_for_user integer not null default 0 check (unread_for_user >= 0),
  unread_for_support integer not null default 0 check (unread_for_support >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.support_campaigns (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users (id) on delete set null,
  title text,
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  audience text not null default 'all' check (audience in ('all', 'single')),
  target_user_id uuid references auth.users (id) on delete set null,
  recipients integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.support_conversations (id) on delete cascade,
  -- Dueño del hilo: permite filtrar por RLS sin joins y sobrevive si el
  -- remitente borra la cuenta.
  user_id uuid not null references auth.users (id) on delete cascade,
  sender_id uuid references auth.users (id) on delete set null,
  sender_role text not null default 'user' check (sender_role in ('user', 'support', 'system')),
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  campaign_id uuid references public.support_campaigns (id) on delete set null,
  read_by_user_at timestamptz,
  read_by_support_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.support_campaign_recipients (
  campaign_id uuid not null references public.support_campaigns (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  conversation_id uuid references public.support_conversations (id) on delete set null,
  message_id uuid references public.support_messages (id) on delete set null,
  delivered_at timestamptz not null default now(),
  read_at timestamptz,
  primary key (campaign_id, user_id)
);

create index if not exists support_conversations_last_idx
  on public.support_conversations (last_message_at desc nulls last);
create index if not exists support_conversations_pending_idx
  on public.support_conversations (unread_for_support desc, last_message_at desc nulls last);
create index if not exists support_messages_conversation_idx
  on public.support_messages (conversation_id, created_at);
create index if not exists support_messages_user_idx
  on public.support_messages (user_id, created_at desc);
create index if not exists support_messages_campaign_idx
  on public.support_messages (campaign_id);
create index if not exists support_campaign_recipients_user_idx
  on public.support_campaign_recipients (user_id, delivered_at desc);

-- ---------------------------------------------------------------------------
-- RLS: nadie toca las tablas directamente salvo lectura
-- ---------------------------------------------------------------------------

alter table public.support_conversations enable row level security;
alter table public.support_messages enable row level security;
alter table public.support_campaigns enable row level security;
alter table public.support_campaign_recipients enable row level security;

revoke all on public.support_conversations from anon, authenticated;
revoke all on public.support_messages from anon, authenticated;
revoke all on public.support_campaigns from anon, authenticated;
revoke all on public.support_campaign_recipients from anon, authenticated;

grant select on public.support_conversations to authenticated;
grant select on public.support_messages to authenticated;
grant select on public.support_campaigns to authenticated;
grant select on public.support_campaign_recipients to authenticated;

drop policy if exists support_conversations_select on public.support_conversations;
create policy support_conversations_select on public.support_conversations
  for select to authenticated
  using (auth.uid() = user_id or public.support_is_admin());

drop policy if exists support_messages_select on public.support_messages;
create policy support_messages_select on public.support_messages
  for select to authenticated
  using (auth.uid() = user_id or public.support_is_admin());

drop policy if exists support_campaigns_select on public.support_campaigns;
create policy support_campaigns_select on public.support_campaigns
  for select to authenticated
  using (public.support_is_admin());

drop policy if exists support_campaign_recipients_select
  on public.support_campaign_recipients;
create policy support_campaign_recipients_select
  on public.support_campaign_recipients
  for select to authenticated
  using (auth.uid() = user_id or public.support_is_admin());

-- ---------------------------------------------------------------------------
-- Hilo del cliente
-- ---------------------------------------------------------------------------
-- Devuelve el id del hilo de quien llama y lo crea si aún no existe. Sirve
-- para abrir la pantalla de chat antes del primer mensaje.

create or replace function public.support_ensure_conversation(
  p_subject text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  cid uuid;
begin
  if uid is null then
    raise exception 'No autenticado';
  end if;

  insert into public.support_conversations as c (user_id, subject)
  values (uid, nullif(btrim(coalesce(p_subject, '')), ''))
  on conflict (user_id) do update
    set updated_at = now(),
        subject = coalesce(c.subject, excluded.subject)
  returning c.id into cid;

  return cid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Envío de mensajes (cliente o soporte)
-- ---------------------------------------------------------------------------
-- El rol se deduce del llamador: si es soporte, el mensaje queda como
-- 'support'; si no, como 'user'. Un cliente no puede escribir en un hilo ajeno.

create or replace function public.support_send_message(
  p_body text,
  p_conversation_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v_body text := btrim(coalesce(p_body, ''));
  v_admin boolean := public.support_is_admin();
  v_conversation public.support_conversations;
  v_role text;
  v_message_id uuid;
begin
  if uid is null then
    raise exception 'No autenticado';
  end if;
  if v_body = '' then
    raise exception 'El mensaje está vacío';
  end if;
  if char_length(v_body) > 4000 then
    raise exception 'El mensaje supera los 4000 caracteres';
  end if;

  if p_conversation_id is null then
    if v_admin then
      raise exception 'Indica la conversación del cliente';
    end if;
    p_conversation_id := public.support_ensure_conversation(null);
  end if;

  select * into v_conversation
  from public.support_conversations
  where id = p_conversation_id;

  if not found then
    raise exception 'Conversación no encontrada';
  end if;
  if not v_admin and v_conversation.user_id <> uid then
    raise exception 'Sin permiso sobre esta conversación';
  end if;

  v_role := case when v_admin then 'support' else 'user' end;

  insert into public.support_messages
    (conversation_id, user_id, sender_id, sender_role, body)
  values
    (v_conversation.id, v_conversation.user_id, uid, v_role, v_body)
  returning id into v_message_id;

  update public.support_conversations
  set updated_at = now(),
      last_message_at = now(),
      last_message_preview = left(v_body, 160),
      last_message_role = v_role,
      status = 'open',
      unread_for_user = unread_for_user + case when v_role = 'user' then 0 else 1 end,
      unread_for_support = unread_for_support + case when v_role = 'user' then 1 else 0 end
  where id = v_conversation.id;

  return v_message_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Marcar leído
-- ---------------------------------------------------------------------------
-- El cliente pone a cero lo que le escribió soporte; soporte pone a cero lo
-- que escribió el cliente. Sin `p_conversation_id`, actúa sobre el hilo propio.

create or replace function public.support_mark_read(
  p_conversation_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v_admin boolean := public.support_is_admin();
  v_conversation public.support_conversations;
begin
  if uid is null then
    raise exception 'No autenticado';
  end if;

  if p_conversation_id is null and not v_admin then
    select * into v_conversation
    from public.support_conversations
    where user_id = uid;
  elsif p_conversation_id is not null then
    select * into v_conversation
    from public.support_conversations
    where id = p_conversation_id;
  else
    raise exception 'Indica la conversación';
  end if;

  if not found then
    return;
  end if;
  if not v_admin and v_conversation.user_id <> uid then
    raise exception 'Sin permiso sobre esta conversación';
  end if;

  if v_admin then
    update public.support_messages
    set read_by_support_at = now()
    where conversation_id = v_conversation.id
      and sender_role = 'user'
      and read_by_support_at is null;

    update public.support_conversations
    set unread_for_support = 0
    where id = v_conversation.id;
  else
    update public.support_messages
    set read_by_user_at = now()
    where conversation_id = v_conversation.id
      and sender_role in ('support', 'system')
      and read_by_user_at is null;

    update public.support_conversations
    set unread_for_user = 0
    where id = v_conversation.id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Abrir / cerrar el hilo
-- ---------------------------------------------------------------------------

create or replace function public.support_set_status(
  p_conversation_id uuid,
  p_closed boolean default true
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v_admin boolean := public.support_is_admin();
  v_conversation public.support_conversations;
begin
  if uid is null then
    raise exception 'No autenticado';
  end if;

  select * into v_conversation
  from public.support_conversations
  where id = p_conversation_id;

  if not found then
    raise exception 'Conversación no encontrada';
  end if;
  if not v_admin and v_conversation.user_id <> uid then
    raise exception 'Sin permiso sobre esta conversación';
  end if;

  update public.support_conversations
  set status = case when p_closed then 'closed' else 'open' end,
      updated_at = now()
  where id = p_conversation_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Campañas: un mensaje a todos los clientes o a uno concreto
-- ---------------------------------------------------------------------------
-- Crea (o reutiliza) el hilo de cada destinatario y deja el mensaje como
-- 'support', con `campaign_id` para poder rastrear la entrega.

create or replace function public.support_send_campaign(
  p_body text,
  p_title text default null,
  p_target_user_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v_body text := btrim(coalesce(p_body, ''));
  v_title text := nullif(btrim(coalesce(p_title, '')), '');
  v_audience text;
  v_campaign_id uuid;
  v_recipients integer := 0;
  r record;
  v_conversation_id uuid;
  v_message_id uuid;
begin
  if not public.support_is_admin() then
    raise exception 'Solo el soporte puede enviar campañas';
  end if;
  if v_body = '' then
    raise exception 'El mensaje está vacío';
  end if;
  if char_length(v_body) > 4000 then
    raise exception 'El mensaje supera los 4000 caracteres';
  end if;

  v_audience := case when p_target_user_id is null then 'all' else 'single' end;

  if p_target_user_id is not null
     and not exists (
       select 1 from public.profiles p where p.id = p_target_user_id
     ) then
    raise exception 'El usuario no existe o no ha entrado con Google todavía';
  end if;

  insert into public.support_campaigns
    (created_by, title, body, audience, target_user_id)
  values
    (uid, v_title, v_body, v_audience, p_target_user_id)
  returning id into v_campaign_id;

  for r in
    select p.id
    from public.profiles p
    where (p_target_user_id is not null and p.id = p_target_user_id)
       or (p_target_user_id is null and p.id <> uid)
  loop
    insert into public.support_conversations as c (user_id)
    values (r.id)
    on conflict (user_id) do update set updated_at = now()
    returning c.id into v_conversation_id;

    insert into public.support_messages
      (conversation_id, user_id, sender_id, sender_role, body, campaign_id)
    values
      (v_conversation_id, r.id, uid, 'support', v_body, v_campaign_id)
    returning id into v_message_id;

    update public.support_conversations
    set updated_at = now(),
        last_message_at = now(),
        last_message_preview = left(v_body, 160),
        last_message_role = 'support',
        status = 'open',
        unread_for_user = unread_for_user + 1
    where id = v_conversation_id;

    insert into public.support_campaign_recipients
      (campaign_id, user_id, conversation_id, message_id)
    values
      (v_campaign_id, r.id, v_conversation_id, v_message_id)
    on conflict (campaign_id, user_id) do nothing;

    v_recipients := v_recipients + 1;
  end loop;

  update public.support_campaigns
  set recipients = v_recipients
  where id = v_campaign_id;

  return v_campaign_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Bandeja del soporte: todos los clientes ordenados por actividad
-- ---------------------------------------------------------------------------

create or replace function public.support_inbox()
returns table (
  conversation_id uuid,
  user_id uuid,
  email text,
  full_name text,
  avatar_url text,
  subject text,
  status text,
  last_message_preview text,
  last_message_at timestamptz,
  last_message_role text,
  unread_for_support integer,
  unread_for_user integer,
  message_count bigint,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.support_is_admin() then
    raise exception 'Solo el soporte puede ver la bandeja';
  end if;

  return query
  select c.id,
         c.user_id,
         p.email,
         p.full_name,
         p.avatar_url,
         c.subject,
         c.status,
         c.last_message_preview,
         c.last_message_at,
         c.last_message_role,
         c.unread_for_support,
         c.unread_for_user,
         (select count(*)
            from public.support_messages m
           where m.conversation_id = c.id) as message_count,
         c.created_at
  from public.support_conversations c
  left join public.profiles p on p.id = c.user_id
  order by c.last_message_at desc nulls last, c.created_at desc;
end;
$$;

-- ---------------------------------------------------------------------------
-- Permisos
-- ---------------------------------------------------------------------------
-- Las funciones nacen con EXECUTE para PUBLIC: se recorta a `authenticated`.

revoke all on function public.support_is_admin() from public, anon;
revoke all on function public.support_ensure_conversation(text) from public, anon;
revoke all on function public.support_send_message(text, uuid) from public, anon;
revoke all on function public.support_mark_read(uuid) from public, anon;
revoke all on function public.support_set_status(uuid, boolean) from public, anon;
revoke all on function public.support_send_campaign(text, text, uuid) from public, anon;
revoke all on function public.support_inbox() from public, anon;

grant execute on function public.support_is_admin() to authenticated;
grant execute on function public.support_ensure_conversation(text) to authenticated;
grant execute on function public.support_send_message(text, uuid) to authenticated;
grant execute on function public.support_mark_read(uuid) to authenticated;
grant execute on function public.support_set_status(uuid, boolean) to authenticated;
grant execute on function public.support_send_campaign(text, text, uuid) to authenticated;
grant execute on function public.support_inbox() to authenticated;

-- ---------------------------------------------------------------------------
-- Tiempo real: el chat recibe mensajes sin recargar
-- ---------------------------------------------------------------------------

do $realtime$
begin
  begin
    alter publication supabase_realtime add table public.support_messages;
  exception
    when duplicate_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.support_conversations;
  exception
    when duplicate_object then null;
  end;
end;
$realtime$;

commit;
