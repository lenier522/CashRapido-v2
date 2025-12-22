import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/localization_service.dart';
import 'add_card_screen.dart';
import 'money_counter_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.t('wallet'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddCardScreen()),
            ),
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.deepPurple,
            ),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          final cards = provider.cards;
          // If no cards, show placeholder only? Or add a logical check.
          // Let's simplify: List includes actual cards. If empty, show instructions.

          if (cards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.credit_card_off,
                    size: 60,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.t('no_cards'),
                    style: GoogleFonts.outfit(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddCardScreen()),
                    ),
                    child: Text(context.t('add_now')),
                  ),
                ],
              ),
            );
          }

          final activeCard = cards[_currentIndex % cards.length];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    context.t('my_cards'),
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // PageView for Cards
                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentIndex = index),
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      // Translate name if 'Efectivo'
                      String displayName = card.name;
                      if (displayName == 'Efectivo' || displayName == 'CASH') {
                        displayName = context.t('card_cash');
                      }

                      final currencyObj = provider.availableCurrencies
                          .firstWhere(
                            (c) => c.code == card.currency,
                            orElse: () => Currency(
                              code: card.currency,
                              symbol: '\$',
                              name: '',
                            ),
                          );

                      return _buildCreditCard(
                        context: context,
                        cardId: card.id,
                        isLocked: card.isLocked,
                        color: Color(card.colorValue),
                        bankName: card.isCash
                            ? context.t('card_cash')
                            : (card.bankName ?? 'VISA'),
                        balance:
                            '${currencyObj.symbol} ${card.balance.toStringAsFixed(2)}',
                        cardNumber: card.isCash
                            ? ''
                            : _maskCardNumber(card.cardNumber),
                        expiry: card.isCash ? '' : card.expiryDate,
                        cardHolder: displayName,
                        isCash: card.isCash,
                        currencyCode: card.currency,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),
                Center(
                  child: Text(
                    "${_currentIndex + 1} ${context.t('of')} ${cards.length}",
                    style: GoogleFonts.outfit(color: Colors.grey),
                  ),
                ),

                const SizedBox(height: 30),

                // Settings for ACTIVE CARD
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('card_settings'),
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildSettingTile(
                        Icons.edit,
                        context.t('edit_card'),
                        context.t('edit_card_subtitle'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AddCardScreen(cardToEdit: activeCard),
                            ),
                          );
                        },
                      ),

                      _buildSettingTile(
                        activeCard.isLocked ? Icons.lock : Icons.lock_open,
                        activeCard.isLocked
                            ? context.t('unlock_card')
                            : context.t('lock_card'),
                        activeCard.isLocked
                            ? context.t('enable_use')
                            : context.t('disable_temporarily'),
                        onTap: () async {
                          await Provider.of<AppProvider>(
                            context,
                            listen: false,
                          ).toggleCardLock(activeCard.id);
                        },
                        isDestructive: activeCard.isLocked ? false : true,
                      ),

                      if (!activeCard.isCash)
                        _buildSettingTile(
                          Icons.pin,
                          context.t('change_pin'),
                          context.t('transaction_security'),
                          onTap: () => _showPinDialog(
                            context,
                            Provider.of<AppProvider>(context, listen: false),
                            activeCard.id,
                          ),
                        ),

                      _buildSettingTile(
                        Icons.speed,
                        context.t('spending_limit'),
                        activeCard.spendingLimit == null
                            ? context.t('no_limit_set')
                            : '\$ ${activeCard.spendingLimit!.toStringAsFixed(2)}',
                        onTap: () => _showLimitDialog(
                          context,
                          Provider.of<AppProvider>(context, listen: false),
                          activeCard.id,
                        ),
                      ),

                      if (activeCard.isCash)
                        _buildSettingTile(
                          Icons.calculate_outlined,
                          context.t('count_money'),
                          context.t('money_counter_title'),
                          onTap: () {
                            final currency =
                                Provider.of<AppProvider>(
                                  context,
                                  listen: false,
                                ).availableCurrencies.firstWhere(
                                  (c) => c.code == activeCard.currency,
                                  orElse: () => Currency(
                                    code: activeCard.currency,
                                    symbol: '\$',
                                    name: '',
                                  ),
                                );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MoneyCounterScreen(
                                  currencySymbol: currency.symbol,
                                ),
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 20),
                      _buildSettingTile(
                        Icons.delete_outline,
                        context.t('delete_card'),
                        context.t('action_cannot_undone'),
                        onTap: () => _confirmDelete(context, activeCard.id),
                        isDestructive: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // Placeholder for Add New Card if minimal space
              ],
            ),
          );
        },
      ),
    );
  }

  String _maskCardNumber(String input) {
    if (input == 'CASH') return '';
    // Input format from DB: "2547-5568-7854-1154"
    if (input.length < 5) return input;
    // We want: "**** **** **** 1154" (Spaces)
    // Identify the last 4 chars
    String last4 = input.substring(input.length - 4);
    return '**** **** **** $last4';
  }

  Widget _buildCreditCard({
    required BuildContext context,
    required String cardId,
    required bool isLocked,
    required Color color,
    required String balance,
    required String cardNumber,
    required String expiry,
    required String cardHolder,
    required String bankName,
    required String currencyCode,
    bool isCash = false,
  }) {
    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isLocked ? Colors.grey : color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isLocked ? Colors.grey : color).withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: isLocked
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.9), color],
              ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    bankName,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        currencyCode,
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isCash
                            ? Icons.account_balance_wallet
                            : Icons.contactless,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                balance,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCash)
                    Text(
                      cardNumber,
                      style: GoogleFonts.sourceCodePro(
                        color: Colors.white,
                        fontSize: 18,
                        letterSpacing: 2,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cardHolder,
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        expiry,
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (isLocked)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(Icons.lock, color: Colors.white, size: 40),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    IconData icon,
    String title,
    String subtitle, {
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.1)
                : Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isDestructive
                ? Colors.red
                : Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDestructive
                ? Colors.red
                : Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.outfit(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        onTap: onTap,
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
    );
  }

  void _showPinDialog(
    BuildContext context,
    AppProvider provider,
    String cardId,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          context.t('set_pin'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: InputDecoration(hintText: context.t('enter_4_digits')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.length == 4) {
                provider.setCardPin(cardId, controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('pin_updated'))),
                );
              }
            },
            child: Text(context.t('save')),
          ),
        ],
      ),
    );
  }

  void _showLimitDialog(
    BuildContext context,
    AppProvider provider,
    String cardId,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          context.t('spending_limit'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: context.t('monthly_amount'),
            prefixText: "\$ ",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final limit = double.tryParse(controller.text);
              if (limit != null && limit > 0) {
                provider.setCardLimit(cardId, limit);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('limit_updated'))),
                );
              }
            },
            child: Text(context.t('save')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String cardId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.t('delete_card_question'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.t('delete_card_confirmation'),
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.t('cancel'),
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              await Provider.of<AppProvider>(
                context,
                listen: false,
              ).deleteCard(cardId);
              if (!context.mounted) return;
              Navigator.pop(ctx);
              // If cards empty, setState handled by builder or parent
              setState(() {
                if (_currentIndex > 0) _currentIndex--;
              });
            },
            child: Text(
              context.t('delete'),
              style: GoogleFonts.outfit(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
