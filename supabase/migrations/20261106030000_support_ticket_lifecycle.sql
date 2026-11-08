-- CashRápido · tickets de soporte: cerrar, borrar y abrir uno nuevo
--
-- Reglas que añade esta migración:
--   · Solo el equipo de soporte puede cerrar (o reabrir) un ticket.
--   · Un ticket cerrado ya no admite mensajes: el cliente tiene que empezar
--     una conversación nueva, y esa es la que se sigue usando.
--   · Tanto el cliente como el soporte pueden eliminar un ticket; al hacerlo
--     se borran también sus mensajes (`on delete cascade`).
--
-- Un cliente puede tener varias conversaciones (una por ticket cerrado), pero
-- solo una abierta a la vez. Eso sustituye el `unique(user_id)` original.
--
-- Ejecutar DESPUÉS de 20261106010000_support_chat.sql. Es idempotente.

begin;

-- ---------------------------------------------------------------------------
-- Un solo ticket abierto por cliente
-- ---------------------------------------------------------------------------

alter table public.support_conversations
  drop constraint if exists support_conversations_user_id_key;

create unique index if not exists support_conversations_open_user_idx
  on public.support_conversations (user_id)
  where status = 'open';

-- ---------------------------------------------------------------------------
-- Hilo abierto del cliente (uso interno de las funciones definer)
-- ---------------------------------------------------------------------------

create or replace function public.support_open_conversation(p_user_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select c.id
  from public.support_conversations c
  where c.user_id = p_user_id
    and c.status = 'open'
  order by c.created_at desc
  limit 1;
$$;

revoke all on function public.support_open_conversation(uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Hilo del cliente: devuelve el abierto o crea uno nuevo
-- ---------------------------------------------------------------------------
-- Si el cliente ya tiene un ticket abierto se reutiliza; si el anterior quedó
-- cerrado, se crea una conversación nueva (el ticket cerrado se conserva como
-- histórico hasta que alguien lo elimine).

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
  v_subject text := nullif(btrim(coalesce(p_subject, '')), '');
begin
  if uid is null then
    raise exception 'No autenticado';
  end if;

  cid := public.support_open_conversation(uid);

  if cid is null then
    begin
      insert into public.support_conversations (user_id, subject)
      values (uid, v_subject)
      returning id into cid;
    exception
      when unique_violation then
        -- Otra petición creó el ticket abierto al mismo tiempo.
        cid := public.support_open_conversation(uid);
    end;
  elsif v_subject is not null then
    update public.support_conversations
    set subject = coalesce(subject, v_subject),
        updated_at = now()
    where id = cid;
  end if;

  return cid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Envío de mensajes (cliente o soporte)
-- ---------------------------------------------------------------------------
-- Un ticket cerrado no admite mensajes: el cliente debe abrir uno nuevo y el
-- soporte puede reabrirlo desde la app si hace falta.

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
  if v_conversation.status = 'closed' then
    raise exception 'La conversación está cerrada; empieza una nueva';
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
      unread_for_user = unread_for_user + case when v_role = 'user' then 0 else 1 end,
      unread_for_support = unread_for_support + case when v_role = 'user' then 1 else 0 end
  where id = v_conversation.id;

  return v_message_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Marcar leído
-- ---------------------------------------------------------------------------

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
    -- El ticket más reciente del cliente (puede haber cerrados detrás).
    select * into v_conversation
    from public.support_conversations
    where user_id = uid
    order by created_at desc
    limit 1;
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
-- Abrir / cerrar el ticket (solo soporte)
-- ---------------------------------------------------------------------------
-- Al cerrar se limpian los contadores: un ticket cerrado no debe seguir
-- generando insignias de no leídos. Al reabrir se comprueba que el cliente no
-- tenga ya otro ticket abierto (solo puede haber uno).

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
  if not v_admin then
    raise exception 'Solo el soporte puede cerrar o reabrir un ticket';
  end if;

  select * into v_conversation
  from public.support_conversations
  where id = p_conversation_id;

  if not found then
    raise exception 'Conversación no encontrada';
  end if;

  if p_closed then
    update public.support_conversations
    set status = 'closed',
        updated_at = now(),
        unread_for_user = 0,
        unread_for_support = 0
    where id = p_conversation_id;
  else
    if exists (
      select 1
      from public.support_conversations c
      where c.user_id = v_conversation.user_id
        and c.status = 'open'
        and c.id <> p_conversation_id
    ) then
      raise exception 'El cliente ya tiene una conversación abierta';
    end if;

    update public.support_conversations
    set status = 'open',
        updated_at = now()
    where id = p_conversation_id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Eliminar un ticket (cliente dueño o soporte)
-- ---------------------------------------------------------------------------
-- Los mensajes caen con la cascada. La entrega de campañas conserva su fila,
-- pero pierde la referencia a la conversación borrada.

create or replace function public.support_delete_conversation(
  p_conversation_id uuid
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
    return;
  end if;
  if not v_admin and v_conversation.user_id <> uid then
    raise exception 'Sin permiso sobre esta conversación';
  end if;

  delete from public.support_conversations
  where id = p_conversation_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Campañas: un mensaje a todos los clientes o a uno concreto
-- ---------------------------------------------------------------------------
-- Se entrega en el ticket abierto; si el cliente no tiene ninguno se crea uno
-- nuevo. Nunca reabre un ticket cerrado.

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
    v_conversation_id := public.support_open_conversation(r.id);

    if v_conversation_id is null then
      begin
        insert into public.support_conversations (user_id)
        values (r.id)
        returning id into v_conversation_id;
      exception
        when unique_violation then
          v_conversation_id := public.support_open_conversation(r.id);
      end;
    end if;

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
-- Permisos
-- ---------------------------------------------------------------------------

revoke all on function public.support_delete_conversation(uuid)
  from public, anon;
grant execute on function public.support_delete_conversation(uuid)
  to authenticated;

commit;
