import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../services/localization_service.dart';
import '../../services/support_chat_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_dialog.dart';
import '../../widgets/design/cash_snack.dart';
import '../profile/profile_helpers.dart';
import 'support_inbox_screen.dart';
import 'support_widgets.dart';

/// Chat con el equipo de soporte.
///
/// El cliente ve únicamente su hilo: la base de datos aplica RLS por
/// `auth.uid()`, así que aunque la app pidiera otro id no recibiría nada. El
/// equipo de soporte reutiliza esta misma pantalla con [adminView] y
/// [conversationId] para responder a un cliente concreto.
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({
    super.key,
    this.conversationId,
    this.title,
    this.adminView = false,
  });

  /// Hilo a abrir. Si es nulo, se resuelve el hilo propio del cliente.
  final String? conversationId;

  /// Título de la barra (por ejemplo, el correo del cliente en la vista de
  /// soporte). Por defecto, «Soporte».
  final String? title;

  /// `true` cuando la abre el equipo de soporte para responder a un cliente.
  final bool adminView;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _input = TextEditingController();
  final List<SupportMessage> _messages = <SupportMessage>[];

  StreamSubscription<List<SupportMessage>>? _subscription;
  StreamSubscription<String?>? _statusSubscription;

  String? _conversationId;
  bool _loading = true;
  bool _sending = false;
  bool _failed = false;
  bool _admin = false;
  bool _closed = false;
  bool _acting = false;
  DateTime? _lastMarkRead;

  @override
  void initState() {
    super.initState();
    _admin = widget.adminView;
    _start();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _statusSubscription?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!SupabaseService.isSignedIn) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      if (!_admin) {
        _admin = await SupportChatService.isSupportAdmin();
      }

      // El cliente abre su ticket más reciente, aunque esté cerrado: el
      // historial no desaparece. Solo se crea otro al pedirlo.
      final String? id =
          widget.conversationId ??
          await SupportChatService.latestConversationId();
      if (!mounted) return;
      if (id == null) {
        setState(() {
          _loading = false;
          _failed = false;
          _closed = false;
        });
        return;
      }
      await _loadConversation(id);
    } catch (error) {
      debugPrint('Chat de soporte: $error');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// Muestra [id] y se suscribe a su estado y a sus mensajes.
  Future<void> _loadConversation(String id) async {
    String? status;
    try {
      status = await SupportChatService.conversationStatus(id);
    } catch (error) {
      debugPrint('Estado del ticket de soporte: $error');
    }
    if (!mounted) return;

    setState(() {
      _conversationId = id;
      _closed = status == 'closed';
      _failed = false;
      _loading = true;
    });
    _watchStatus(id);

    await _reload();
    if (!mounted) return;

    _subscription?.cancel();
    _subscription = SupportChatService.watchMessages(id).listen(
      _onMessages,
      onError: (Object error) =>
          debugPrint('Chat de soporte (tiempo real): $error'),
    );
  }

  void _onMessages(List<SupportMessage> messages) {
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(messages);
      _loading = false;
      _failed = false;
    });
    _markReadIfNeeded();
  }

  Future<void> _reload() async {
    final String? id = _conversationId;
    if (id == null) return;

    final List<SupportMessage> messages =
        await SupportChatService.fetchMessages(id);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(messages);
      _loading = false;
      _failed = false;
    });
    _markReadIfNeeded();
  }

  /// Pone a cero el contador del lado que está mirando el hilo.
  Future<void> _markReadIfNeeded() async {
    final String? id = _conversationId;
    if (id == null) return;

    final bool hasUnread = _messages.any(
      (SupportMessage message) => _admin
          ? message.role == 'user' && message.readBySupportAt == null
          : message.isFromSupport && message.readByUserAt == null,
    );
    if (!hasUnread) return;

    // Evita repetir la RPC en cada evento del flujo mientras la anterior
    // todavía se está aplicando.
    final DateTime now = DateTime.now();
    if (_lastMarkRead != null &&
        now.difference(_lastMarkRead!).inSeconds < 3) {
      return;
    }
    _lastMarkRead = now;

    try {
      await SupportChatService.markRead(conversationId: id);
    } catch (error) {
      debugPrint('Marcar leído en soporte: $error');
    }
  }

  Future<void> _send() async {
    final String text = _input.text.trim();
    if (text.isEmpty || _sending || _closed) return;

    setState(() => _sending = true);
    try {
      // Primer mensaje sin ticket todavía: se crea al enviar.
      final String id =
          _conversationId ?? await SupportChatService.ensureConversation();
      if (!mounted) return;
      if (_conversationId == null) {
        await _loadConversation(id);
        if (!mounted) return;
      }
      await SupportChatService.sendMessage(text, conversationId: id);
      _input.clear();
      await _reload();
    } catch (error) {
      debugPrint('Enviar mensaje de soporte: $error');
      if (mounted) CashSnack.error(context, context.t('support_send_error'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Mantiene el aviso de ticket cerrado al día sin recargar la pantalla.
  void _watchStatus(String id) {
    _statusSubscription?.cancel();
    _statusSubscription = SupportChatService.watchStatus(id).listen(
      (String? status) {
        if (!mounted) return;
        final bool closed = status == 'closed';
        if (closed != _closed) setState(() => _closed = closed);
      },
      onError: (Object error) => debugPrint('Estado del ticket: $error'),
    );
  }

  /// Cierra o reabre el ticket. Solo se ofrece al equipo de soporte; el
  /// servidor vuelve a comprobarlo.
  Future<void> _toggleClosed() async {
    final String? id = _conversationId;
    if (id == null || _acting) return;

    final bool closed = !_closed;
    setState(() => _acting = true);
    try {
      await SupportChatService.setStatus(id, closed: closed);
      if (!mounted) return;
      setState(() => _closed = closed);
      CashSnack.success(
        context,
        context.t(closed ? 'support_closed_done' : 'support_reopened_done'),
      );
    } catch (error) {
      debugPrint('Estado del ticket de soporte: $error');
      if (mounted) CashSnack.error(context, context.t('support_action_error'));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  /// Borra el ticket entero. Sirve tanto al cliente (el suyo) como al soporte
  /// (cualquiera); al terminar se sale de la conversación.
  Future<void> _deleteConversation() async {
    final String? id = _conversationId;
    if (id == null || _acting) return;

    final bool? confirmed = await showCashConfirmDialog(
      context,
      title: context.t('support_delete_title'),
      message: context.t('support_delete_desc'),
      confirmLabel: context.t('delete'),
      cancelLabel: context.t('cancel'),
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _acting = true);
    try {
      await SupportChatService.deleteConversation(id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      debugPrint('Eliminar conversación de soporte: $error');
      if (mounted) CashSnack.error(context, context.t('support_action_error'));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  /// Abre un ticket nuevo cuando el anterior quedó cerrado.
  Future<void> _startNewConversation() async {
    if (_acting) return;

    setState(() {
      _acting = true;
      _loading = true;
      _messages.clear();
      _closed = false;
    });
    try {
      final String id = await SupportChatService.ensureConversation();
      if (!mounted) return;
      await _loadConversation(id);
    } catch (error) {
      debugPrint('Nueva conversación de soporte: $error');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
        CashSnack.error(context, context.t('support_action_error'));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  /// Historial de tickets del cliente; tocar uno lo vuelve a mostrar.
  Future<void> _openHistory() async {
    if (_acting) return;

    List<SupportConversation> conversations;
    try {
      conversations = await SupportChatService.myConversations();
    } catch (error) {
      debugPrint('Historial de soporte: $error');
      if (mounted) CashSnack.error(context, context.t('support_action_error'));
      return;
    }
    if (!mounted || conversations.isEmpty) return;

    final String? selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) => _HistorySheet(
        conversations: conversations,
        activeId: _conversationId,
      ),
    );
    if (selected == null || !mounted) return;

    try {
      await _loadConversation(selected);
    } catch (error) {
      debugPrint('Abrir ticket del historial: $error');
      if (mounted) {
        setState(() => _loading = false);
        CashSnack.error(context, context.t('support_action_error'));
      }
    }
  }

  Future<void> _connect() async {
    final provider = context.read<AppProvider>();
    if (!provider.canSyncDrive) {
      showFeatureLockedDialog(context);
      return;
    }
    final bool connected = await connectGoogleAccount(context);
    if (!connected || !mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title ?? context.t('support_title')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_admin && !widget.adminView)
            IconButton(
              tooltip: context.t('admin_inbox_title'),
              icon: const Icon(Icons.forum_outlined),
              onPressed: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SupportInboxScreen(),
                  ),
                );
              },
            ),
          if (SupabaseService.isSignedIn && !_admin)
            IconButton(
              tooltip: context.t('support_history'),
              icon: const Icon(Icons.history_rounded),
              onPressed: _openHistory,
            ),
          if (SupabaseService.isSignedIn)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (String value) {
                if (value == 'status') {
                  _toggleClosed();
                } else if (value == 'delete') {
                  _deleteConversation();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (_admin)
                  PopupMenuItem<String>(
                    value: 'status',
                    child: Row(
                      children: [
                        Icon(
                          _closed
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          context.t(
                            _closed
                                ? 'support_reopen_ticket'
                                : 'support_close_ticket',
                          ),
                        ),
                      ],
                    ),
                  ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(context.t('support_delete_conversation')),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SupabaseService.isSignedIn
          ? _buildBody(context)
          : _buildLoginPrompt(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        if (!_admin)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
            ),
            child: Text(
              context.t('support_subtitle'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        Expanded(child: _buildConversation(context)),
        _closed ? _buildClosedNotice(context) : _buildComposer(context),
      ],
    );
  }

  Widget _buildConversation(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed && _messages.isEmpty) {
      return SupportStateView(
        icon: Icons.cloud_off_rounded,
        title: context.t('support_load_error'),
        action: CashButton(
          label: context.t('support_retry'),
          fullWidth: false,
          height: 44,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          onPressed: () {
            setState(() {
              _loading = true;
              _failed = false;
            });
            _start();
          },
        ),
      );
    }
    if (_messages.isEmpty) {
      return SupportStateView(
        icon: Icons.forum_outlined,
        title: context.t('support_empty_title'),
        message: context.t('support_empty_desc'),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        reverse: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        itemCount: _messages.length,
        itemBuilder: (BuildContext context, int index) {
          final SupportMessage message =
              _messages[_messages.length - 1 - index];
          final bool mine = _admin
              ? message.isFromSupport
              : !message.isFromSupport;
          return _SupportBubble(message: message, mine: mine);
        },
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: context.t('support_input_hint'),
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.surfaceDark2
                      : AppColors.surfaceVariantLight,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.radiusLg,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.radiusLg,
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.radiusLg,
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _input,
              builder: (BuildContext context, TextEditingValue value, _) {
                final bool canSend =
                    value.text.trim().isNotEmpty && !_sending && !_closed;
                return SizedBox(
                  width: 48,
                  height: 48,
                  child: Material(
                    color: canSend
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.surfaceDark3
                              : AppColors.surfaceVariantLight),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: canSend ? _send : null,
                      child: Center(
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                size: 20,
                                color: canSend
                                    ? Colors.white
                                    : (isDark
                                          ? AppColors.textTertiaryDark
                                          : AppColors.textTertiary),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Sustituye al campo de escritura cuando el ticket está cerrado.
  ///
  /// El cliente solo puede empezar otro ticket; el equipo de soporte puede
  /// reabrir este.
  Widget _buildClosedNotice(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, size: 18, color: secondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.t('support_closed_desc'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            CashButton(
              label: context.t(
                _admin ? 'support_reopen_ticket' : 'support_new_conversation',
              ),
              icon: Icon(
                _admin ? Icons.lock_open_rounded : Icons.add_comment_outlined,
                size: 18,
              ),
              height: 46,
              loading: _acting,
              onPressed: _admin ? _toggleClosed : _startNewConversation,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: CashCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.support_agent_rounded,
                size: 44,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.t('support_need_login_title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.t('support_need_login_desc'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              CashButton(
                label: context.t('support_connect'),
                icon: const Icon(Icons.login_rounded, size: 20),
                onPressed: _connect,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Historial de tickets del cliente (abiertos y cerrados).
class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.conversations, required this.activeId});

  final List<SupportConversation> conversations;
  final String? activeId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('support_history'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: conversations.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (BuildContext context, int index) {
                  final SupportConversation conversation =
                      conversations[index];
                  final String preview =
                      conversation.lastMessagePreview?.trim() ?? '';
                  final DateTime? date =
                      conversation.lastMessageAt ?? conversation.createdAt;

                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusLg,
                    ),
                    selected: conversation.id == activeId,
                    leading: Icon(
                      conversation.isOpen
                          ? Icons.chat_bubble_outline_rounded
                          : Icons.lock_outline_rounded,
                      color: conversation.isOpen
                          ? AppColors.primary
                          : secondary,
                    ),
                    title: Text(
                      preview.isNotEmpty
                          ? preview
                          : context.t('support_empty_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      <String>[
                        context.t(
                          conversation.isOpen
                              ? 'support_open_badge'
                              : 'support_closed_badge',
                        ),
                        if (date != null) formatSupportListDate(date),
                      ].join(' · '),
                    ),
                    onTap: () => Navigator.pop(context, conversation.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Burbuja de un mensaje del hilo.
class _SupportBubble extends StatelessWidget {
  const _SupportBubble({required this.message, required this.mine});

  final SupportMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color background = mine
        ? AppColors.primary
        : (isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight);
    final Color foreground = mine
        ? Colors.white
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);
    final Color meta = mine
        ? Colors.white70
        : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiary);

    final BorderRadius radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.lg),
      topRight: const Radius.circular(AppRadius.lg),
      bottomLeft: Radius.circular(mine ? AppRadius.lg : AppRadius.xs),
      bottomRight: Radius.circular(mine ? AppRadius.xs : AppRadius.lg),
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: mine ? AppSpacing.giant : 0,
          right: mine ? 0 : AppSpacing.giant,
          bottom: AppSpacing.sm,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: mine
              ? null
              : Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foreground,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              formatSupportTime(message.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: meta,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
