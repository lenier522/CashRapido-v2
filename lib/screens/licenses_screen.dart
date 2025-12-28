import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cashrapido/services/localization_service.dart';

class LicensesScreen extends StatelessWidget {
  // Set this to true for the Cuban version, false for the International version
  static const bool isCuba = true;

  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Holiday Promotion Check (Until Jan 10th midnight, 2026)
    final isPromoActive = DateTime.now().isBefore(DateTime(2026, 1, 11));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          context.t('licenses_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                    vertical: 120,
                  ),
                  children: [
                    _buildLicenseCard(
                      context,
                      title: context.t('license_personal'),
                      price: isCuba ? '\$500' : '\$5',
                      currency: isCuba ? 'CUP' : 'USD',
                      period: context.t('month_short'),
                      features: [
                        context.t('features_basic'),
                        context.t('features_device_1'),
                        context.t('features_support_basic'),
                      ],
                      color: Colors.blueGrey.shade400,
                      accentColor: Colors.blueGrey,
                    ),
                    const SizedBox(height: 24),
                    _buildLicenseCard(
                      context,
                      title: context.t('license_pro'),
                      price: isCuba ? '\$1000' : '\$10',
                      currency: isCuba ? 'CUP' : 'USD',
                      period: context.t('month_short'),
                      features: [
                        context.t('features_all_personal'),
                        context.t('features_multi_device'),
                        context.t('features_support_priority'),
                        context.t('features_advanced_analytics'),
                      ],
                      color: const Color(0xFFBB86FC), // Premium Purple
                      accentColor: Colors.deepPurpleAccent,
                      isPopular: true,
                    ),
                    const SizedBox(height: 24),
                    _buildLicenseCard(
                      context,
                      title: context.t('license_enterprise'),
                      price: isCuba ? '\$2000' : '\$20',
                      currency: isCuba ? 'CUP' : 'USD',
                      period: context.t('month_short'),
                      features: [
                        context.t('features_all_pro'),
                        context.t('features_unlimited_users'),
                        context.t('features_api_access'),
                        context.t('features_support_247'),
                      ],
                      color: Colors.amberAccent,
                      accentColor: Colors.orangeAccent,
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPopular ? accentColor : Colors.white10,
                      foregroundColor: isPopular ? Colors.white : Colors.white,
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
              ],
            ),
          ),
          if (isPopular)
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
}
