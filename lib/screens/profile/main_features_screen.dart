import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/add_transaction_modal.dart';
import '../../widgets/design/cash_nav_group.dart';
import '../../widgets/design/cash_section.dart';
import '../../widgets/design/cash_snack.dart';
import '../add_category_screen.dart';
import '../ai_chat_screen.dart';
import '../business/business_gatekeeper.dart';
import '../card_scanner_screen.dart';
import '../licenses_screen.dart';
import '../loans/loans_gatekeeper.dart';
import '../main_screen.dart';
import '../money_counter_screen.dart';
import '../notification_settings_screen.dart';
import '../recurring_transactions_screen.dart';
import '../streak_calendar_screen.dart';
import '../transfermovil_screen.dart';
import '../wallet_screen.dart';
import 'google_drive_screen.dart';
import 'my_account_screen.dart';
import 'profile_helpers.dart';

/// Apartado «Funciones Principales»: catálogo real de la aplicación.
///
/// Cada entrada lleva a la pantalla o acción ya existente; no incluye funciones
/// que no estén implementadas. Las tres pestañas base (Inicio, Movimientos y
/// Estadísticas) vuelven a la barra inferior mediante [mainTabRequest].
class MainFeaturesScreen extends StatelessWidget {
  const MainFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppProvider provider = context.watch<AppProvider>();
    final bool isMobile =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('features_title')),
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
            context.t('features_intro'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Finanzas personales ──────────────────────────────────────────
          CashSection(
            title: context.t('features_group_personal'),
            child: CashNavGroup(
              children: [
                CashNavRow(
                  icon: Icons.home_outlined,
                  title: context.t('feat_home'),
                  subtitle: context.t('feat_home_desc'),
                  onTap: () => _goToTab(context, MainTab.home),
                ),
                CashNavRow(
                  icon: Icons.receipt_long_outlined,
                  title: context.t('feat_movements'),
                  subtitle: context.t('feat_movements_desc'),
                  onTap: () => _goToTab(context, MainTab.movements),
                ),
                CashNavRow(
                  icon: Icons.south_west_rounded,
                  title: context.t('feat_add_income'),
                  subtitle: context.t('feat_add_income_desc'),
                  onTap: () => _openTransaction(context, expense: false),
                ),
                CashNavRow(
                  icon: Icons.north_east_rounded,
                  title: context.t('feat_add_expense'),
                  subtitle: context.t('feat_add_expense_desc'),
                  onTap: () => _openTransaction(context, expense: true),
                ),
                CashNavRow(
                  icon: Icons.category_outlined,
                  title: context.t('feat_categories'),
                  subtitle: context.t('feat_categories_desc'),
                  onTap: () => _openCategories(context, provider),
                ),
                CashNavRow(
                  icon: Icons.account_balance_wallet_outlined,
                  title: context.t('feat_accounts'),
                  subtitle: context.t('feat_accounts_desc'),
                  onTap: () =>
                      pushProfileScreen(context, const WalletScreen()),
                ),
                CashNavRow(
                  icon: Icons.autorenew_rounded,
                  title: context.t('feat_recurring'),
                  subtitle: context.t('feat_recurring_desc'),
                  onTap: () => pushProfileScreen(
                    context,
                    const RecurringTransactionsScreen(),
                  ),
                ),
                CashNavRow(
                  icon: Icons.insights_rounded,
                  title: context.t('feat_stats'),
                  subtitle: context.t('feat_stats_desc'),
                  onTap: () => _goToTab(context, MainTab.stats),
                ),
                if (provider.isCuba)
                  CashNavRow(
                    icon: Icons.smartphone_rounded,
                    title: context.t('feat_transfermovil'),
                    subtitle: context.t('feat_transfermovil_desc'),
                    onTap: () => pushProfileScreen(
                      context,
                      const TransferMovilScreen(),
                    ),
                  ),
                CashNavRow(
                  icon: Icons.calculate_outlined,
                  title: context.t('feat_money_counter'),
                  subtitle: context.t('feat_money_counter_desc'),
                  onTap: () => pushProfileScreen(
                    context,
                    MoneyCounterScreen(
                      currencySymbol: _currencySymbol(provider),
                    ),
                  ),
                ),
                CashNavRow(
                  icon: Icons.local_fire_department_outlined,
                  title: context.t('feat_streak'),
                  subtitle: context.t('feat_streak_desc'),
                  onTap: () =>
                      pushProfileScreen(context, const StreakCalendarScreen()),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Herramientas ─────────────────────────────────────────────────
          CashSection(
            title: context.t('features_group_tools'),
            child: CashNavGroup(
              children: [
                CashNavRow(
                  icon: Icons.auto_awesome_rounded,
                  title: context.t('feat_ai'),
                  subtitle: context.t('feat_ai_desc'),
                  onTap: () => _openAi(context, provider),
                ),
                if (isMobile)
                  CashNavRow(
                    icon: Icons.qr_code_scanner_rounded,
                    title: context.t('feat_scanner'),
                    subtitle: context.t('feat_scanner_desc'),
                    onTap: () => pushProfileScreen(
                      context,
                      const CardScannerScreen(),
                    ),
                  ),
                CashNavRow(
                  icon: Icons.notifications_outlined,
                  title: context.t('feat_notifications'),
                  subtitle: context.t('feat_notifications_desc'),
                  onTap: () => pushProfileScreen(
                    context,
                    const NotificationSettingsScreen(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Módulos avanzados ────────────────────────────────────────────
          CashSection(
            title: context.t('features_group_modules'),
            child: CashNavGroup(
              children: [
                CashNavRow(
                  icon: Icons.storefront_outlined,
                  title: context.t('feat_business'),
                  subtitle: context.t('feat_business_desc'),
                  onTap: () =>
                      pushProfileScreen(context, const BusinessGatekeeper()),
                ),
                CashNavRow(
                  icon: Icons.real_estate_agent_outlined,
                  title: context.t('feat_loans'),
                  subtitle: context.t('feat_loans_desc'),
                  onTap: () =>
                      pushProfileScreen(context, const LoansGatekeeper()),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Datos y cuenta ───────────────────────────────────────────────
          CashSection(
            title: context.t('features_group_data'),
            child: CashNavGroup(
              children: [
                CashNavRow(
                  icon: Icons.ios_share_rounded,
                  title: context.t('feat_export_import'),
                  subtitle: context.t('feat_export_import_desc'),
                  onTap: () =>
                      pushProfileScreen(context, const MyAccountScreen()),
                ),
                CashNavRow(
                  icon: Icons.cloud_outlined,
                  title: context.t('feat_backup'),
                  subtitle: context.t('feat_backup_desc'),
                  onTap: () =>
                      pushProfileScreen(context, const GoogleDriveScreen()),
                ),
                CashNavRow(
                  icon: Icons.workspace_premium_outlined,
                  title: context.t('feat_licenses'),
                  subtitle: context.t('feat_licenses_desc'),
                  onTap: () =>
                      pushProfileScreen(context, const LicensesScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Vuelve a la pestaña [tab] de la barra inferior.
  void _goToTab(BuildContext context, MainTab tab) {
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    mainTabRequest.value = tab;
  }

  void _openTransaction(BuildContext context, {required bool expense}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionModal(startAsExpense: expense),
    );
  }

  void _openAi(BuildContext context, AppProvider provider) {
    if (!provider.canUseAI) {
      showFeatureLockedDialog(context);
      return;
    }
    if (!provider.aiChatEnabled) {
      CashSnack.info(context, context.t('feat_ai_disabled_hint'));
      return;
    }
    pushProfileScreen(context, const AIChatScreen());
  }

  /// Abre el alta de categorías respetando la licencia.
  ///
  /// Crear categorías está reservado a Pro o superior
  /// ([AppProvider.canCreateCategory]); sin esta comprobación este catálogo se
  /// saltaba la restricción que sí aplican el formulario de movimientos y las
  /// estadísticas. Editar una categoría existente sigue permitido.
  void _openCategories(BuildContext context, AppProvider provider) {
    if (!provider.canCreateCategory) {
      showFeatureLockedDialog(context);
      return;
    }
    pushProfileScreen(context, const AddCategoryScreen());
  }

  String _currencySymbol(AppProvider provider) {
    return provider.availableCurrencies
        .firstWhere(
          (Currency c) => c.code == provider.mainCurrency,
          orElse: () =>
              Currency(code: provider.mainCurrency, symbol: '\$', name: ''),
        )
        .symbol;
  }
}
