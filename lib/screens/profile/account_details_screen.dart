import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_nav_group.dart';
import 'profile_helpers.dart';

/// Pantalla «Tu Cuenta»: información real y verificable de la cuenta.
///
/// CashRapido no dispone de registro en la nube con usuario y contraseña
/// propios: la cuenta es local a este dispositivo. Aquí sólo se muestran los
/// datos disponibles (estado de licencia, moneda y volumen de datos), sin
/// inventar correos ni estados de suscripción.
class AccountDetailsScreen extends StatelessWidget {
  const AccountDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppProvider provider = context.watch<AppProvider>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final DateTime? expiry = provider.licenseActivationDate;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('account_details_title')),
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
          CashNavGroup(
            children: [
              CashNavRow(
                icon: Icons.smartphone_rounded,
                title: context.t('account_type_label'),
                subtitle: context.t('account_type_local'),
                showChevron: false,
              ),
              CashNavRow(
                icon: Icons.workspace_premium_outlined,
                title: context.t('account_license_label'),
                subtitle: licenseLabel(context, provider.licenseType),
                showChevron: false,
              ),
              CashNavRow(
                icon: Icons.event_available_outlined,
                title: context.t('account_expires_label'),
                subtitle: expiry == null
                    ? context.t('account_no_expiry')
                    : DateFormat('dd/MM/yyyy').format(expiry),
                showChevron: false,
              ),
              CashNavRow(
                icon: Icons.payments_outlined,
                title: context.t('account_currency_label'),
                subtitle: provider.mainCurrency,
                showChevron: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          CashNavGroup(
            children: [
              CashNavRow(
                icon: Icons.receipt_long_outlined,
                title: context.t('nav_movements'),
                subtitle: '${provider.transactions.length}',
                showChevron: false,
              ),
              CashNavRow(
                icon: Icons.credit_card_outlined,
                title: context.t('cards'),
                subtitle: '${provider.cards.length}',
                showChevron: false,
              ),
              CashNavRow(
                icon: Icons.category_outlined,
                title: context.t('categories'),
                subtitle: '${provider.categories.length}',
                showChevron: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.t('account_local_note'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}
