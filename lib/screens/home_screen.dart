import 'dart:io' show Platform;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../utils/icon_constants.dart';
import '../utils/number_format_utils.dart';
import '../utils/tour_keys.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/design/cash_account_avatar.dart';
import '../widgets/design/cash_button.dart';
import '../widgets/design/cash_card.dart';
import '../widgets/design/cash_chip.dart';
import '../widgets/design/cash_dialog.dart';
import '../widgets/design/cash_empty_state.dart';
import '../widgets/design/cash_icon_button.dart';
import '../widgets/design/cash_quick_action.dart';
import '../widgets/design/cash_section.dart';
import '../widgets/design/cash_snack.dart';
import '../widgets/design/cash_stat_card.dart';
import '../widgets/design/cash_transaction_tile.dart';
import 'all_transactions_screen.dart';
import 'add_card_screen.dart';
import 'business/business_gatekeeper.dart';
import 'card_scanner_screen.dart';
import 'info_screens.dart';
import 'licenses_screen.dart';
import 'loans/loans_gatekeeper.dart';
import 'notifications_screen.dart';
import 'profile/google_drive_screen.dart';
import 'recurring_transactions_screen.dart';
import 'streak_calendar_screen.dart';
import 'transfermovil_screen.dart';
import 'wallet_screen.dart';

