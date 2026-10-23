import 'package:material_ui/material_ui.dart';

import '../../services/localization_service.dart';
import '../../services/official_links.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_input.dart';
import 'profile_helpers.dart';

/// Pantalla «Canjear código promocional».
///
/// La arquitectura de licencias de CashRapido funciona con compras en tienda
/// (Apklis / Art-Pay) y planes aleatorios de racha; no existe todavía un
/// servicio de validación de códigos promocionales. Por eso esta pantalla no
/// simula un canje correcto: informa con claridad del estado real y ofrece
/// contactar con soporte. Cuando el servicio exista, sólo hay que conectar aquí
/// su validación.
class PromoCodeScreen extends StatefulWidget {
  const PromoCodeScreen({super.key});

  @override
  State<PromoCodeScreen> createState() => _PromoCodeScreenState();
}

class _PromoCodeScreenState extends State<PromoCodeScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final String code = _controller.text.trim();
    if (code.isEmpty) {
      _showInfo(context.t('promo_code_empty'));
      return;
    }

    // No existe un servicio de canje conectado: se informa del estado real en
    // lugar de aplicar un código ficticio.
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _busy = false);

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.radiusXxl,
        ),
        icon: const Icon(Icons.info_outline_rounded, color: AppColors.info),
        title: Text(context.t('promo_not_available_title')),
        content: Text(context.t('promo_not_available_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('close')),
          ),
          CashButton(
            label: context.t('help_contact'),
            fullWidth: false,
            height: 44,
            onPressed: () {
              Navigator.pop(ctx);
              _contactSupport();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _contactSupport() {
    return openOfficialEmail(
      context,
      to: OfficialLinks.supportEmail,
      subject: context.t('promo_support_subject'),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('promo_redeem_title')),
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
          Icon(
            Icons.redeem_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.t('promo_redeem_title'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.t('promo_redeem_intro'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          CashInput(
            controller: _controller,
            label: context.t('promo_code_label'),
            hint: context.t('promo_code_hint'),
            prefix: const Icon(Icons.confirmation_number_outlined),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: AppSpacing.lg),
          CashButton(
            label: context.t('promo_redeem_action'),
            loading: _busy,
            onPressed: _busy ? null : _redeem,
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceDark2
                  : AppColors.warningLight,
              borderRadius: AppRadius.radiusMd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.t('promo_dependency_note'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: secondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
