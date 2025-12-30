import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/localization_service.dart';
import 'licenses_screen.dart';
import 'main_screen.dart';

class DefaultLicenseScreen extends StatelessWidget {
  const DefaultLicenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0F0F0F),
                const Color(0xFF1A1A2E), // Deep Blue-Black
                const Color(0xFF16213E), // Dark Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      // Header Icon with Glow
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.4),
                                blurRadius: 30,
                                offset: const Offset(0, 0),
                              ),
                            ],
                            gradient: LinearGradient(
                              colors: [Colors.blueGrey.shade800, Colors.black],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.security_outlined,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title & Status
                      Text(
                        context.t('default_license_title'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            context.t(
                              'default_license_desc',
                            ), // "Licencia Básica (Gratuita)"
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Glassmorphism Card for Restrictions
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t(
                                'current_plan_limits',
                              ), // "Límites del Plan"
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white54,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildRestrictionRow(
                              context,
                              Icons.credit_card,
                              context.t('limit_card_1'),
                              isLocked: false,
                            ),
                            const SizedBox(height: 16),
                            _buildRestrictionRow(
                              context,
                              Icons.bar_chart_rounded,
                              context.t(
                                'limit_no_charts',
                              ), // "Sin gráficas avanzadas"
                              isLocked: true,
                            ),
                            const SizedBox(height: 16),
                            _buildRestrictionRow(
                              context,
                              Icons.cloud_off_rounded,
                              context.t(
                                'limit_no_backup',
                              ), // "Sin respaldo en la nube"
                              isLocked: true,
                            ),
                            const SizedBox(height: 16),
                            _buildRestrictionRow(
                              context,
                              Icons.lock_outline,
                              context.t('limit_restricted_features'),
                              isLocked: true,
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),
                      const SizedBox(height: 32),

                      // Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LicensesScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 8,
                                shadowColor: const Color(
                                  0xFF6B4226,
                                ).withOpacity(0.5),
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFD4AF37), // Metallic Gold
                                      Color(0xFFFFD700), // Gold
                                      Color(0xFFD4AF37), // Metallic Gold
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Text(
                                    context.t('upgrade_btn'),
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black, // Contrast on Gold
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const MainScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white54,
                              ),
                              child: Text(
                                context.t('continue_btn'),
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestrictionRow(
    BuildContext context,
    IconData icon,
    String text, {
    required bool isLocked,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isLocked
                ? Colors.red.withOpacity(0.1)
                : Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isLocked ? Colors.redAccent : Colors.white70,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: isLocked ? Colors.white60 : Colors.white,
              fontWeight: isLocked ? FontWeight.normal : FontWeight.w500,
              decoration: isLocked ? TextDecoration.lineThrough : null,
              decorationColor: Colors.redAccent.withOpacity(0.5),
            ),
          ),
        ),
        if (isLocked) Icon(Icons.lock_outline, color: Colors.white24, size: 18),
      ],
    );
  }
}