/// Pantalla principal de CashRapido.
///
/// Es la referencia visual del producto. La jerarquía es:
/// saludo -> balance -> acciones -> resumen del mes -> movimientos.
///
/// Esta capa es puramente visual: no calcula saldos ni dispara transacciones,
/// solo consume lo que `AppProvider` ya expone.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Cuenta seleccionada. `null` equivale a la primera disponible.
  String? _selectedCardId;

  /// Cuántos movimientos se muestran en la sección de recientes.
  static const int _recentTransactionsCount = 5;

  /// Ancho máximo del selector de cuenta dentro de la tarjeta de balance.
  static const double _cardSelectorMaxWidth = 190;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Ensure valid selection
        if (_selectedCardId != null &&
            !provider.cards.any((c) => c.id == _selectedCardId)) {
          _selectedCardId = null;
        }

        if (_selectedCardId == null && provider.cards.isNotEmpty) {
          _selectedCardId = provider.cards.first.id;
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            // La barra de navegación principal ya reserva el espacio inferior.
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.screenVertical,
                AppSpacing.screenHorizontal,
                AppSpacing.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, provider),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildBalanceCard(context, provider),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildQuickActions(context, provider),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildFinancialSummary(context, provider),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildTransactionsList(context, provider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, AppProvider provider) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra superior: la cuenta (Google Drive) queda lo primero a la
        // izquierda; a la derecha se mantienen racha y notificaciones.
        Row(
          children: [
            Expanded(child: _buildAccountChip(context, provider)),
            const SizedBox(width: AppSpacing.sm),
            CashChip(
              label: '${provider.streakDays}',
              icon: Icons.local_fire_department_rounded,
              color: AppColors.orange,
              selected: provider.streakDays > 0,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StreakCalendarScreen()),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _NotificationsButton(
              count: provider.unreadNotificationsCount,
              tooltip: context.t('tooltip_notifications'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          _greeting(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          context.t('daily_summary'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
        ),
      ],
    );
  }

  /// Cuenta de Google Drive en la barra superior de Inicio.
  ///
  /// Es lo primero a la izquierda: muestra la foto real y el nombre cuando hay
  /// sesión iniciada. Si no la hay, muestra «Invitado» y, al pulsar, permite
  /// conectar la cuenta desde aquí mismo.
  Widget _buildAccountChip(BuildContext context, AppProvider provider) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final user = provider.currentUser;
    final bool connected = user != null;
    final String displayName = user?.displayName?.trim() ?? '';
    final String? email = user?.email;
    final String accountName = displayName.isNotEmpty
        ? displayName
        : (email ?? context.t('user_default'));

    final String label = connected ? accountName : context.t('home_guest');
    final String subtitle = connected
        ? context.t('profile_drive_title')
        : context.t('profile_drive_connect');

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: AppRadius.radiusXl,
        onTap: () => _onAccountTap(context, provider),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              CashAccountAvatar(
                imageUrl: user?.photoUrl,
                name: connected
                    ? (displayName.isNotEmpty ? displayName : email)
                    : null,
                size: 42,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAccountTap(BuildContext context, AppProvider provider) async {
    // Con sesión: abre la gestión de la copia en Drive.
    if (provider.currentUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GoogleDriveScreen()),
      );
      return;
    }

    // Sin sesión: primero comprueba que la función esté disponible.
    if (!provider.canSyncDrive) {
      _showLockedFeatureDialog(context);
      return;
    }

    try {
      await provider.signInToGoogle();
      if (!context.mounted) return;
      if (provider.currentUser != null) {
        CashSnack.success(context, context.t('profile_drive_connected_msg'));
      }
    } catch (_) {
      if (context.mounted) {
        CashSnack.error(context, context.t('profile_drive_error'));
      }
    }
  }

  String _greeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return context.t('greeting_morning');
    if (hour < 20) return context.t('greeting_afternoon');
    return context.t('greeting_night');
  }

  // ---------------------------------------------------------------------------
  // BALANCE
  // ---------------------------------------------------------------------------

  AccountCard? _selectedCard(AppProvider provider) {
    if (_selectedCardId == null) return null;
    for (final AccountCard card in provider.cards) {
      if (card.id == _selectedCardId) return card;
    }
    return null;
  }

  Widget _buildBalanceCard(BuildContext context, AppProvider provider) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final AccountCard? card = _selectedCard(provider);
    final String currency = card?.currency ?? 'USD';
    final double totalBalance = card?.balance ?? 0.00;

    final double expense = provider.getSpentThisMonth(
      currency,
      cardId: _selectedCardId,
    );
    final double income = provider.getIncomeThisMonth(
      currency,
      cardId: _selectedCardId,
    );

    // Sparkline: gasto de los últimos 7 días para esta cuenta.
    final List<double> last7 = _last7DaysSpending(
      provider.transactions,
      currency: currency,
      cardId: _selectedCardId,
    );
    final double maxSpending = last7.fold(
      0.0,
      (max, value) => value > max ? value : max,
    );
    final double chartMaxY = maxSpending == 0 ? 20.0 : maxSpending * 1.3;

    return CashCard(
      key: TourKeys.balanceCardKey,
      padding: EdgeInsets.zero,
      gradient: isDark ? AppColors.darkGradient : AppColors.heroGradient,
      boxShadow: isDark ? AppShadows.darkPrimary : AppShadows.primary,
      child: Stack(
        children: [
          // Gráfico de fondo: no intercepta gestos.
          Positioned(
            left: 0,
            right: 0,
            bottom: -10,
            height: 96,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.45,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 6,
                    minY: 0,
                    maxY: chartMaxY,
                    lineTouchData: LineTouchData(enabled: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < last7.length; i++)
                            FlSpot(i.toDouble(), last7[i]),
                        ],
                        isCurved: true,
                        color: Colors.white,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Orbe decorativa para dar profundidad.
          Positioned(
            right: -46,
            top: -46,
            child: Container(
              height: 130,
              width: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t('total_balance'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _buildCardSelector(context, provider),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildBalanceAmount(context, totalBalance, currency),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: _BalanceMetric(
                        icon: Icons.south_west_rounded,
                        label: context.t('income_month'),
                        value: '\$${income.toFormattedString(0)}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _BalanceMetric(
                        icon: Icons.north_east_rounded,
                        label: context.t('expense_month'),
                        value: '\$${expense.toFormattedString(0)}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Saldo principal. Se escala hacia abajo en pantallas muy angostas para no
  /// desbordar nunca, sin truncar el número.
  Widget _buildBalanceAmount(
    BuildContext context,
    double balance,
    String currency,
  ) {
    final ThemeData theme = Theme.of(context);

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '\$ ${balance.toFormattedString(2)}',
            maxLines: 1,
            style: theme.textTheme.displayMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: AppRadius.radiusSm,
            ),
            child: Text(
              currency,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSelector(BuildContext context, AppProvider provider) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Flexible(
      child: Container(
        key: TourKeys.cardSelectorKey,
        constraints: const BoxConstraints(maxWidth: _cardSelectorMaxWidth),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: AppRadius.radiusSm,
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: const Key('homeCardSelector'),
            isExpanded: true,
            isDense: true,
            value: _selectedCardId,
            borderRadius: AppRadius.radiusMd,
            dropdownColor: isDark
                ? AppColors.surfaceDark2
                : AppColors.surfaceLight,
            icon: const Icon(
              Icons.expand_more_rounded,
              color: Colors.white,
              size: 18,
            ),
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            hint: Text(
              context.t('select_card'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: Colors.white),
            ),
            items: provider.cards.map((AccountCard card) {
              final String label = _cardDropdownLabel(context, card);
              return DropdownMenuItem<String>(
                value: card.id,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() => _selectedCardId = newValue);
            },
          ),
        ),
      ),
    );
  }

  String _cardDropdownLabel(BuildContext context, AccountCard card) {
    if (card.isCash) {
      return '${context.t('card_cash')} · ${card.name} · ${card.currency}';
    }

    final String bankName = card.bankName == 'Efectivo'
        ? context.t('card_cash')
        : (card.bankName ?? context.t('card_default_name'));
    final String last4 = card.cardNumber.length >= 4
        ? card.cardNumber.substring(card.cardNumber.length - 4)
        : '****';

    return '$bankName · $last4 · ${card.currency}';
  }

  /// Agrega el gasto de cada día de la última semana.
  List<double> _last7DaysSpending(
    List<InternalTransaction> transactions, {
    required String currency,
    String? cardId,
  }) {
    final List<double> result = List.filled(7, 0);
    final DateTime today = DateTime.now();

    for (final tx in transactions) {
      if (tx.currency != currency) continue;
      if (cardId != null && tx.cardId != cardId) continue;
      if (tx.amount >= 0) continue;

      final txDate = tx.date;
      for (var i = 0; i < 7; i++) {
        final dayDate = DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(Duration(days: 6 - i));
        if (txDate.year == dayDate.year &&
            txDate.month == dayDate.month &&
            txDate.day == dayDate.day) {
          result[i] += tx.amount.abs();
        }
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // ACCIONES RÁPIDAS
  // ---------------------------------------------------------------------------

  Widget _buildQuickActions(BuildContext context, AppProvider provider) {
    final List<Widget> primaryActions = [
      CashQuickAction(
        icon: Icons.remove_rounded,
        label: context.t('expense'),
        color: AppColors.expense,
        onTap: () => _openAddTransaction(context, asExpense: true),
      ),
      CashQuickAction(
        icon: Icons.add_rounded,
        label: context.t('income'),
        color: AppColors.income,
        onTap: () => _openAddTransaction(context, asExpense: false),
      ),
      CashQuickAction(
        key: TourKeys.transferActionKey,
        icon: Icons.swap_horiz_rounded,
        label: context.t('action_transfer'),
        color: Theme.of(context).colorScheme.primary,
        isLocked: !provider.canTransfer,
        onTap: () {
          if (provider.canTransfer) {
            _showActionDialog(context, provider, 'transfer');
          } else {
            _showLockedFeatureDialog(context);
          }
        },
      ),
    ];

    final List<Widget> secondaryActions = [
      CashChip(
        label: context.t('nav_business'),
        icon: Icons.storefront_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BusinessGatekeeper()),
        ),
      ),
      CashChip(
        label: context.t('recurring'),
        icon: Icons.autorenew_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RecurringTransactionsScreen(),
          ),
        ),
      ),
      if (provider.isCuba &&
          provider.transferMovilEnabled &&
          (!kIsWeb && !Platform.isWindows))
        CashChip(
          label: 'Transfermóvil',
          icon: Icons.smartphone_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TransferMovilScreen()),
          ),
        ),
      CashChip(
        key: TourKeys.scanKey,
        label: context.t('action_more'),
        icon: Icons.grid_view_rounded,
        onTap: () => _checkPremiumAndExecute(
          context,
          provider,
          () => _showMoreOptions(context),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tres acciones frecuentes, siempre a la misma altura sea cual sea el
        // ancho: Expanded evita cualquier overflow en pantallas de 320 px.
        Row(
          children: [
            for (int i = 0; i < primaryActions.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: primaryActions[i]),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Herramientas secundarias: se desplazan en horizontal para no robarle
        // espacio a las acciones principales.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (int i = 0; i < secondaryActions.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                secondaryActions[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _openAddTransaction(BuildContext context, {required bool asExpense}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionModal(startAsExpense: asExpense),
    );
  }

  void _openAllTransactions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllTransactionsScreen(initialCardId: _selectedCardId),
      ),
    );
  }

  void _checkPremiumAndExecute(
    BuildContext context,
    AppProvider provider,
    VoidCallback action,
  ) {
    if (provider.canUseMoreActions) {
      action();
    } else {
      _showLockedFeatureDialog(context);
    }
  }

  void _showLockedFeatureDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.lock_rounded,
          size: 40,
          color: AppColors.warning,
        ),
        title: Text(
          ctx.t('feature_locked_title'),
          style: Theme.of(ctx).textTheme.titleLarge,
        ),
        content: Text(
          ctx.t('feature_locked_desc'),
          textAlign: TextAlign.center,
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('cancel')),
          ),
          CashButton(
            label: ctx.t('upgrade_btn'),
            fullWidth: false,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LicensesScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showActionDialog(
    BuildContext context,
    AppProvider provider,
    String actionType,
  ) async {
    // actionType is now 'transfer', 'recharge', 'request'
    final titleMap = {
      'transfer': context.t('action_transfer'),
      'recharge': context.t('action_recharge'),
      'request': context.t('action_request'),
    };
    final displayTitle = titleMap[actionType] ?? actionType;

    if (_selectedCardId == null && provider.cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('add_card_first')),
        ), // Fallback if key missing
      );
      return;
    }

    final cardId = _selectedCardId ?? provider.cards.first.id;
    final card = provider.cards.firstWhere((c) => c.id == cardId);
    final controller = TextEditingController();
    final exchangeRateController = TextEditingController(text: "1.0");

    // For internal transfer logic
    bool isInternalTransfer = false;
    String? toCardId;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          // Need state for Dropdown/Switch
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                displayTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${context.t('from')}: ${card.bankName} (${card.currency})",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),

                    if (actionType == "transfer") ...[
                      Row(
                        children: [
                          Checkbox(
                            value: isInternalTransfer,
                            onChanged: (val) {
                              setState(() => isInternalTransfer = val == true);
                            },
                          ),
                          Flexible(
                            child: Text(
                              context.t('to_card'),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      if (isInternalTransfer) ...[
                        const SizedBox(height: 10),
                        DropdownButton<String>(
                          isExpanded: true,
                          hint: Text(context.t('select_dest')),
                          value: toCardId,
                          items: provider.cards
                              .where((c) => c.id != card.id)
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    "${c.isCash ? c.name : (c.bankName ?? 'Tarjeta')} (...${c.isCash ? 'CASH' : (c.cardNumber.length >= 4 ? c.cardNumber.substring(c.cardNumber.length - 4) : c.cardNumber)}) - ${c.currency}",
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) => setState(() => toCardId = val),
                        ),
                        if (toCardId != null &&
                            provider.cards
                                    .firstWhere((c) => c.id == toCardId)
                                    .currency !=
                                card.currency) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: exchangeRateController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: "Tasa de cambio (Ej. 320)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 10),
                    ],

                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: context.t('amount'),
                        prefixText: "\$ ",
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text(context.t('cancel')),
                  onPressed: () => Navigator.pop(ctx),
                ),
                CashButton(
                  label: context.t('confirm'),
                  fullWidth: false,
                  onPressed: () {
                    final amount = double.tryParse(controller.text);
                    if (amount == null || amount <= 0) return;

                    if (actionType == "transfer" &&
                        (amount - card.balance) > 0.005) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.t('insufficient_funds')),
                        ),
                      );
                      return;
                    }

                    if (card.isLocked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.t('card_locked'))),
                      );
                      return;
                    }

                    // Define the Action to Run
                    void runAction() {
                      if (actionType == "transfer" && isInternalTransfer) {
                        if (toCardId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.t('select_destination_error'),
                              ),
                            ),
                          );
                          return;
                        }
                        double exRate = 1.0;
                        if (toCardId != null &&
                            provider.cards
                                    .firstWhere((c) => c.id == toCardId)
                                    .currency !=
                                card.currency) {
                          exRate =
                              double.tryParse(exchangeRateController.text) ??
                              1.0;
                        }
                        provider.transferBetweenCards(
                          fromCardId: card.id,
                          toCardId: toCardId!,
                          amount: amount,
                          exchangeRate: exRate,
                        );
                      } else {
                        // Standard Action
                        double finalAmount = amount;
                        String title = displayTitle;
                        String catId = 'general';
                        if (actionType == "transfer") {
                          finalAmount = -amount;
                          title = context.t('transfer_sent');
                          catId = 'transfer_out';
                        } else if (actionType == "recharge") {
                          title = context.t('recharge_success');
                          catId = 'recharge';
                        } else if (actionType == "request") {
                          title = context.t('request_received');
                          catId = 'income_request';
                        }

                        provider.addTransaction(
                          amount: finalAmount,
                          title: title,
                          categoryId: catId,
                          currency: card.currency,
                          cardId: card.id,
                        );
                      }
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "$displayTitle ${context.t('success_action')}",
                          ),
                        ),
                      );
                    }

                    // Check PIN
                    if (card.pin != null && card.pin!.isNotEmpty) {
                      // Close current dialog first? No, stack it.
                      // Actually, better to verify inside THIS dialog context or close it?
                      // If we open another dialog on top, it's fine.
                      showDialog<void>(
                        context: context,
                        builder: (pinCtx) {
                          final pinController = TextEditingController();
                          return AlertDialog(
                            title: Text(
                              context.t('enter_pin'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            content: TextField(
                              controller: pinController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 4,
                              autofocus: true,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(pinCtx),
                                child: Text(context.t('cancel')),
                              ),
                              CashButton(
                                label: context.t('confirm'),
                                fullWidth: false,
                                onPressed: () {
                                  if (pinController.text == card.pin) {
                                    if (!context.mounted) return;
                                    Navigator.pop(pinCtx); // Close PIN
                                    runAction(); // Run
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.t('pin_incorrect'),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      runAction();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final List<Widget> options = [
          if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
            CashQuickAction(
              icon: Icons.qr_code_scanner_rounded,
              label: context.t('action_scan'),
              // El resultado del escáner ya no se descarta: se precarga en el
              // formulario de alta de la tarjeta.
              onTap: _scanCardFromHome,
            ),
          CashQuickAction(
            icon: Icons.history_rounded,
            label: context.t('action_history'),
            onTap: () => _navigateFromMoreOptions(
              context,
              AllTransactionsScreen(initialCardId: _selectedCardId),
            ),
          ),
          CashQuickAction(
            icon: Icons.account_balance_rounded,
            label: context.t('action_balances'),
            onTap: () =>
                _navigateFromMoreOptions(context, const WalletScreen()),
          ),
          CashQuickAction(
            icon: Icons.real_estate_agent_rounded,
            label: context.t('nav_loans'),
            onTap: () =>
                _navigateFromMoreOptions(context, const LoansGatekeeper()),
          ),
          CashQuickAction(
            icon: Icons.help_outline_rounded,
            label: context.t('action_help'),
            onTap: () =>
                _navigateFromMoreOptions(context, const HelpCenterScreen()),
          ),
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              0,
              AppSpacing.screenHorizontal,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('action_more'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const int columns = 3;
                    const double spacing = AppSpacing.sm;
                    final double itemWidth =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final Widget option in options)
                          SizedBox(width: itemWidth, child: option),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateFromMoreOptions(BuildContext context, Widget destination) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
  }

  /// Escanea una tarjeta física y ofrece darla de alta con los datos leídos.
  ///
  /// Antes la acción "Escanear" descartaba el resultado del escáner y la
  /// lectura no servía para nada; ahora se reutiliza para precargar el
  /// formulario de alta (`AddCardScreen`).
  Future<void> _scanCardFromHome() async {
    Navigator.pop(context); // Cierra el bottom sheet de "Más opciones".

    final dynamic result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CardScannerScreen()),
    );

    // Tras el `await` la pantalla puede haberse desmontado.
    if (!mounted || result is! Map) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCardScreen(
          initialHolder: result['holder'] as String?,
          initialNumber: result['number'] as String?,
          initialExpiry: result['expiry'] as String?,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RESUMEN DEL MES
  // ---------------------------------------------------------------------------

  Widget _buildFinancialSummary(BuildContext context, AppProvider provider) {
    final AccountCard? card = _selectedCard(provider);
    final String currency = card?.currency ?? 'USD';

    final double income = provider.getIncomeThisMonth(
      currency,
      cardId: _selectedCardId,
    );
    final double expense = provider.getSpentThisMonth(
      currency,
      cardId: _selectedCardId,
    );
    final double savings = income - expense;

    // El ahorro usa iconos además del color para no depender solo del tono.
    final bool positive = savings >= 0;

    final List<Widget> stats = <Widget>[
      CashStatCard(
        title: context.t('income'),
        value: '\$${income.toFormattedString(0)}',
        icon: Icons.south_west_rounded,
        iconColor: AppColors.income,
      ),
      CashStatCard(
        title: context.t('expense'),
        value: '\$${expense.toFormattedString(0)}',
        icon: Icons.north_east_rounded,
        iconColor: AppColors.expense,
      ),
      CashStatCard(
        title: context.t('savings'),
        value: '\$${savings.toFormattedString(0)}',
        icon: positive ? Icons.savings_rounded : Icons.trending_down_rounded,
        iconColor: positive ? AppColors.income : AppColors.expense,
      ),
    ];

    return CashSection(
      title: context.t('financial_summary'),
      subtitle: context.t('monthly_movement'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double spacing = AppSpacing.md;
          final int columns = constraints.maxWidth >= 420 ? 3 : 2;
          final double itemWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final Widget stat in stats)
                SizedBox(width: itemWidth, child: stat),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOVIMIENTOS
  // ---------------------------------------------------------------------------

  Widget _buildTransactionsList(BuildContext context, AppProvider provider) {
    final ThemeData theme = Theme.of(context);

    List<InternalTransaction> transactions = provider.transactions;
    if (_selectedCardId != null) {
      transactions = transactions
          .where((t) => t.cardId == _selectedCardId)
          .toList();
    }

    transactions = transactions.take(_recentTransactionsCount).toList();

    return CashSection(
      key: TourKeys.transactionsKey,
      title: context.t('recent_transactions'),
      action: TextButton(
        onPressed: () => _openAllTransactions(context),
        child: Text(
          context.t('view_all'),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      child: transactions.isEmpty
          ? CashCard(
              child: CashEmptyState(
                icon: Icons.receipt_long_rounded,
                title: context.t('no_recent_transactions'),
                message: context.t('home_empty_hint'),
                buttonLabel: context.t('new_transaction'),
                onButtonPressed: () =>
                    _openAddTransaction(context, asExpense: true),
              ),
            )
          : CashCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                children: [
                  for (int i = 0; i < transactions.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: theme.dividerColor,
                      ),
                    CashTransactionTile(
                      icon: _transactionIcon(provider, transactions[i]),
                      title: _getTransactionTitle(context, transactions[i]),
                      subtitle: _transactionSubtitle(
                        context,
                        provider,
                        transactions[i],
                      ),
                      amount:
                          '\$${transactions[i].amount.abs().toFormattedString(2)}',
                      isIncome: transactions[i].amount >= 0,
                      onTap: () => _showTransactionActions(
                        context,
                        provider,
                        transactions[i],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  String _getTransactionTitle(BuildContext context, InternalTransaction tx) {
    if (tx.categoryId == 'transfer_out') {
      return context.t('transfer_sent');
    }
    if (tx.categoryId == 'recharge') {
      return context.t('recharge_success');
    }
    if (tx.categoryId == 'income_request') {
      return context.t('request_received');
    }
    if (tx.categoryId == 'general') {
      return context.t('cat_general'); // Or 'nueva transaccion' if general
    }
    // Default Categories
    if (tx.categoryId.startsWith('cat_')) {
      return context.t(tx.categoryId);
    }
    // Fallback to stored title if custom or unknown
    return tx.title;
  }

  /// Icono del movimiento: el de su categoría cuando existe.
  IconData _transactionIcon(AppProvider provider, InternalTransaction tx) {
    for (final Category category in provider.categories) {
      if (category.id == tx.categoryId) {
        return IconConstants.getCategoryIcon(category.iconCode);
      }
    }
    return tx.amount >= 0
        ? Icons.attach_money_rounded
        : Icons.receipt_long_rounded;
  }

  String _transactionSubtitle(
    BuildContext context,
    AppProvider provider,
    InternalTransaction tx,
  ) {
    final String date = _formatDate(tx.date);

    for (final AccountCard card in provider.cards) {
      if (card.id != tx.cardId) continue;
      final String name = card.isCash
          ? '${context.t('card_cash')} · ${card.name}'
          : '${card.bankName ?? context.t('card_default_name')} · ${_last4(card.cardNumber)}';
      return '$date · $name';
    }

    return date;
  }

  String _last4(String cardNumber) => cardNumber.length >= 4
      ? cardNumber.substring(cardNumber.length - 4)
      : '****';

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  /// Acciones del movimiento. Antes solo se disparaba con long press; ahora
  /// responde al toque (más descubrible) y mantiene el long press.
  void _showTransactionActions(
    BuildContext context,
    AppProvider provider,
    InternalTransaction tx,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.info),
              title: Text(context.t('edit')),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEditTransactionDialog(context, provider, tx);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: Text(context.t('delete')),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDeleteConfirmation(context, provider, tx);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  void _showEditTransactionDialog(
    BuildContext context,
    AppProvider provider,
    InternalTransaction tx,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTransactionModal(transactionToEdit: tx),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    AppProvider provider,
    InternalTransaction tx,
  ) {
    showCashConfirmDialog(
      context,
      title: context.t('delete_transaction'),
      message: context.t('delete_transaction_confirm'),
      confirmLabel: context.t('delete'),
      cancelLabel: context.t('cancel'),
      icon: Icons.delete_outline_rounded,
    ).then((confirmed) async {
      if (confirmed == true && context.mounted) {
        await provider.deleteTransaction(tx.id);
        if (context.mounted) {
          CashSnack.success(context, context.t('transaction_deleted'));
        }
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Piezas visuales locales
// ---------------------------------------------------------------------------

/// Botón de notificaciones con contador de no leídas.
class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({
    required this.count,
    required this.tooltip,
    required this.onPressed,
  });

  final int count;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CashIconButton(
      icon: Icons.notifications_none_rounded,
      size: 44,
      iconSize: 21,
      bordered: true,
      tooltip: tooltip,
      onPressed: onPressed,
      badge: count > 0
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 1,
              ),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: AppRadius.radiusSm,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                ),
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }
}

/// Métrica secundaria dentro de la tarjeta de balance.
class _BalanceMetric extends StatelessWidget {
  const _BalanceMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: [
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
