import 'package:material_ui/material_ui.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'localization_service.dart';
import '../utils/tour_keys.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_shadows.dart';

/// Recorrido guiado de primer uso de la pantalla principal.
///
/// Destaca la tarjeta de balance, las acciones rápidas, la acción principal
/// (IA) y la barra de navegación, y va cambiando de pestaña para explicar cada
/// sección. La preferencia `seenFeatureTour` que decide si debe mostrarse se
/// gestiona en [MainScreen], no aquí.
class FeatureTour {
  final BuildContext context;
  final GlobalKey fabKey;
  final GlobalKey navBarKey;
  final Function(int) onNavigate;

  /// Evita programar la navegación automática más de una vez por paso cuando
  /// el contenido del objetivo se reconstruye durante el tour.
  final Set<String> _navigatedSteps = <String>{};

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
      colorShadow: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
      textSkip: context.t('skip'), // Fallback, usamos nuestro propio widget
      paddingFocus: 10,
      opacityShadow: 0.8,
      hideSkip: true, // We strictly use our own skip widget
      skipWidget: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextButton(
              onPressed: () {
                tutorialCoachMark.skip();
              },
              style: TextButton.styleFrom(
                backgroundColor: AppColors.surfaceDark2,
                foregroundColor: AppColors.textPrimaryDark,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusLg,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
              child: Text(
                context.t('skip'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
          ),
        ),
      ),
      onClickTarget: (target) {
        tutorialCoachMark.next();
      },
      onClickOverlay: (target) {
        tutorialCoachMark.next();
      },
    );

    tutorialCoachMark.show(context: context);
  }

  /// Programa la navegación automática de un paso una sola vez.
  void _navigateOnce(String identify, int index) {
    if (!_navigatedSteps.add(identify)) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      onNavigate(index);
    });
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];

    // 0.1 Balance Card
    targets.add(
      TargetFocus(
        identify: "balanceCardTarget",
        keyTarget: TourKeys.balanceCardKey,
        enableOverlayTab: true,
        enableTargetTab: false,
        shape: ShapeLightFocus.RRect,
        radius: 16,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTourContent(
                context,
                context.t('tour_balance_title'),
                context.t('tour_balance_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 0.2 Quick Actions - Transfer
    targets.add(
      TargetFocus(
        identify: "transferTarget",
        keyTarget: TourKeys.transferActionKey,
        enableOverlayTab: true,
        enableTargetTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTourContent(
                context,
                context.t('tour_quick_actions_title'),
                context.t('tour_quick_actions_desc'),
              );
            },
          ),
        ],
      ),
    );

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
                context,
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
                context,
                context.t('tour_navbar_title'),
                context.t('tour_navbar_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 3. Navigate to Home tab
    targets.add(
      TargetFocus(
        identify: "homeTab",
        keyTarget: navBarKey,
        enableOverlayTab: true,
        enableTargetTab: false,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              _navigateOnce("homeTab", 0);
              return _buildTourContent(
                context,
                context.t('tour_home_nav_title'),
                context.t('tour_home_nav_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 4. Navigate to Movements tab
    targets.add(
      TargetFocus(
        identify: "movementsTab",
        keyTarget: navBarKey,
        enableOverlayTab: true,
        enableTargetTab: false,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              _navigateOnce("movementsTab", 1);
              return _buildTourContent(
                context,
                context.t('tour_movements_nav_title'),
                context.t('tour_movements_nav_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 5. Navigate to Stats tab
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
              _navigateOnce("statsTab", 2);
              return _buildTourContent(
                context,
                context.t('tour_stats_nav_title'),
                context.t('tour_stats_nav_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 6. Navigate to Profile tab
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
              _navigateOnce("settingsTab", 3);
              return _buildTourContent(
                context,
                context.t('tour_profile_nav_title'),
                context.t('tour_profile_nav_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 7. Final step - Return to Home
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
              _navigateOnce("finalStep", 0);
              return _buildTourContent(
                context,
                context.t('tour_finish_title'),
                context.t('tour_finish_desc'),
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }

  Widget _buildTourContent(
    BuildContext context,
    String title,
    String description,
  ) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark2,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.borderDark),
        boxShadow: AppShadows.darkCard,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryDark,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
