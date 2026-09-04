import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/localization_service.dart';
import 'all_transactions_screen.dart';
import 'ai_chat_screen.dart';
import 'card_scanner_screen.dart';
import 'info_screens.dart';
import 'licenses_screen.dart';
import 'transfermovil_screen.dart';
import 'wallet_screen.dart';
import 'streak_calendar_screen.dart';
import 'notifications_screen.dart';
import 'recurring_transactions_screen.dart';
import '../widgets/add_transaction_modal.dart';
import 'loans/loans_gatekeeper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../utils/tour_keys.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedCardId;
  Timer? _promoTimer;

  @override
  void initState() {
    super.initState();
    // Tour moved to MainScreen for multi-screen coverage
    // Live countdown for the 24h trial banner.
    // Defer setState out of the build phase so it never throws
    // "setState called during build" while another widget animates.
    _promoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    super.dispose();
  }

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (provider.isTrialActive) ...[
                    _buildTrialBanner(context, provider),
                    const SizedBox(height: 20),
                  ],
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildBalanceCard(context, provider),
                  const SizedBox(height: 24),
                  _buildQuickActions(context, provider),
                  const SizedBox(height: 24),
                  _buildTransactionsList(context, provider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Placeholder for BottomNavBar if it doesn't exist, likely need to find where it was defined or if I need to add it.
  // Viewing previous file suggests it calls `_buildBottomNavBar` but I don't see definition.
  // I will assume it exists further down or I need to create a simple one to fix build.
  // actually, looking at the original file (pre-edit), there WAS NO _buildBottomNavBar call in build method?
  // Wait, line 49 was _buildQuickActions.
  // The FAB adds transaction.
  // The user mentions "floating bottom se ve x encima del icono de billetera", implying there is a bottom bar.
  // I'll add a dummy one or find it.
  // Actually, let's look at the bottom of the file later.

  Widget _buildTrialBanner(BuildContext context, AppProvider provider) {
    final remaining = provider.trialRemaining;
    final hh = remaining.inHours.toString().padLeft(2, '0');
    final mm = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final time = '$hh:$mm:$ss';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = Colors.green;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            baseColor.withValues(alpha: 0.25),
            Colors.teal.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: baseColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.card_giftcard, color: Colors.greenAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context
                      .t('trial_active_banner')
                      .replaceAll('{time}', time),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF0B3D2E),
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LicensesScreen(),
                      ),
                    );
                  },
                  child: Text(
                    context.t('trial_view_plans'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      color: isDark
                          ? Colors.greenAccent
                          : const Color(0xFF0B7A45),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final provider = Provider.of<AppProvider>(context);

    // AI Button
    Widget? aiButton;
    if (provider.aiChatEnabled) {
      aiButton = GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AIChatScreen()),
          );
        },
        child: Container(
          key: TourKeys.aiButtonKey,
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('daily_summary'),
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.headlineMedium?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const StreakCalendarScreen()));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 4),
                    Text(
                      '${provider.streakDays}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (aiButton != null) ...[aiButton, const SizedBox(width: 12)],

            // Notification Icon
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
              child: Stack(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: Theme.of(context).iconTheme.color,
                    ),
                  ),
                  if (provider.unreadNotificationsCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${provider.unreadNotificationsCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceCard(BuildContext context, AppProvider provider) {
    AccountCard? selectedCard;
    if (_selectedCardId != null) {
      try {
        selectedCard = provider.cards.firstWhere(
          (c) => c.id == _selectedCardId,
        );
      } catch (e) {
        selectedCard = null;
      }
    }

    final currency = selectedCard?.currency ?? 'USD';
    final totalBalance = selectedCard?.balance ?? 0.00;

    final expense = provider.getSpentThisMonth(
      currency,
      cardId: _selectedCardId,
    );
    final income = provider.getIncomeThisMonth(
      currency,
      cardId: _selectedCardId,
    );

    // Gradient built from the selected card color, with a premium fallback.
    final int cardColorValue = selectedCard?.colorValue ?? 0xFF7E57C2;
    final Color baseColor = cardColorValue == 0xFF1A1A1A
        ? const Color(0xFF4A2E8F)
        : Color(cardColorValue);
    final Color endColor = Color.lerp(baseColor, Colors.black, 0.35)!;

    // Sparkline data: last 7 days of spending for this card/currency.
    final List<double> last7 = _last7DaysSpending(
      provider.transactions,
      currency: currency,
      cardId: _selectedCardId,
    );
    final double maxSpending =
        last7.fold(0.0, (max, value) => value > max ? value : max);
    final double chartMaxY = maxSpending == 0 ? 20.0 : maxSpending * 1.3;

    return Container(
      key: TourKeys.balanceCardKey,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor, endColor],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background chart: smooth sparkline of the last 7 days of spending.
          Positioned.fill(
            left: 0,
            right: 0,
            bottom: -8,
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
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Decorative floating orb for a premium feel.
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.t('total_balance'),
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Card Selector
                    Flexible(
                      child: Container(
                        key: TourKeys.cardSelectorKey,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded:
                                true, // Allows button to shrink and truncate
                            value: _selectedCardId,
                            dropdownColor: const Color(0xFF2B2340),
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                              size: 16,
                            ),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            hint: Text(
                              context.t('select_card'),
                              style: GoogleFonts.outfit(color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                            items: provider.cards.map((AccountCard card) {
                              String displayName;
                              if (card.isCash) {
                                displayName = card.name;
                              } else {
                                String bankName = card.bankName ?? 'Tarjeta';
                                if (bankName == 'Efectivo') {
                                  bankName = context.t('card_cash');
                                }
                                displayName = bankName;
                              }

                              final last4 = card.isCash
                                  ? ''
                                  : (card.cardNumber.length >= 4
                                        ? card.cardNumber.substring(
                                            card.cardNumber.length - 4,
                                          )
                                        : '****');

                              return DropdownMenuItem<String>(
                                value: card.id,
                                child: Text(
                                  card.isCash
                                      ? "${context.t('card_cash')}(${card.name})-${card.currency}"
                                      : "$displayName $last4 ${card.currency}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedCardId = newValue;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '\$ ${totalBalance.toFormattedString(2)}',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.t('monthly_movement'),
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _buildCardInfoBadge(
                      Icons.arrow_upward,
                      context.t('income_month'),
                      '+ \$${income.toFormattedString(0)}',
                      Colors.white,
                    ),
                    const SizedBox(width: 24),
                    _buildCardInfoBadge(
                      Icons.arrow_downward,
                      context.t('expense_month'),
                      '- \$${expense.toFormattedString(0)}',
                      Colors.white,
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

  // Aggregates net spending per day for the last 7 days.
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
        final dayDate =
            DateTime(today.year, today.month, today.day).subtract(
              Duration(days: 6 - i),
            );
        if (txDate.year == dayDate.year &&
            txDate.month == dayDate.month &&
            txDate.day == dayDate.day) {
          result[i] += tx.amount.abs();
        }
      }
    }
    return result;
  }

  Widget _buildCardInfoBadge(
    IconData icon,
    String label,
    String amount,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, AppProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment
          .spaceAround, // Changed to spaceAround for better look with 2 items
      children: [
        _buildActionButton(
          context,
          Icons.swap_horiz,
          context.t('action_transfer'),
          () {
            if (provider.canTransfer) {
              _showActionDialog(context, provider, "transfer");
            } else {
              _showLockedFeatureDialog(context);
            }
          },
          key: TourKeys.transferActionKey,
          isLocked: !provider.canTransfer,
        ),
        _buildActionButton(
          context,
          Icons.autorenew,
          'Recurrente',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecurringTransactionsScreen()),
            );
          },
        ),
        if (provider.isCuba &&
            provider.transferMovilEnabled &&
            (!kIsWeb && !Platform.isWindows))
          _buildActionButton(
            context,
            Icons.smartphone, // Transfermóvil Icon
            "Transfermóvil", // Localization? The user said "Transfermóvil" explicitly in plan, but we should use key if possible. The key 'cat_transfermovil' is for category. I'll use raw string or add new key. Plan used raw name in options.
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransferMovilScreen()),
              );
            },
          ),
        _buildActionButton(
          context,
          Icons.more_horiz,
          context.t('action_more'),
          () => _checkPremiumAndExecute(
            context,
            provider,
            () => _showMoreOptions(context),
          ),
          key: TourKeys.scanKey,
          isLocked: !provider.canUseMoreActions,
        ),
      ],
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.t('feature_locked_title'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_person, size: 48, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              context.t('feature_locked_desc'),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LicensesScreen()),
              );
            },
            child: Text(context.t('upgrade_btn')),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Key? key,
    bool isLocked = false,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip
                .none, // Allow lock to overflow without clipping or affecting layout
            children: [
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20), // Softer radius
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.deepPurple),
              ),
              if (isLocked)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ), // Border to separate
                    ),
                    child: const Icon(
                      Icons.lock,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
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
    // If we want to do "Transferir" between cards, we need logic for that.
    // For now, let's keep it simple: "Transferir" is external expense.
    // BUT user requested: "opcion de que se pueda transferir de una tarjeta a otra".

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

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          // Need state for Dropdown/Switch
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                displayTitle,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${context.t('from')}: ${card.bankName} (${card.currency})",
                      style: GoogleFonts.outfit(color: Colors.grey),
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
                              style: GoogleFonts.outfit(),
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
                        if (toCardId != null && provider.cards.firstWhere((c) => c.id == toCardId).currency != card.currency) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: exchangeRateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                ElevatedButton(
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
                        if (toCardId != null && provider.cards.firstWhere((c) => c.id == toCardId).currency != card.currency) {
                          exRate = double.tryParse(exchangeRateController.text) ?? 1.0;
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
                      showDialog(
                        context: context,
                        builder: (pinCtx) {
                          final pinController = TextEditingController();
                          return AlertDialog(
                            title: Text(
                              context.t('enter_pin'),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                              ),
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
                              ElevatedButton(
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
                                child: Text(context.t('confirm')),
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      runAction();
                    }
                  },
                  child: Text(context.t('confirm')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t('action_more'),
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                    _buildMoreOptionItem(
                      Icons.qr_code_scanner,
                      context.t('action_scan'),
                      () => _navigateFromMoreOptions(
                        context,
                        const CardScannerScreen(),
                      ),
                    ),
                  _buildMoreOptionItem(
                    Icons.history,
                    context.t('action_history'),
                    () => _navigateFromMoreOptions(
                      context,
                      AllTransactionsScreen(initialCardId: _selectedCardId),
                    ),
                  ),
                  _buildMoreOptionItem(
                    Icons.bar_chart,
                    context.t('action_balances'),
                    () => _navigateFromMoreOptions(context, const WalletScreen()),
                  ),
                  _buildMoreOptionItem(
                    Icons.real_estate_agent_outlined,
                    context.t('nav_loans'),
                    () => _navigateFromMoreOptions(context, const LoansGatekeeper()),
                  ),
                  _buildMoreOptionItem(
                    Icons.help_outline,
                    context.t('action_help'),
                    () =>
                        _navigateFromMoreOptions(context, const HelpCenterScreen()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateFromMoreOptions(BuildContext context, Widget destination) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  Widget _buildMoreOptionItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.deepPurple),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.outfit(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(BuildContext context, AppProvider provider) {
    // Filter transactions if card selected
    List<InternalTransaction> transactions = provider.transactions;
    if (_selectedCardId != null) {
      transactions = transactions
          .where((t) => t.cardId == _selectedCardId)
          .toList();
    }

    // Take recent 5 transactions
    transactions = transactions.take(5).toList();

    return Column(
      key: TourKeys.transactionsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.t('recent_transactions'),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AllTransactionsScreen(initialCardId: _selectedCardId),
                  ),
                );
              },
              child: Text(
                context.t('view_all'),
                style: TextStyle(color: Colors.deepPurple),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                context.t('no_recent_transactions'),
                style: GoogleFonts.outfit(color: Colors.grey),
              ),
            ),
          )
        else
          ...transactions.map((tx) {
            final isExpense = tx.amount < 0;

            String cardNameStr = '';
            try {
              final card = provider.cards.firstWhere((c) => c.id == tx.cardId);
              if (card.isCash) {
                cardNameStr = " • ${context.t('card_cash')} - ${card.name}";
              } else {
                final bName = card.bankName == 'Efectivo' ? context.t('card_cash') : (card.bankName ?? context.t('card_default_name'));
                final l4 = card.cardNumber.length >= 4 ? card.cardNumber.substring(card.cardNumber.length - 4) : '****';
                cardNameStr = " • $bName $l4";
              }
            } catch (_) {}

            return _buildTransactionItem(
              context,
              provider,
              tx,
              _getTransactionTitle(context, tx),
              "${tx.date.toString().substring(0, 10)}$cardNameStr",
              '${isExpense ? '-' : '+'}\$${tx.amount.abs().toFormattedString(2)}',
              isExpense
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              isExpense ? Colors.red : Colors.green,
              isExpense ? Icons.shopping_bag_outlined : Icons.attach_money,
            );
          }),
      ],
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

  Widget _buildTransactionItem(
    BuildContext context,
    AppProvider provider,
    InternalTransaction tx,
    String title,
    String subtitle,
    String amount,
    Color bgColor,
    Color iconColor,
    IconData icon,
  ) {
    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: Text(context.t('edit')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditTransactionDialog(context, provider, tx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(context.t('delete')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirmation(context, provider, tx);
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amount,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: amount.startsWith('+') ? Colors.green : Colors.red,
              ),
            ),
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
    showModalBottomSheet(
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('delete_transaction')),
        content: Text(context.t('delete_transaction_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await provider.deleteTransaction(tx.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.t('transaction_deleted'))),
              );
            },
            child: Text(context.t('delete')),
          ),
        ],
      ),
    );
  }
}
