import 'package:material_ui/material_ui.dart';

import '../../services/localization_service.dart';
import '../../services/support_chat_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_input.dart';
import '../../widgets/design/cash_snack.dart';

/// Redacción de una campaña de soporte.
///
/// El mensaje se entrega en el chat de cada destinatario, con el mismo formato
/// que una respuesta normal, y queda registrado en `support_campaigns` para
/// saber a quién se envió.
class SupportCampaignScreen extends StatefulWidget {
  const SupportCampaignScreen({super.key, required this.clients});

  /// Clientes con hilo abierto, para elegir destinatario individual.
  final List<SupportConversation> clients;

  @override
  State<SupportCampaignScreen> createState() => _SupportCampaignScreenState();
}

class _SupportCampaignScreenState extends State<SupportCampaignScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();

  bool _all = true;
  String? _targetUserId;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String body = _body.text.trim();
    if (body.isEmpty) {
      CashSnack.warning(context, context.t('campaign_empty_body'));
      return;
    }
    if (!_all && _targetUserId == null) {
      CashSnack.warning(context, context.t('campaign_no_target'));
      return;
    }

    setState(() => _sending = true);
    try {
      await SupportChatService.sendCampaign(
        body: body,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        targetUserId: _all ? null : _targetUserId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('Enviar campaña de soporte: $error');
      if (!mounted) return;
      setState(() => _sending = false);
      CashSnack.error(context, context.t('campaign_error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('campaign_title')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.screenVertical,
        ),
        children: [
          Text(
            context.t('campaign_subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          CashInput(
            controller: _title,
            label: context.t('campaign_name_label'),
            hint: context.t('campaign_name_hint'),
            textCapitalization: TextCapitalization.sentences,
            maxLength: 80,
          ),
          const SizedBox(height: AppSpacing.md),
          CashInput(
            controller: _body,
            label: context.t('campaign_body_label'),
            hint: context.t('campaign_body_hint'),
            maxLines: 6,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.t('campaign_audience'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          CashCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                _AudienceTile(
                  selected: _all,
                  icon: Icons.groups_rounded,
                  title: context.t('campaign_all'),
                  subtitle: context.t('campaign_all_desc'),
                  onTap: () => setState(() => _all = true),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? AppColors.dividerDark
                      : AppColors.dividerLight,
                ),
                _AudienceTile(
                  selected: !_all,
                  icon: Icons.person_outline_rounded,
                  title: context.t('campaign_single'),
                  subtitle: context.t('campaign_single_desc'),
                  onTap: () => setState(() => _all = false),
                ),
              ],
            ),
          ),
          if (!_all) ...[
            const SizedBox(height: AppSpacing.md),
            CashCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: widget.clients.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Text(
                        context.t('campaign_no_clients'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _targetUserId,
                        hint: Text(context.t('campaign_select_client')),
                        items: widget.clients
                            .map(
                              (SupportConversation conversation) =>
                                  DropdownMenuItem<String>(
                                    value: conversation.userId,
                                    child: Text(
                                      conversation.email?.isNotEmpty == true
                                          ? '${conversation.label} · ${conversation.email}'
                                          : conversation.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                            )
                            .toList(growable: false),
                        onChanged: (String? value) =>
                            setState(() => _targetUserId = value),
                      ),
                    ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          CashButton(
            label: context.t('campaign_send'),
            icon: const Icon(Icons.campaign_outlined, size: 20),
            loading: _sending,
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}

/// Opción de destinatario con el mismo aspecto que un `RadioListTile`, sin
/// depender de APIs de radio que cambian entre versiones de Flutter.
class _AudienceTile extends StatelessWidget {
  const _AudienceTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: selected
            ? AppColors.primary
            : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiary),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(color: secondary),
      ),
      trailing: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected
            ? AppColors.primary
            : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiary),
      ),
    );
  }
}
