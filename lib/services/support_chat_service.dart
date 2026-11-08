import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Mensaje del chat de soporte.
///
/// `senderRole` distingue al cliente (`user`) del equipo de soporte
/// (`support`) y de los avisos del sistema (`system`). El texto lo valida la
/// base de datos (1–4000 caracteres).
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.body,
    required this.createdAt,
    this.senderId,
    this.readByUserAt,
    this.readBySupportAt,
  });

  final String id;
  final String conversationId;
  final String? senderId;
  final String role;
  final String body;
  final DateTime createdAt;
  final DateTime? readByUserAt;
  final DateTime? readBySupportAt;

  /// `true` cuando el mensaje lo escribió el equipo de soporte (o el sistema),
  /// no el cliente dueño del hilo.
  bool get isFromSupport => role != 'user';

  factory SupportMessage.fromMap(Map<String, dynamic> map) {
    return SupportMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String?,
      role: (map['sender_role'] as String?) ?? 'user',
      body: (map['body'] as String?) ?? '',
      createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
      readByUserAt: _parseDate(map['read_by_user_at']),
      readBySupportAt: _parseDate(map['read_by_support_at']),
    );
  }
}

/// Hilo de un cliente dentro de la bandeja de soporte.
class SupportConversation {
  const SupportConversation({
    required this.id,
    required this.userId,
    required this.status,
    required this.unreadForUser,
    required this.unreadForSupport,
    required this.messageCount,
    this.email,
    this.fullName,
    this.subject,
    this.lastMessagePreview,
    this.lastMessageRole,
    this.lastMessageAt,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String status;
  final int unreadForUser;
  final int unreadForSupport;
  final int messageCount;
  final String? email;
  final String? fullName;
  final String? subject;
  final String? lastMessagePreview;
  final String? lastMessageRole;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  bool get isOpen => status == 'open';

  /// Nombre para mostrar: el de Google si existe, si no el correo.
  String get label {
    final String? name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return email ?? userId;
  }

  /// Iniciales para el avatar de la bandeja.
  String get initials {
    final String source = label.trim();
    if (source.isEmpty) return '?';
    final List<String> parts = source.split(RegExp(r'\s+'));
    final String first = parts.first;
    if (first.isEmpty) return '?';
    if (parts.length > 1 && parts[1].isNotEmpty) {
      return '${first[0]}${parts[1][0]}'.toUpperCase();
    }
    return first.substring(0, first.length >= 2 ? 2 : 1).toUpperCase();
  }

  factory SupportConversation.fromMap(Map<String, dynamic> map) {
    return SupportConversation(
      id: (map['conversation_id'] as String?) ?? (map['id'] as String? ?? ''),
      userId: (map['user_id'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'open',
      unreadForUser: _asInt(map['unread_for_user']),
      unreadForSupport: _asInt(map['unread_for_support']),
      messageCount: _asInt(map['message_count']),
      email: map['email'] as String?,
      fullName: map['full_name'] as String?,
      subject: map['subject'] as String?,
      lastMessagePreview: map['last_message_preview'] as String?,
      lastMessageRole: map['last_message_role'] as String?,
      lastMessageAt: _parseDate(map['last_message_at']),
      createdAt: _parseDate(map['created_at']),
    );
  }
}

/// Acceso al chat de soporte de Supabase.
///
/// El cliente solo puede leer y escribir en su propio hilo: lo impone RLS en la
/// base de datos, no la app. El equipo de soporte (los correos de
/// `support_admins`) ve todos los hilos y puede enviar campañas a todos los
/// perfiles o a uno concreto.
///
/// Todas las escrituras pasan por RPC para que los contadores de no leídos y el
/// resumen del hilo se mantengan coherentes.
abstract final class SupportChatService {
  static bool? _adminCache;
  static String? _adminCacheUserId;

  /// `true` cuando hay una sesión de Supabase activa.
  static bool get isAvailable => SupabaseService.isSignedIn;

  /// `true` si la cuenta conectada es del equipo de soporte.
  ///
  /// El resultado se memoriza por usuario para no repetir la llamada en cada
  /// reconstrucción. Usa [refresh] para volver a preguntar al servidor.
  static Future<bool> isSupportAdmin({bool refresh = false}) async {
    final User? user = SupabaseService.currentUser;
    if (user == null) return false;
    if (!refresh &&
        _adminCache != null &&
        _adminCacheUserId == user.id) {
      return _adminCache!;
    }

    final dynamic value = await SupabaseService.client.rpc('support_is_admin');
    _adminCache = value == true;
    _adminCacheUserId = user.id;
    return _adminCache!;
  }

  /// Devuelve el id del hilo propio y lo crea si todavía no existe.
  static Future<String> ensureConversation() async {
    final dynamic id = await SupabaseService.client.rpc(
      'support_ensure_conversation',
    );
    return id as String;
  }

  /// Ticket más reciente de la cuenta conectada, esté abierto o cerrado.
  ///
  /// Se filtra por usuario a propósito: el equipo de soporte puede leer todos
  /// los hilos, así que sin este filtro su propio chat abriría el de otro.
  static Future<String?> latestConversationId() async {
    final User? user = SupabaseService.currentUser;
    if (user == null) return null;

    final List<Map<String, dynamic>> rows = await SupabaseService.client
        .from('support_conversations')
        .select('id')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['id'] as String?;
  }

  /// Historial de tickets de la cuenta conectada, del más reciente al más
  /// antiguo (abiertos y cerrados).
  static Future<List<SupportConversation>> myConversations() async {
    final User? user = SupabaseService.currentUser;
    if (user == null) return const <SupportConversation>[];

    final List<Map<String, dynamic>> rows = await SupabaseService.client
        .from('support_conversations')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return rows.map(SupportConversation.fromMap).toList(growable: false);
  }

  /// Mensajes de [conversationId], del más antiguo al más reciente.
  static Future<List<SupportMessage>> fetchMessages(
    String conversationId,
  ) async {
    final List<Map<String, dynamic>> rows = await SupabaseService.client
        .from('support_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return _sortedMessages(rows.map(SupportMessage.fromMap));
  }

  /// Cambios del hilo en tiempo real (RLS decide qué llega a cada cuenta).
  static Stream<List<SupportMessage>> watchMessages(String conversationId) {
    return SupabaseService.client
        .from('support_messages')
        .stream(primaryKey: <String>['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map(
          (List<Map<String, dynamic>> rows) =>
              _sortedMessages(rows.map(SupportMessage.fromMap)),
        );
  }

  /// Cambios en los hilos (la bandeja del soporte los usa para refrescarse).
  static Stream<List<Map<String, dynamic>>> watchConversations() {
    return SupabaseService.client
        .from('support_conversations')
        .stream(primaryKey: <String>['id']);
  }

  /// Envía [body]. Si [conversationId] es nulo, el servidor resuelve el hilo de
  /// quien llama; soporte debe indicar siempre el hilo del cliente.
  static Future<void> sendMessage(
    String body, {
    String? conversationId,
  }) async {
    await SupabaseService.client.rpc(
      'support_send_message',
      params: <String, dynamic>{
        'p_body': body,
        // `null` deja que el servidor resuelva el hilo de quien llama.
        'p_conversation_id': conversationId,
      },
    );
  }

  /// Marca como leídos los mensajes pendientes del hilo.
  static Future<void> markRead({String? conversationId}) async {
    await SupabaseService.client.rpc(
      'support_mark_read',
      params: <String, dynamic>{
        'p_conversation_id': conversationId,
      },
    );
  }

  /// Cierra o reabre un ticket. Solo el equipo de soporte puede hacerlo: el
  /// servidor rechaza la llamada si la cuenta no es de soporte.
  static Future<void> setStatus(
    String conversationId, {
    required bool closed,
  }) async {
    await SupabaseService.client.rpc(
      'support_set_status',
      params: <String, dynamic>{
        'p_conversation_id': conversationId,
        'p_closed': closed,
      },
    );
  }

  /// Elimina el ticket y todos sus mensajes. El cliente solo puede borrar el
  /// suyo; el soporte, cualquiera.
  static Future<void> deleteConversation(String conversationId) async {
    await SupabaseService.client.rpc(
      'support_delete_conversation',
      params: <String, dynamic>{'p_conversation_id': conversationId},
    );
  }

  /// Estado del ticket (`open`/`closed`), o `null` si ya no existe.
  static Future<String?> conversationStatus(String conversationId) async {
    final Map<String, dynamic>? row = await SupabaseService.client
        .from('support_conversations')
        .select('status')
        .eq('id', conversationId)
        .maybeSingle();
    return row?['status'] as String?;
  }

  /// Estado del ticket en tiempo real (se cierra o se reabre sin recargar).
  static Stream<String?> watchStatus(String conversationId) {
    return SupabaseService.client
        .from('support_conversations')
        .stream(primaryKey: <String>['id'])
        .eq('id', conversationId)
        .map(
          (List<Map<String, dynamic>> rows) => rows.isEmpty
              ? null
              : rows.first['status'] as String?,
        );
  }

  /// Bandeja completa del soporte, ordenada por actividad.
  static Future<List<SupportConversation>> inbox() async {
    final dynamic data = await SupabaseService.client.rpc('support_inbox');
    if (data is! List) return const <SupportConversation>[];
    return data
        .map(
          (dynamic row) => SupportConversation.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  /// Contadores de no leídos de los hilos visibles para la cuenta.
  ///
  /// RLS devuelve solo el hilo propio de un cliente; el equipo de soporte
  /// recibe todos. Sirve para el contador del botón de soporte del inicio.
  static Future<List<Map<String, dynamic>>> conversationCounters() async {
    // Los tickets cerrados no cuentan como pendientes.
    return SupabaseService.client
        .from('support_conversations')
        .select('unread_for_user, unread_for_support')
        .eq('status', 'open');
  }

  /// Suma los pendientes del lado que mira: el cliente o todo el equipo.
  static int unreadFromRows(
    List<Map<String, dynamic>> rows, {
    required bool admin,
  }) {
    return rows.fold<int>(
      0,
      (int total, Map<String, dynamic> row) =>
          total +
          _asInt(row[admin ? 'unread_for_support' : 'unread_for_user']),
    );
  }

  /// Envía una campaña a todos los perfiles ([targetUserId] nulo) o a uno solo.
  static Future<String> sendCampaign({
    required String body,
    String? title,
    String? targetUserId,
  }) async {
    final dynamic id = await SupabaseService.client.rpc(
      'support_send_campaign',
      params: <String, dynamic>{
        'p_body': body,
        'p_title': title,
        'p_target_user_id': targetUserId,
      },
    );
    return id as String;
  }
}

/// Copia ordenada del mensaje más antiguo al más reciente.
///
/// No se delega en el orden de la consulta ni del flujo en tiempo real: si
/// llegara invertido, el chat mostraría las respuestas nuevas por encima.
List<SupportMessage> _sortedMessages(Iterable<SupportMessage> messages) {
  final List<SupportMessage> sorted = messages.toList();
  sorted.sort((SupportMessage a, SupportMessage b) {
    final int byDate = a.createdAt.compareTo(b.createdAt);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  });
  return List<SupportMessage>.unmodifiable(sorted);
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
