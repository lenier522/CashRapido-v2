import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'localization_service.dart';

class FeedbackService {
  static const String _kLastOpenDate = 'feedback_last_open_date';
  static const String _kDailyOpenCount = 'feedback_daily_open_count';
  static const String _kLastShownDate = 'feedback_last_shown_date';

  static const String _kTelegramUrl = 'https://t.me/+De8fwjWq94xjMzBh';
  static const String _kApklisUrl =
      'https://apklis.cu/application/cu.lenier.cashrapido';
  static const String _kPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=cu.lenier.cashrapido';

  /// Call this when the app starts or resumes
  static Future<void> checkAndShowFeedback(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayString = "${now.year}-${now.month}-${now.day}"; // YYYY-MM-DD

    String? lastOpenDate = prefs.getString(_kLastOpenDate);
    int dailyOpenCount = prefs.getInt(_kDailyOpenCount) ?? 0;
    String? lastShownDate = prefs.getString(_kLastShownDate);

    // Reset counter if new day
    if (lastOpenDate != todayString) {
      dailyOpenCount = 0;
      lastOpenDate = todayString;
    }

    // Increment open count
    dailyOpenCount++;

    // Save state
    await prefs.setString(_kLastOpenDate, lastOpenDate!);
    await prefs.setInt(_kDailyOpenCount, dailyOpenCount);

    // Check condition: >= 5 opens today AND not shown today
    if (dailyOpenCount >= 5 && lastShownDate != todayString) {
      if (context.mounted) {
        _showFeedbackDialog(context);
        // Mark as shown today
        await prefs.setString(_kLastShownDate, todayString);
      }
    }
  }

  static void _showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const FeedbackPrompt(),
    );
  }

  static Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }
}

class FeedbackPrompt extends StatelessWidget {
  const FeedbackPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E2C).withOpacity(0.95)
                : Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon (Telegram logo style or Star)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0088cc).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Color(0xFF0088cc), // Telegram Blue
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                context.t('feedback_title'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E1E2C),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                context.t('feedback_description'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Telegram Button (Primary)
              _buildStoreButton(
                context,
                label: context.t('join_telegram'),
                icon: Icons.telegram,
                color: const Color(0xFF0088cc),
                onTap: () =>
                    FeedbackService._launchUrl(FeedbackService._kTelegramUrl),
                isPrimary: true,
              ),
              const SizedBox(height: 12),

              // Stores Row
              Row(
                children: [
                  Expanded(
                    child: _buildStoreButton(
                      context,
                      label: context.t('apklis'),
                      icon: Icons.shop_two, // Generic store icon
                      color: Colors
                          .blueGrey, // Apklis doesn't have a standard color, maybe generic
                      onTap: () => FeedbackService._launchUrl(
                        FeedbackService._kApklisUrl,
                      ),
                      isSmall: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStoreButton(
                      context,
                      label: context.t('play_store'),
                      icon: Icons.android,
                      color: const Color(0xFF0F9D58), // Google Green
                      onTap: () => FeedbackService._launchUrl(
                        FeedbackService._kPlayStoreUrl,
                      ),
                      isSmall: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  context.t('maybe_later'),
                  style: GoogleFonts.outfit(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isSmall = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: isSmall ? 10 : 14,
            horizontal: 16,
          ),
          decoration: BoxDecoration(
            color: isPrimary ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: isPrimary
                ? null
                : Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.white : color,
                size: isSmall ? 20 : 24,
              ),
              const SizedBox(width: 8),
              Flexible(
                // Prevent overflow
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: isPrimary ? Colors.white : color,
                    fontWeight: FontWeight.bold,
                    fontSize: isSmall ? 14 : 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
