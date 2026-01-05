import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:google_fonts/google_fonts.dart';
import 'localization_service.dart';

class FeatureTour {
  final BuildContext context;
  final GlobalKey fabKey;
  final GlobalKey navBarKey;
  final Function(int) onNavigate;

  FeatureTour({
    required this.context,
    required this.fabKey,
    required this.navBarKey,
    required this.onNavigate,
  });

  void show() {
    late TutorialCoachMark tutorialCoachMark;

    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Theme.of(context).colorScheme.primary.withOpacity(0.8),
      textSkip: "SKIP", // Fallback, we use custom widget
      paddingFocus: 10,
      opacityShadow: 0.8,
      hideSkip: true, // We strictly use our own skip widget
      skipWidget: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextButton(
              onPressed: () {
                tutorialCoachMark.skip();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.black54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                context.t('skip'),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
      onFinish: () {
        print("Tour finished");
      },
      onClickTarget: (target) {
        print('Clicked target: $target');
        tutorialCoachMark.next();
      },
      onClickOverlay: (target) {
        print('Clicked overlay: $target');
        tutorialCoachMark.next();
      },
      onSkip: () {
        print("Tour skipped");
        return true;
      },
    );

    tutorialCoachMark.show(context: context);
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    // 1. FAB - Add Transaction
    targets.add(
      TargetFocus(
        identify: "fabKey",
        keyTarget: fabKey,
        enableOverlayTab: true,
        enableTargetTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTourContent(
                context.t('tour_fab_title'),
                context.t('tour_fab_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 2. Bottom Navigation
    targets.add(
      TargetFocus(
        identify: "navBarKey",
        keyTarget: navBarKey,
        enableOverlayTab: true,
        enableTargetTab: false,
        shape: ShapeLightFocus.RRect,
        radius: 5,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTourContent(
                context.t('tour_navbar_title'),
                context.t('tour_navbar_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 3. Navigate to Wallet tab
    targets.add(
      TargetFocus(
        identify: "walletTab",
        keyTarget: navBarKey,
        enableOverlayTab: true,
        enableTargetTab: false,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              // Auto-navigate to Wallet
              Future.delayed(const Duration(milliseconds: 300), () {
                onNavigate(1);
              });
              return _buildTourContent(
                context.t('tour_wallet_nav_title'),
                context.t('tour_wallet_nav_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 4. Navigate to Stats tab
    targets.add(
      TargetFocus(
        identify: "statsTab",
        keyTarget: navBarKey,
        enableOverlayTab: true,
        enableTargetTab: false,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              // Auto-navigate to Stats
              Future.delayed(const Duration(milliseconds: 300), () {
                onNavigate(2);
              });
              return _buildTourContent(
                context.t('tour_stats_nav_title'),
                context.t('tour_stats_nav_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 5. Navigate to Settings tab
    targets.add(
      TargetFocus(
        identify: "settingsTab",
        keyTarget: navBarKey,
        enableOverlayTab: true,
        enableTargetTab: false,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              // Auto-navigate to Settings
              Future.delayed(const Duration(milliseconds: 300), () {
                onNavigate(3);
              });
              return _buildTourContent(
                context.t('tour_settings_nav_title'),
                context.t('tour_settings_nav_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 6. Final step - Return to Home
    targets.add(
      TargetFocus(
        identify: "finalStep",
        keyTarget: navBarKey,
        enableOverlayTab: true,
        enableTargetTab: false,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              // Return to Home
              Future.delayed(const Duration(milliseconds: 300), () {
                onNavigate(0);
              });
              return _buildTourContent(
                "¡Tour Completado!",
                "Has explorado todas las funciones principales de CashRapido. ¡Comienza a gestionar tus finanzas!",
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }

  Widget _buildTourContent(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
