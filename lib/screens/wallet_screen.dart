import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../utils/number_format_utils.dart';
import '../widgets/design/cash_button.dart';
import '../widgets/design/cash_card.dart';
import '../widgets/design/cash_chip.dart';
import '../widgets/design/cash_empty_state.dart';
import '../widgets/design/cash_icon_button.dart';
import '../widgets/design/cash_input.dart';
import '../widgets/design/cash_quick_action.dart';
import '../widgets/design/cash_section.dart';
import '../widgets/design/cash_stat_card.dart';
import 'add_card_screen.dart';
import 'licenses_screen.dart';
import 'money_counter_screen.dart';

/// Centro de cuentas y dinero de CashRapido.
///
/// Responde, en este orden, las cinco preguntas del usuario:
/// cuánto dinero tengo, en qué cuentas está, cuál estoy viendo,
/// en qué moneda y qué puedo hacer con ella.
///
/// Esta capa es visual: no recalcula saldos ni decide límites de licencia.
/// Todo sale de `AppProvider`, y los totales por moneda usan su propio
/// `getTotalBalance`, de modo que nunca se suman cantidades entre divisas.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  /// Índice de la cuenta activa dentro de `provider.cards`.
  int _currentIndex = 0;

  /// Moneda del resumen principal. `null` se resuelve a la principal del
  /// ajuste o, si no se usa, a la primera cuenta existente.
  String? _totalCurrencyCode;

  // ---------------------------------------------------------------------------
  // ESTRUCTURA
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        // La barra de navegación principal ya reserva el espacio inferior.
        bottom: false,
        child: Consumer<AppProvider>(
          builder: (context, provider, child) {
            final List<AccountCard> cards = provider.cards;

            if (cards.isEmpty) {
              return _buildEmptyState(context, provider);
            }

            // El índice se modula porque `deleteCard` puede dejar el puntero
            // fuera de rango hasta que el siguiente build lo corrija.
            final int activeIndex = _currentIndex % cards.length;
            final AccountCard activeCard = cards[activeIndex];
            final List<String> currencies = _currenciesInUse(provider);

            if (_totalCurrencyCode == null ||
                !currencies.contains(_totalCurrencyCode)) {
              _totalCurrencyCode = _defaultCurrencyCode(provider, currencies);
            }

            return SingleChildScrollView(
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
                  _buildTotalBalance(context, provider, currencies),
                  if (currencies.length > 1) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    _buildCurrencyBreakdown(context, provider, currencies),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  _buildAccountsSection(context, provider, activeIndex),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildSelectedAccount(context, provider, activeCard),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildActions(context, provider, activeCard),
                ],
              ),
            );
          },
        ),
      ),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('wallet'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                context.t('wallet_subtitle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        CashIconButton(
          icon: Icons.add_rounded,
          size: 46,
          iconSize: 24,
          iconColor: isDark ? AppColors.primary : AppColors.primaryDark,
          backgroundColor: isDark
              ? AppColors.surfaceDark2
              : AppColors.primaryLight,
          tooltip: context.t('add_account'),
          onPressed: () => _openAddCard(context, provider),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BALANCE TOTAL
  // ---------------------------------------------------------------------------

  Widget _buildTotalBalance(
    BuildContext context,
    AppProvider provider,
    List<String> currencies,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final String code = _totalCurrencyCode!;
    final Currency currency = _currencyFor(provider, code);

    // Suma exacta de las cuentas de esa moneda. Nunca se suman divisas
    // distintas: cada código mantiene su propio total.
    final double total = provider.getTotalBalance(code);
    final int accountCount = provider.cards
        .where((AccountCard card) => card.currency == code)
        .length;

    return CashCard(
      padding: EdgeInsets.zero,
      gradient: isDark ? AppColors.darkGradient : AppColors.heroGradient,
      boxShadow: isDark ? AppShadows.darkPrimary : AppShadows.primary,
      child: Padding(
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
                _HeroChip(
                  icon: Icons.payments_rounded,
                  label: code,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Se escala hacia abajo en pantallas muy angostas para que un saldo
            // largo nunca desborde ni se trunque.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${currency.symbol} ${total.toFormattedString(2)}',
                maxLines: 1,
                style: theme.textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '$accountCount ${context.t('accounts')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            if (currencies.length > 1) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                context.t('total_by_currency_hint'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Desglose por moneda. Cada tarjeta es un `CashStatCard` y a la vez el
  /// selector de la moneda del resumen principal.
  Widget _buildCurrencyBreakdown(
    BuildContext context,
    AppProvider provider,
    List<String> currencies,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return CashSection(
      title: context.t('total_by_currency'),
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
              for (final String code in currencies)
                SizedBox(
                  width: itemWidth,
                  child: _CurrencyStatCard(
                    code: code,
                    symbol: _currencyFor(provider, code).symbol,
                    amount: provider.getTotalBalance(code),
                    isActive: code == _totalCurrencyCode,
                    onTap: () => setState(() => _totalCurrencyCode = code),
                    primary: theme.colorScheme.primary,
                    mutedColor: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CUENTAS Y TARJETAS
  // ---------------------------------------------------------------------------

  Widget _buildAccountsSection(
    BuildContext context,
    AppProvider provider,
    int activeIndex,
  ) {
    final List<AccountCard> cards = provider.cards;

    return CashSection(
      title: context.t('my_cards'),
      subtitle: context.t('reorder_hint'),
      action: CashChip(
        label: '${activeIndex + 1} ${context.t('of')} ${cards.length}',
        icon: Icons.account_balance_wallet_rounded,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Se deja asomar la siguiente tarjeta para.invitar a deslizar, sin
          // provocar scroll horizontal en la página.
          final double tileWidth = math.min(
            320.0,
            math.max(232.0, constraints.maxWidth - 72),
          );

          return SizedBox(
            height: 196,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: AppSpacing.screenHorizontal),
              buildDefaultDragHandles: false,
              clipBehavior: Clip.none,
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (BuildContext context, Widget? child) {
                        final double t = Curves.easeInOut.transform(
                          animation.value,
                        );
                        return Transform.scale(
                          scale: 1 + 0.04 * t,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              borderRadius: AppRadius.radiusXl,
                              boxShadow: AppShadows.elevated,
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: child,
                    );
                  },
              itemCount: cards.length,
              onReorder: (int oldIndex, int newIndex) =>
                  _handleReorder(context, provider, oldIndex, newIndex),
              itemBuilder: (context, int index) {
                final AccountCard card = cards[index];

                return ReorderableDelayedDragStartListener(
                  key: ValueKey<String>(card.id),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: SizedBox(
                      width: tileWidth,
                      child: _AccountCardTile(
                        card: card,
                        position: index,
                        isSelected: index == activeIndex,
                        onTap: () => setState(() => _currentIndex = index),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _handleReorder(
    BuildContext context,
    AppProvider provider,
    int oldIndex,
    int newIndex,
  ) {
    if (!provider.canReorderCards) {
      _showFeatureLockedDialog(context);
      return;
    }

    provider.reorderCards(oldIndex, newIndex);
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      _currentIndex = newIndex;
    });
  }

  // ---------------------------------------------------------------------------
  // CUENTA SELECCIONADA
  // ---------------------------------------------------------------------------

  Widget _buildSelectedAccount(
    BuildContext context,
    AppProvider provider,
    AccountCard card,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Currency currency = _currencyFor(provider, card.currency);
    final Color accent = Color(card.colorValue);

    return CashSection(
      title: context.t('selected_account'),
      child: CashCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: Icon(
                    card.isCash
                        ? Icons.account_balance_wallet_rounded
                        : Icons.credit_card_rounded,
                    color: isDark ? Colors.white : accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayName(context, card),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.isCash
                            ? context.t('type_cash')
                            : (card.bankName ?? context.t('type_card')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Divider(height: 1, thickness: 1, color: theme.dividerColor),
            const SizedBox(height: AppSpacing.md),
            // El estado se repite con texto aquí porque el carrusel solo tiene
            // espacio para el icono: nunca se depende únicamente del color.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                CashChip(
                  label: context.t('selected_badge'),
                  icon: Icons.check_circle_rounded,
                  selected: true,
                ),
                if (card.isLocked)
                  CashChip(
                    label: context.t('locked_badge'),
                    icon: Icons.lock_rounded,
                    selected: true,
                    color: AppColors.warning,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _MetaItem(
                  icon: Icons.category_rounded,
                  label: card.isCash
                      ? context.t('type_cash')
                      : context.t('type_card'),
                ),
                _MetaItem(
                  icon: Icons.payments_rounded,
                  label: '${currency.symbol} ${card.currency}',
                ),
                if (!card.isCash)
                  _MetaItem(
                    icon: Icons.tag_rounded,
                    label: _maskCardNumber(card.cardNumber),
                  ),
                if (!card.isCash)
                  _MetaItem(
                    icon: Icons.event_rounded,
                    label: card.expiryDate.isEmpty
                        ? '—'
                        : card.expiryDate,
                  ),
                _MetaItem(
                  icon: Icons.speed_rounded,
                  label: card.spendingLimit == null
                      ? context.t('no_limit_set')
                      : '\$${card.spendingLimit!.toFormattedString(2)}',
                ),
                _MetaItem(
                  icon: card.pin == null || card.pin!.isEmpty
                      ? Icons.lock_open_rounded
                      : Icons.lock_rounded,
                  label: card.pin == null || card.pin!.isEmpty
                      ? context.t('pin_not_set')
                      : context.t('pin_set'),
                  color: card.isLocked ? AppColors.warning : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACCIONES
  // ---------------------------------------------------------------------------

  Widget _buildActions(
    BuildContext context,
    AppProvider provider,
    AccountCard card,
  ) {
    final List<Widget> actions = <Widget>[
      CashQuickAction(
        icon: Icons.edit_rounded,
        label: context.t('edit_card'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddCardScreen(cardToEdit: card),
          ),
        ),
      ),
      CashQuickAction(
        icon: card.isLocked
            ? Icons.lock_open_rounded
            : Icons.lock_rounded,
        label: card.isLocked
            ? context.t('unlock_card')
            : context.t('lock_card'),
        color: card.isLocked ? AppColors.income : AppColors.warning,
        isLocked: !provider.canSecurizeCard,
        onTap: () => _guard(
          context,
          provider.canSecurizeCard,
          () => provider.toggleCardLock(card.id),
        ),
      ),
      if (!card.isCash)
        CashQuickAction(
          icon: Icons.pin_rounded,
          label: context.t('change_pin'),
          color: AppColors.info,
          isLocked: !provider.canChangeCardPIN,
          onTap: () => _guard(
            context,
            provider.canChangeCardPIN,
            () => _showPinDialog(context, provider, card.id),
          ),
        ),
      CashQuickAction(
        icon: Icons.speed_rounded,
        label: context.t('spending_limit'),
        color: AppColors.secondary,
        isLocked: !provider.canSecurizeCard,
        onTap: () => _guard(
          context,
          provider.canSecurizeCard,
          () => _showLimitDialog(context, provider, card),
        ),
      ),
      if (card.isCash)
        CashQuickAction(
          icon: Icons.calculate_rounded,
          label: context.t('count_money'),
          color: AppColors.primaryDark,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MoneyCounterScreen(
                currencySymbol: _currencyFor(provider, card.currency).symbol,
              ),
            ),
          ),
        ),
    ];

    return CashSection(
      title: context.t('account_actions'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const double spacing = AppSpacing.sm;
              // Tres columnas en móvil amplio, dos en el más estrecho.
              final int columns = constraints.maxWidth >= 400 ? 3 : 2;
              final double itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final Widget action in actions)
                    SizedBox(width: itemWidth, child: action),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          // Zona destructiva: una sola acción roja, nunca un botón por tile.
          CashCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.28),
            ),
            boxShadow: const <BoxShadow>[],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('delete_card'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  context.t('action_cannot_undone'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                CashButton(
                  label: context.t('delete_card'),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  type: CashButtonType.danger,
                  onPressed: () => _confirmDelete(context, card.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ejecuta la acción o muestra el diálogo de licencia, según el permiso.
  void _guard(BuildContext context, bool allowed, VoidCallback action) {
    if (allowed) {
      action();
    } else {
      _showFeatureLockedDialog(context);
    }
  }

  // ---------------------------------------------------------------------------
  // ESTADO VACÍO
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(BuildContext context, AppProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Punto de extensión para la ilustración de Rapi (FASE 10).
          CashEmptyState(
            icon: Icons.account_balance_wallet_rounded,
            title: context.t('no_cards'),
            message: context.t('wallet_empty_hint'),
            buttonLabel: context.t('add_account'),
            onButtonPressed: () => _openAddCard(context, provider),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NAVEGACIÓN Y DIÁLOGOS
  // ---------------------------------------------------------------------------

  void _openAddCard(BuildContext context, AppProvider provider) {
    if (provider.canAddCard) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddCardScreen()),
      );
    } else {
      _showLicenseDialog(
        context,
        title: context.t('limit_reached_title'),
        message: context.t('limit_card_desc'),
      );
    }
  }

  void _showFeatureLockedDialog(BuildContext context) {
    _showLicenseDialog(
      context,
      title: context.t('feature_locked_title'),
      message: context.t('feature_locked_desc'),
    );
  }

  void _showLicenseDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: const Icon(
          Icons.lock_rounded,
          size: 40,
          color: AppColors.warning,
        ),
        title: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('close')),
          ),
          CashButton(
            label: context.t('upgrade_btn'),
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

  void _showPinDialog(
    BuildContext context,
    AppProvider provider,
    String cardId,
  ) {
    final TextEditingController controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(
          context.t('set_pin'),
          style: Theme.of(ctx).textTheme.titleLarge,
        ),
        content: CashInput(
          controller: controller,
          label: context.t('enter_4_digits'),
          hint: context.t('enter_4_digits'),
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          autofocus: true,
          prefix: const Icon(Icons.lock_outline_rounded),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          CashButton(
            label: context.t('save'),
            fullWidth: false,
            onPressed: () {
              // Misma validación que antes: exactamente 4 dígitos.
              if (controller.text.length == 4) {
                provider.setCardPin(cardId, controller.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('pin_updated'))),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showLimitDialog(
    BuildContext context,
    AppProvider provider,
    AccountCard card,
  ) {
    final TextEditingController controller = TextEditingController();
    final String symbol = _currencyFor(provider, card.currency).symbol;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(
          context.t('spending_limit'),
          style: Theme.of(ctx).textTheme.titleLarge,
        ),
        content: CashInput(
          controller: controller,
          label: context.t('spending_limit'),
          hint: context.t('monthly_amount'),
          helperText: symbol,
          keyboardType: TextInputType.number,
          autofocus: true,
          prefix: const Icon(Icons.payments_rounded),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          CashButton(
            label: context.t('save'),
            fullWidth: false,
            onPressed: () {
              final double? limit = double.tryParse(controller.text);
              if (limit != null && limit > 0) {
                provider.setCardLimit(card.id, limit);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('limit_updated'))),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String cardId) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline_rounded,
          size: 40,
          color: AppColors.error,
        ),
        title: Text(
          context.t('delete_card_question'),
          style: Theme.of(ctx).textTheme.titleLarge,
        ),
        content: Text(
          context.t('delete_card_confirmation'),
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          CashButton(
            label: context.t('delete'),
            type: CashButtonType.danger,
            fullWidth: false,
            onPressed: () async {
              await Provider.of<AppProvider>(
                context,
                listen: false,
              ).deleteCard(cardId);
              if (!context.mounted) return;
              Navigator.pop(ctx);
              setState(() {
                if (_currentIndex > 0) _currentIndex--;
              });
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UTILIDADES
  // ---------------------------------------------------------------------------

  /// Traduce el nombre interno "Efectivo" / "CASH" al idioma activo.
  String _displayName(BuildContext context, AccountCard card) {
    if (card.name == 'Efectivo' || card.name == 'CASH') {
      return context.t('card_cash');
    }
    return card.name;
  }

  /// Monedas realmente usadas por las cuentas, con la principal del ajuste
  /// primero si existe entre ellas.
  List<String> _currenciesInUse(AppProvider provider) {
    final Set<String> used = <String>{
      for (final AccountCard card in provider.cards) card.currency,
    };
    final List<String> result = used.toList();

    if (result.contains(provider.mainCurrency)) {
      result
        ..remove(provider.mainCurrency)
        ..insert(0, provider.mainCurrency);
    }

    return result;
  }

  String _defaultCurrencyCode(
    AppProvider provider,
    List<String> currencies,
  ) {
    if (currencies.contains(provider.mainCurrency)) {
      return provider.mainCurrency;
    }
    return currencies.first;
  }

  Currency _currencyFor(AppProvider provider, String code) {
    return provider.availableCurrencies.firstWhere(
      (Currency c) => c.code == code,
      orElse: () => Currency(code: code, symbol: '\$', name: ''),
    );
  }

  String _maskCardNumber(String input) {
    if (input == 'CASH') return '';
    if (input.length < 5) return input;
    final String last4 = input.substring(input.length - 4);
    return '**** **** **** $last4';
  }
}

// ---------------------------------------------------------------------------
// Piezas visuales locales
// ---------------------------------------------------------------------------

/// Chip translúcido para usar sobre el degradado verde del resumen.
///
/// `CashChip` usa superficies neutras y perdería contraste sobre el verde,
/// por eso aquí se necesita una variante sobre color.
class _HeroChip extends StatelessWidget {
  const _HeroChip({this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta visual de una cuenta.
///
/// Mantiene el color que el usuario eligió para esa cuenta (dato del modelo,
/// no identidad de marca): por eso las cuentas no se ven todas iguales.
/// El estado bloqueado se marca con gris + candado, no solo con tono.
class _AccountCardTile extends StatelessWidget {
  const _AccountCardTile({
    required this.card,
    required this.position,
    required this.isSelected,
    required this.onTap,
  });

  final AccountCard card;

  /// Posición dentro del carrusel (base 0). La cuenta 0 es la principal.
  final int position;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color accountColor = Color(card.colorValue);
    final Color face = card.isLocked
        ? (isDark ? const Color(0xFF39413D) : const Color(0xFF8D9993))
        : accountColor;

    // La selección se marca con borde + icono + el texto del chip de detalle,
    // para que no dependa solo del color.
    final Border? border = isSelected
        ? Border.all(color: AppColors.primary, width: 2.2)
        : null;

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CashCard(
        onTap: onTap,
        border: border,
        padding: const EdgeInsets.all(AppSpacing.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            face.withValues(alpha: card.isLocked ? 1 : 0.9),
            face,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: face.withValues(alpha: isDark ? 0.28 : 0.32),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: AppRadius.radiusXs,
                  ),
                  child: Text(
                    position == 0
                        ? '1 · ${context.t('primary_account')}'
                        : '${position + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    card.isCash
                        ? context.t('type_cash')
                        : (card.bankName ?? context.t('type_card_short')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  card.isCash
                      ? Icons.account_balance_wallet_rounded
                      : Icons.contactless_rounded,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    card.balance.toFormattedString(2),
                    maxLines: 1,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            // Sin `Spacer`: si el texto no cabe (fuente alternativa o escala del
            // sistema grande) se recorta con puntos suspensivos en vez de
            // desbordar la tarjeta.
            Row(
              children: [
                _HeroChip(label: card.currency),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (card.isLocked) ...[
                        Icon(
                          Icons.lock_rounded,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            context.t('locked_badge'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ] else if (isSelected) ...[
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            context.t('selected_badge'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `CashStatCard` con el código de la moneda como título y el saldo exacto
/// como valor. Es a la vez el desglose multimoneda y el selector del resumen.
class _CurrencyStatCard extends StatelessWidget {
  const _CurrencyStatCard({
    required this.code,
    required this.symbol,
    required this.amount,
    required this.isActive,
    required this.onTap,
    required this.primary,
    required this.mutedColor,
  });

  final String code;
  final String symbol;
  final double amount;
  final bool isActive;
  final VoidCallback onTap;
  final Color primary;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return CashStatCard(
      title: '$symbol $code',
      value: amount.toFormattedString(2),
      icon: isActive ? Icons.check_circle_rounded : Icons.payments_rounded,
      iconColor: isActive ? primary : mutedColor,
      onTap: onTap,
    );
  }
}

/// Dato suelto del detalle de la cuenta (tipo, moneda, número, vencimiento…).
class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color accent = color ?? theme.colorScheme.primary;
    final Color textColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark2 : AppColors.surfaceVariantLight,
        borderRadius: AppRadius.radiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}