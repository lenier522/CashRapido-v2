import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cashrapido/services/localization_service.dart';

import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isCuba = provider.isCuba;
    // Holiday Promotion Check (Until Jan 10th midnight, 2026)
    final isPromoActive = DateTime.now().isBefore(
      DateTime(2026, 1, 11),
    ); // Promo ended

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t('licenses_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isCuba)
            IconButton(
              tooltip: context.t('verify_license'),
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () async {
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  useRootNavigator: true,
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
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );

                // Capture navigator and messenger
                final navigator = Navigator.of(context, rootNavigator: true);
                final messenger = ScaffoldMessenger.of(context);
                final appProvider = Provider.of<AppProvider>(
                  context,
                  listen: false,
                );

                String? errorMsg;
                try {
                  errorMsg = await appProvider.verifyAndRestoreLicense();
                } catch (e) {
                  errorMsg = e.toString();
                } finally {
                  navigator.pop(); // Close loading dialog
                }

                if (!context.mounted) return;

                // Show result
                if (errorMsg == null) {
                  // Success - license restored
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(context.t('license_restored')),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                } else {
                  // Error or no license found
                  final isNoLicense =
                      errorMsg.contains('No se encontró') ||
                      errorMsg.contains('No active license') ||
                      errorMsg.contains('Aucune licence');

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        isNoLicense ? context.t('no_license_found') : errorMsg,
                      ),
                      backgroundColor: isNoLicense ? Colors.orange : Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF121212), // Deep dark background
            ),
          ),
          // Gradient Orbs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPromoActive
                    ? Colors.amber.withValues(alpha: 0.2)
                    : Colors.purple.withValues(alpha: 0.2),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPromoActive
                    ? Colors.redAccent.withValues(alpha: 0.15)
                    : Colors.blueAccent.withValues(alpha: 0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Content
          isPromoActive
              ? _buildHolidayPromo(context)
              : ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  children: [
                    _buildLicenseCard(
                      context,
                      title: context.t('license_personal'),
                      price: isCuba ? '\$50' : '\$0.50',
                      currency: isCuba ? 'CUP' : 'USD',
                      period: context.t('month_short'),
                      features: [
                        context.t('feat_3_cards'),
                        context.t('feat_transfers'),
                        context.t('feat_lock_card'),
                        context.t('feat_adv_stats'),
                        context.t('feat_settings_basic'),
                      ],
                      color: Colors.blueGrey.shade400,
                      accentColor: Colors.blueGrey,
                      onTap: () => _showPaymentMethodsDialog(
                        context,
                        LicenseType.personal,
                      ),
                      isCurrent: provider.licenseType == LicenseType.personal,
                      isCuba: isCuba,
                      hasAnyLicense: provider.licenseType != LicenseType.free,
                    ),
                    const SizedBox(height: 24),
                    _buildLicenseCard(
                      context,
                      title: context.t('license_pro'),
                      price: isCuba ? '\$75' : '\$1',
                      currency: isCuba ? 'CUP' : 'USD',
                      period: context.t('month_short'),
                      features: [
                        context.t('feat_pro_cards'),
                        context.t('feat_pro_categories'),
                        context.t('feat_pro_stats'),
                        context.t('feat_pro_settings'),
                        context.t('feat_pro_security'),
                      ],
                      color: const Color(0xFFBB86FC), // Premium Purple
                      accentColor: Colors.deepPurpleAccent,
                      isPopular: true,
                      onTap: () =>
                          _showPaymentMethodsDialog(context, LicenseType.pro),
                      isCurrent: provider.licenseType == LicenseType.pro,
                      isCuba: isCuba,
                      hasAnyLicense: provider.licenseType != LicenseType.free,
                    ),
                    const SizedBox(height: 24),
                    _buildLicenseCard(
                      context,
                      title: context.t('license_enterprise'),
                      price: isCuba ? '\$110' : '\$1.5',
                      currency: isCuba ? 'CUP' : 'USD',
                      period: context.t('month_short'),
                      features: [
                        context.t('feat_ent_unlimited'),
                        context.t('feat_ent_scanner'),
                        context.t('feat_ent_ai_bio'),
                        context.t('feat_ent_charts_pdf'),
                        context.t('feat_ent_cloud'),
                      ],
                      color: Colors.amberAccent,
                      accentColor: Colors.orangeAccent,
                      onTap: () => _showPaymentMethodsDialog(
                        context,
                        LicenseType.enterprise,
                      ),
                      isCurrent: provider.licenseType == LicenseType.enterprise,
                      isCuba: isCuba,
                      hasAnyLicense: provider.licenseType != LicenseType.free,
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildHolidayPromo(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.amberAccent.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amberAccent.withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.celebration_rounded,
                color: Colors.amberAccent,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                context.t('promo_title'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.t('promo_message'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    context.t('promo_button'),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseCard(
    BuildContext context, {
    required String title,
    required String price,
    required String currency,
    required String period,
    required List<String> features,
    required Color color,
    required Color accentColor,

    bool isPopular = false,

    bool isCurrent = false,
    bool isCuba = false,
    bool hasAnyLicense = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isPopular
            ? LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.15),
                  const Color(0xFF1E1E2C),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: const Color(0xFF1E1E2C),
        border: Border.all(
          color: isPopular
              ? accentColor.withValues(alpha: 0.5)
              : Colors.white10,
          width: isPopular ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          if (isPopular)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: -5,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isPopular) const SizedBox(height: 12), // Space for badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (isPopular)
                      Icon(Icons.star_rounded, color: accentColor, size: 28),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currency,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          period,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                const SizedBox(height: 24),
                ...features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check, color: color, size: 14),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          feature,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(height: 32),
                if (!isCurrent) ...[
                  if (!isCuba && hasAnyLicense)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          context.t('plan_change'),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  else if (!isCuba || !hasAnyLicense)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPopular
                              ? accentColor
                              : Colors.white10,
                          foregroundColor: isPopular
                              ? Colors.white
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          context.t('select_plan'),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                ] else if (isCurrent && !isCuba) ...[
                  // Renew Button for Non-Cuba (Ads)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: accentColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        context.t('plan_renew'),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isCurrent)
            Positioned(
              top: 0,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  context.t('active_plan_banner'),
                  style: GoogleFonts.outfit(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            )
          else if (isPopular)
            Positioned(
              top: 0,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  context.t('popular'),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPaymentMethodsDialog(
    BuildContext context,
    LicenseType targetLicense,
  ) {
    Provider.of<AppProvider>(
      context,
      listen: false,
    ); // Listen false? No, we might want to check isCuba updates?
    // Actually we are inside a function. Dialog builder needs its own context or Consumer if we want updates.
    // Provider.of outside is fine for reading initial state, but if user toggles region inside dialog?
    // I'll put Consumer in dialog.

    showDialog(
      context: context,
      builder: (ctx) => Consumer<AppProvider>(
        builder: (innerContext, provider, _) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              context.t('payment_methods_title'),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: provider.paymentMethods.map((method) {
                  return Opacity(
                    opacity: method.isVisible ? 1.0 : 0.0,
                    child: method.isVisible
                        ? Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: ListTile(
                              leading:
                                  method.iconAsset.endsWith(
                                    '.png',
                                  ) // Crude check, assume asset
                                  ? Image.asset(
                                      method.iconAsset,
                                      width: 32,
                                      height: 32,
                                      errorBuilder: (c, e, s) => const Icon(
                                        Icons.payment,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.payment,
                                      color: Colors.white,
                                    ),
                              title: Text(
                                method.id.contains('test')
                                    ? context.t('test_method')
                                    : method.id == 'watch_ads'
                                    ? context.t('pay_watch_ads')
                                    : method.name,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () async {
                                if (!method.isEnabled) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.t('payment_disabled'),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (method.id == 'watch_ads') {
                                  Navigator.of(innerContext).pop();
                                  provider.setAdTargetLicense(targetLicense);
                                  _showAdWatcherDialog(context, targetLicense);
                                  return;
                                }

                                // 1. Close the "Select Payment Method" dialog

                                // 1. Close the "Select Payment Method" dialog
                                // Use innerContext because it belongs to the dialog
                                Navigator.of(innerContext).pop();

                                if (method.isTest) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${context.t('payment_test_success')} (${targetLicense.name.toUpperCase()})',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }

                                // 2. Show Loading Dialog for Apklis (non-test)
                                if (!method.isTest) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    useRootNavigator:
                                        true, // Ensure we use root navigator
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
                                                  'Procesando pago...',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                // Capture Navigator (Root) and Messenger to use after async gap safely
                                final navigator = Navigator.of(
                                  context,
                                  rootNavigator: true,
                                );
                                final messenger = ScaffoldMessenger.of(context);

                                // 3. Perform the async Purchase operation
                                String? errorMsg;
                                try {
                                  errorMsg = await provider.simulatePayment(
                                    method.id,
                                    targetLicense,
                                  );
                                } catch (e) {
                                  errorMsg = 'Error inesperado: $e';
                                } finally {
                                  // 4. ALWAYS close the Loading Dialog
                                  if (!method.isTest) {
                                    // We use the captured navigator to ensure we pop the dialog
                                    // regardless of current context state if possible.
                                    navigator.pop();
                                  }
                                }

                                // Check OUTER context (Screen) which behaves correctly
                                if (!context.mounted) return;

                                // 5. Handle Result
                                if (errorMsg == null) {
                                  // Success
                                  if (!method.isTest) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${context.t('payment_success_title')} (${targetLicense.name.toUpperCase()})',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } else {
                                  // Failure - Parse logic
                                  String displayError = errorMsg;

                                  // 1. Check for specific Apklis error codes/strings
                                  if (displayError.contains(
                                        'pending_payment',
                                      ) ||
                                      displayError.contains(
                                        'El pago de la licencia está pendiente',
                                      )) {
                                    displayError = context.t('payment_pending');
                                  } else if (displayError
                                          .toLowerCase()
                                          .contains('cancel') ||
                                      displayError.toLowerCase().contains(
                                        'aborted',
                                      )) {
                                    displayError = context.t(
                                      'payment_cancelled',
                                    );
                                  } else {
                                    // 2. Try cleaning JSON format if it looks like JSON
                                    try {
                                      if (displayError.trim().startsWith('{')) {
                                        final detailMatch = RegExp(
                                          r'"detail"\s*:\s*"([^"]+)"',
                                        ).firstMatch(displayError);
                                        if (detailMatch != null) {
                                          displayError =
                                              detailMatch.group(1) ??
                                              displayError;
                                        }
                                      }
                                    } catch (_) {}

                                    // 3. Map cleaned strings to localized messages
                                    if (displayError.contains('credentials') ||
                                        (displayError.contains('403') &&
                                            displayError.contains(
                                              'autenticación',
                                            )) ||
                                        displayError.contains(
                                          'Autenticación requerida',
                                        )) {
                                      displayError = context.t('auth_required');
                                    } else if (displayError.contains(
                                          'pending_payment',
                                        ) ||
                                        displayError.contains('pendiente')) {
                                      // Check again in case JSON parsing revealed it
                                      displayError = context.t(
                                        'payment_pending',
                                      );
                                    } else if (displayError.contains(
                                          'Network',
                                        ) ||
                                        displayError.contains(
                                          'SocketException',
                                        )) {
                                      displayError = context.t(
                                        'connection_error',
                                      );
                                    }
                                  }

                                  // Final cleanup
                                  displayError = displayError
                                      .replaceAll('"}', '')
                                      .replaceAll('{"', '')
                                      .replaceAll('"', '');

                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(displayError),
                                      backgroundColor:
                                          displayError ==
                                                  context.t(
                                                    'payment_cancelled',
                                                  ) ||
                                              displayError ==
                                                  context.t('already_paid')
                                          ? Colors.orange
                                          : Colors.red,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              },
                            ),
                          )
                        : const SizedBox.shrink(),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(innerContext).pop(),
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

  void _showAdWatcherDialog(BuildContext context, LicenseType targetLicense) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Consumer<AppProvider>(
        builder: (context, provider, __) {
          final watched = provider.adsWatched;
          final target = provider.adsTarget;
          final isReady = provider.adService.isAdReady;

          if (watched >= target) {
            // Auto-close on success
            Future.delayed(Duration.zero, () {
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context
                          .t('msg_license_activated')
                          .replaceAll(
                            '{license}',
                            targetLicense.name.toUpperCase(),
                          ),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            });
            return const SizedBox.shrink();
          }

          return PopScope(
            canPop: true,
            child: AlertDialog(
              backgroundColor: const Color(0xFF1E1E2C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Column(
                children: [
                  const Icon(
                    Icons.ondemand_video_rounded,
                    color: Colors.amberAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.t('dialog_watch_ads_title'),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
                          targetLicense.name.toUpperCase(),
                        ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: watched / target,
                      minHeight: 12,
                      backgroundColor: Colors.white12,
                      color: Colors.amberAccent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "$watched / $target",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isReady
                          ? () {
                              provider.adService.showRewardedAd(
                                onUserEarnedReward: () {
                                  provider.incrementAdsWatched();
                                },
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: isReady
                          ? const Icon(Icons.play_arrow_rounded)
                          : const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black54,
                              ),
                            ),
                      label: Text(
                        isReady
                            ? context.t('btn_watch_video')
                            : context.t('btn_loading_ad'),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.t('btn_close'),
                    style: GoogleFonts.outfit(color: Colors.white54),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
