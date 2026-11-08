import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../services/localization_service.dart';
import '../../services/support_chat_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_input.dart';
import '../../widgets/design/cash_snack.dart';
import 'support_campaign_screen.dart';
import 'support_chat_screen.dart';
import 'support_widgets.dart';

/// Bandeja del equipo de soporte: todos los hilos de los clientes.
///
/// Solo pueden abrirla las cuentas de `support_admins`; el servidor lo vuelve a
/// comprobar en cada consulta, así que la comprobación de aquí es solo para no
/// mostrar una pantalla inútil.
class SupportInboxScreen extends StatefulWidget {
  const SupportInboxScreen({super.key});

  @override
  State<SupportInboxScreen> createState() => _SupportInboxScreenState();
}

class _SupportInboxScreenState extends State<SupportInboxScreen> {
  final TextEditingController _search = TextEditingController();

  List<SupportConversation> _conversations = const <SupportConversation>[];
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  Timer? _reloadTimer;

  bool _loading = true;
  bool _denied = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _subscription?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!SupabaseService.isSignedIn) {
      setState(() {
        _loading = false;
        _denied = true;
      });
      return;
    }

    try {
      final bool admin = await SupportChatService.isSupportAdmin(refresh: true);
      if (!mounted) return;
      if (!admin) {
        setState(() {
          _loading = false;
          _denied = true;
        });
        return;
      }

      await _load();
      _subscription?.cancel();
      _subscription = SupportChatService.watchConversations().listen(
        (_) => _scheduleReload(),
        onError: (Object error) =>
            debugPrint('Bandeja de soporte (tiempo real): $error'),
      );
    } catch (error) {
      debugPrint('Bandeja de soporte: $error');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// Agrupa varias actualizaciones seguidas en una sola recarga.
  void _scheduleReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 800), _load);
  }

  Future<void> _load() async {
    try {
      final List<SupportConversation> conversations =
          await SupportChatService.inbox();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loading = false;
        _failed = false;
      });
    } catch (error) {
      debugPrint('Cargar bandeja de soporte: $error');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  List<SupportConversation> get _filtered {
    final String query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _conversations;
    return _conversations
        .where(
          (SupportConversation conversation) =>
              conversation.label.toLowerCase().contains(query) ||
              (conversation.email ?? '').toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  Future<void> _openConversation(SupportConversation conversation) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SupportChatScreen(
          conversationId: conversation.id,
          title: conversation.label,
          adminView: true,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openCampaign() async {
    final bool? sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => SupportCampaignScreen(clients: _conversations),
      ),
    );
    if (sent != true || !mounted) return;
    CashSnack.success(context, context.t('campaign_sent'));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('support_title')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // `CashButton` ajusta el rótulo al ancho disponible, así que el texto de
      // la campaña no se sale de la cápsula en pantallas estrechas.
      floatingActionButton: _denied
          ? null
          : CashButton(
              label: context.t('admin_campaign'),
              icon: const Icon(Icons.campaign_outlined, size: 18),
              fullWidth: false,
              height: 48,
              onPressed: _openCampaign,
            ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_denied) {
      return SupportStateView(
        icon: Icons.lock_outline_rounded,
        title: context.t('admin_no_access'),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
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
    if (_conversations.isEmpty) {
      return SupportStateView(
        icon: Icons.forum_outlined,
        title: context.t('admin_inbox_empty'),
      );
    }

    final List<SupportConversation> visible = _filtered;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          AppSpacing.massive + AppSpacing.xl,
        ),
        children: [
          CashInput(
            controller: _search,
            hint: context.t('admin_inbox_search'),
            prefix: const Icon(Icons.search_rounded),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.giant),
              child: SupportStateView(
                icon: Icons.search_off_rounded,
                title: context.t('support_empty_title'),
              ),
            )
          else
            ...visible.map(
              (SupportConversation conversation) =>
                  _ConversationTile(
                    conversation: conversation,
                    onTap: () => _openConversation(conversation),
                  ),
            ),
        ],
      ),
    );
  }
}

/// Fila de la bandeja con nombre, correo, último mensaje y no leídos.
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final SupportConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final Color tertiary = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiary;
    final bool showEmail =
        conversation.fullName?.trim().isNotEmpty == true &&
        (conversation.email?.isNotEmpty ?? false);

    return CashCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: onTap,
      child: Row(
        children: [
          SupportAvatar(initials: conversation.initials),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!conversation.isOpen) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceDark3
                              : AppColors.surfaceVariantLight,
                          borderRadius: AppRadius.radiusSm,
                        ),
                        child: Text(
                          context.t('support_closed_badge'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: tertiary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                    if (conversation.lastMessageAt != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        formatSupportListDate(conversation.lastMessageAt!),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tertiary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  (conversation.lastMessagePreview?.trim().isNotEmpty ?? false)
                      ? conversation.lastMessagePreview!.trim()
                      : context.t('support_empty_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
                if (showEmail) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    conversation.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (conversation.unreadForSupport > 0) ...[
            const SizedBox(width: AppSpacing.sm),
            SupportUnreadBadge(count: conversation.unreadForSupport),
          ],
        ],
      ),
    );
  }
}
