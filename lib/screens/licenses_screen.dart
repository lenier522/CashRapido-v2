import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cashrapido/services/localization_service.dart';
import 'package:provider/provider.dart';
import 'package:cashrapido/providers/app_provider.dart';
import 'package:cashrapido/licences/license_type.dart';
import 'package:cashrapido/licences/art_pay.dart';
import 'package:cashrapido/licences/payment_config.dart';

class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isCuba = provider.isCuba;
    final isPromoActive = provider.isPromoActive;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A14),
        appBar: _buildAppBar(context, isCuba, provider),
        body: Stack(
          children: [
            _buildBackground(),
            isPromoActive
                ? _buildHolidayPromo(context)
                : _buildContent(context, provider),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    bool isCuba,
    AppProvider provider,
  ) {
    return AppBar(
      backgroundColor: const Color(0xFF0A0A14),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        context.t('licenses_title'),
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      actions: [
        if (isCuba)
          IconButton(
            tooltip: context.t('verify_license'),
            icon: const Icon(Icons.refresh, color: Colors.amber),
            onPressed: () => _verifyLicense(context, provider),
          ),
      ],
      bottom: TabBar(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        indicatorColor: Colors.amber,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        tabs: [
          Tab(text: context.t('period_weekly')),
          Tab(text: context.t('period_monthly')),
          Tab(text: context.t('period_annual')),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.purple.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          right: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.amber.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, AppProvider provider) {
    return Column(
      children: [
        Expanded(child: _buildTabBarView(provider)),
        _buildCurrentLicenseBanner(context, provider),
      ],
    );
  }

  Widget _buildTabBarView(AppProvider provider) {
    return TabBarView(
      children: [
        _buildLicenseList(provider, LicensePeriod.weekly),
        _buildLicenseList(provider, LicensePeriod.monthly),
        _buildLicenseList(provider, LicensePeriod.annual),
      ],
    );
  }

  Widget _buildLicenseList(AppProvider provider, LicensePeriod period) {
    final licenses = LicenseType.values
        .where((l) => l.period == period && l != LicenseType.free)
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: licenses.length,
      itemBuilder: (ctx, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildLicenseCard(provider, licenses[index], provider.isCuba),
      ),
    );
  }

  Widget _buildLicenseCard(
    AppProvider provider,
    LicenseType licenseType,
    bool isCuba,
  ) {
    final isCurrent = provider.licenseType == licenseType;
    final level = licenseType.level;
    final durationDays = licenseType.durationDays;
    final priceCUP = ArtPayService.getPriceCUP(licenseType);
    final priceUSD = ArtPayService.getPriceUSD(licenseType);

    final theme = _getTheme(level);
    final features = _getFeatures(level);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141428),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? theme : theme.withValues(alpha: 0.3),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getIcon(level), color: theme, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ArtPayService.getLicenseName(licenseType),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$durationDays ${context.t('days')}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.t('active'),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (level == LicenseLevel.pro && !isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.t('popular'),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Price
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.withValues(alpha: 0.08),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.attach_money, size: 20, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  isCuba ? '\$$priceCUP' : '\$$priceUSD',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isCuba ? 'CUP' : 'USD',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme,
                  ),
                ),
              ],
            ),
          ),
          // Features
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: features
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check, color: theme, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            f,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          // Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: isCurrent
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.t('active'),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme, theme.withValues(alpha: 0.8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showPaymentDialog(licenseType),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.t('select_plan'),
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLicenseBanner(
    BuildContext context,
    AppProvider provider,
  ) {
    final licenseType = provider.licenseType;
    final expirationDate = provider.licenseActivationDate;

    if (licenseType == LicenseType.free) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141428),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.info_outline, color: Colors.white54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.t('current_license_free'),
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withValues(alpha: 0.15),
            Colors.teal.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_user, color: Colors.greenAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.t('current_license')}: ${ArtPayService.getLicenseName(licenseType)}',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                if (expirationDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${context.t('expires')}: ${_formatDate(expirationDate)}',
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayPromo(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration, color: Colors.white, size: 64),
              const SizedBox(height: 20),
              Text(
                context.t('promo_title'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.t('promo_message'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    context.t('promo_button'),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== HELPERS ====================

  Color _getTheme(LicenseLevel level) {
    switch (level) {
      case LicenseLevel.personal:
        return const Color(0xFF4FC3F7);
      case LicenseLevel.pro:
        return const Color(0xFFBA68C8);
      case LicenseLevel.enterprise:
        return const Color(0xFFFFD54F);
      default:
        return Colors.grey;
    }
  }

  IconData _getIcon(LicenseLevel level) {
    switch (level) {
      case LicenseLevel.personal:
        return Icons.person_outline;
      case LicenseLevel.pro:
        return Icons.workspace_premium;
      case LicenseLevel.enterprise:
        return Icons.business_center;
      default:
        return Icons.free_breakfast;
    }
  }

  List<String> _getFeatures(LicenseLevel level) {
    switch (level) {
      case LicenseLevel.personal:
        return [
          context.t('feat_3_cards'),
          context.t('feat_transfers'),
          context.t('feat_lock_card'),
          context.t('feat_adv_stats'),
        ];
      case LicenseLevel.pro:
        return [
          context.t('feat_pro_cards'),
          context.t('feat_pro_categories'),
          context.t('feat_pro_stats'),
          context.t('feat_pro_export'),
        ];
      case LicenseLevel.enterprise:
        return [
          context.t('feat_ent_unlimited'),
          context.t('feat_ent_business'),
          context.t('feat_ent_ai_bio'),
          context.t('feat_ent_all_features'),
        ];
      default:
        return [];
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ==================== PAYMENT DIALOG ====================

  void _showPaymentDialog(LicenseType licenseType) {
    final isCuba = Provider.of<AppProvider>(context, listen: false).isCuba;

    showDialog(
      context: context,
      builder: (ctx) => Consumer<AppProvider>(
        builder: (context, provider, _) {
          final methods = _getFilteredMethods(provider, licenseType);

          return AlertDialog(
            backgroundColor: const Color(0xFF141428),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ArtPayService.getLicenseColor(
                      licenseType,
                    ).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    ArtPayService.getLicenseIcon(licenseType),
                    color: ArtPayService.getLicenseColor(licenseType),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  ArtPayService.getLicenseName(licenseType),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isCuba
                      ? '\$${ArtPayService.getPriceCUP(licenseType)} CUP'
                      : '\$${ArtPayService.getPriceUSD(licenseType)} USD',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: methods.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        context.t('payment_disabled'),
                        style: GoogleFonts.outfit(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: methods
                          .map(
                            (m) =>
                                _buildMethodTile(m, licenseType, provider, ctx),
                          )
                          .toList(),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  context.t('cancel'),
                  style: GoogleFonts.outfit(color: Colors.white54),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMethodTile(
    dynamic method,
    LicenseType licenseType,
    AppProvider provider,
    BuildContext ctx,
  ) {
    final enabled = method.isEnabled ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled
                ? Colors.amber.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.payment,
            color: enabled ? Colors.amber : Colors.grey,
            size: 20,
          ),
        ),
        title: Text(
          method.id.contains('test')
              ? context.t('test_method')
              : method.id == 'watch_ads'
              ? context.t('pay_watch_ads')
              : method.name,
          style: GoogleFonts.outfit(
            color: enabled ? Colors.white : Colors.white38,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: enabled
            ? () => _handlePayment(method, licenseType, provider, ctx)
            : null,
      ),
    );
  }

  List<dynamic> _getFilteredMethods(
    AppProvider provider,
    LicenseType licenseType,
  ) {
    final config = LicensePaymentConfig.getConfig(licenseType);
    final isCuba = provider.isCuba;

    return provider.paymentMethods.where((m) {
      if (!m.isVisible) return false;
      if (!config.isMethodEnabled(m.id)) return false;
      if (config.isCubaOnly && !isCuba) return false;
      if (m.id == 'watch_ads' && isCuba) return false;
      if (m.id == 'apklis' && !isCuba) return false;
      return true;
    }).toList();
  }

  void _handlePayment(
    dynamic method,
    LicenseType licenseType,
    AppProvider provider,
    BuildContext ctx,
  ) async {
    Navigator.pop(ctx);

    if (method.id == 'watch_ads') {
      provider.setAdTargetLicense(licenseType);
      _showAdsDialog(licenseType, provider);
      return;
    }

    if (method.id == 'art_pay') {
      ArtPayService.handlePayment(
        context: context,
        licenseType: licenseType,
        onSuccess: (result) {
          provider.setLicenseType(
            licenseType,
            expirationDate: result.accessExpiresAt,
          );
        },
        onError: (e) => debugPrint("ArtPay Error: $e"),
      );
      return;
    }

    if (method.isTest ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.t('payment_test_success')} (${licenseType.name.toUpperCase()})',
          ),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    if (method.id == 'apklis') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Procesando pago con Apklis...',
                      style: GoogleFonts.outfit(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final errorMsg = await provider.simulatePayment(method.id, licenseType);
      
      if (!mounted) return;
      
      // Cerrar dialog
      Navigator.of(context, rootNavigator: true).pop();
      
      if (errorMsg == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('license_active_success')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAdsDialog(LicenseType licenseType, AppProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Consumer<AppProvider>(
        builder: (context, provider, _) {
          final watched = provider.adsWatched;
          final target = provider.adsTarget;
          final ready = provider.adService.isAdReady;

          if (watched >= target) {
            Future.delayed(Duration.zero, () {
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context
                          .t('msg_license_activated')
                          .replaceAll(
                            '{license}',
                            ArtPayService.getLicenseName(licenseType),
                          ),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            });
            return const SizedBox.shrink();
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF141428),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Column(
              children: [
                const Icon(
                  Icons.ondemand_video,
                  color: Colors.amberAccent,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  context.t('dialog_watch_ads_title'),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context
                      .t('dialog_watch_ads_desc')
                      .replaceAll('{target}', target.toString())
                      .replaceAll(
                        '{license}',
                        ArtPayService.getLicenseName(licenseType),
                      ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: watched / target,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    color: Colors.amberAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "$watched / $target",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: ready
                        ? () {
                            provider.adService.showRewardedAd(
                              onUserEarnedReward: () =>
                                  provider.incrementAdsWatched(),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: ready
                        ? const Icon(Icons.play_arrow)
                        : const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                    label: Text(
                      ready
                          ? context.t('btn_watch_video')
                          : context.t('btn_loading_ad'),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  context.t('btn_close'),
                  style: GoogleFonts.outfit(color: Colors.white54),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _verifyLicense(
    BuildContext context,
    AppProvider provider,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    context.t('verifying'),
                    style: GoogleFonts.outfit(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    String? errorMsg;
    try {
      errorMsg = await provider.verifyAndRestoreLicense();
    } catch (e) {
      errorMsg = e.toString();
    } finally {
      if (context.mounted) navigator.pop();
    }

    if (!context.mounted) return;

    if (errorMsg == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.t('license_restored')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      final isNoLicense =
          errorMsg.contains('No se encontró') ||
          errorMsg.contains('No active license');

      messenger.showSnackBar(
        SnackBar(
          content: Text(isNoLicense ? context.t('no_license_found') : errorMsg),
          backgroundColor: isNoLicense ? Colors.orange : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
