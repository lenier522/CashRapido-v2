import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/localization_service.dart';
import 'default_license_screen.dart';
import '../services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../widgets/design/cash_button.dart';

/// Pantalla de bienvenida / introducción (onboarding).
///
/// Se muestra una sola vez, antes de la licencia por defecto, a los usuarios
/// que todavía no han completado la introducción. Al finalizar se guarda la
/// preferencia `seenOnboarding` (misma clave que ya usaba la app) y se
/// continúa hacia `DefaultLicenseScreen`, conservando la navegación original.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  /// Ancho máximo del contenido para no estirar los textos en tablet.
  static const double _maxContentWidth = 460;

  @override
  void initState() {
    super.initState();
    // Comportamiento existente: se solicita el permiso de notificaciones al
    // iniciar la introducción en móvil (Android/iOS). Se conserva tal cual.
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      NotificationService().requestPermissions();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<OnboardingData> _buildPages(BuildContext context) {
    return [
      OnboardingData(
        title: context.t('onboarding_title_1'),
        description: context.t('onboarding_desc_1'),
        animation: 'assets/animations/finance_1.json',
      ),
      OnboardingData(
        title: context.t('onboarding_title_2'),
        description: context.t('onboarding_desc_2'),
        animation: 'assets/animations/finance_2.json',
      ),
      OnboardingData(
        title: context.t('onboarding_title_3'),
        description: context.t('onboarding_desc_3'),
        animation: 'assets/animations/robot.json',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<OnboardingData> pages = _buildPages(context);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxHeight < 640;
            final double horizontalPadding = constraints.maxWidth < 340
                ? AppSpacing.lg
                : AppSpacing.xl;

            return Column(
              children: [
                _buildBrandHeader(context, isCompact),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildSlide(
                        pages[index],
                        constraints,
                        horizontalPadding,
                        isCompact,
                      );
                    },
                  ),
                ),
                _buildBottomControls(context, pages.length, isCompact),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Encabezado con la identidad de CashRapido (nombre + marca).
  Widget _buildBrandHeader(BuildContext context, bool isCompact) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        isCompact ? AppSpacing.md : AppSpacing.xl,
        AppSpacing.xl,
        0,
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: AppRadius.radiusMd,
                boxShadow: AppShadows.primaryButton,
              ),
              child: const Icon(
                Icons.savings_rounded,
                size: 22,
                color: AppColors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Flexible + elipsis: con escala de texto grande en pantallas
            // estrechas la marca se recorta en vez de desbordar la fila.
            Flexible(
              child: Text(
                'CashRapido',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(
    OnboardingData data,
    BoxConstraints constraints,
    double horizontalPadding,
    bool isCompact,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final Color textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    // Tamaño de la ilustración acotado por ancho y alto disponibles.
    double illustrationSize = constraints.maxWidth * 0.62;
    final double heightCap = isCompact
        ? constraints.maxHeight * 0.32
        : 264.0;
    if (illustrationSize > heightCap) illustrationSize = heightCap;
    if (illustrationSize > 264) illustrationSize = 264;
    if (illustrationSize < 132) illustrationSize = 132;

    final double contentWidth =
        constraints.maxWidth > _maxContentWidth
        ? _maxContentWidth
        : constraints.maxWidth - horizontalPadding * 2;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: isCompact ? AppSpacing.md : AppSpacing.lg,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIllustration(data, illustrationSize, isDark),
              SizedBox(height: isCompact ? AppSpacing.xl : AppSpacing.xxl),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                data.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ilustración sobre un panel suave para que sea legible en ambos temas.
  Widget _buildIllustration(
    OnboardingData data,
    double size,
    bool isDark,
  ) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark2 : AppColors.primarySurface,
          borderRadius: AppRadius.radiusXxxl,
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          boxShadow: isDark ? AppShadows.darkCard : AppShadows.card,
        ),
        padding: EdgeInsets.all(size * 0.12),
        child: Lottie.asset(
          data.animation,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.auto_awesome_rounded,
              size: size * 0.35,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiary,
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    int pageCount,
    bool isCompact,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isLast = _currentIndex == pageCount - 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        isCompact ? AppSpacing.lg : AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: '${_currentIndex + 1} / $pageCount',
            container: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pageCount, (index) {
                final bool isActive = _currentIndex == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: isActive ? 22 : 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.surfaceDark3
                              : AppColors.primaryLight),
                    borderRadius: AppRadius.radiusXs,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          CashButton(
            label: isLast
                ? context.t('onboarding_get_started')
                : context.t('continue_btn'),
            height: 54,
            onPressed: isLast ? _completeOnboarding : _goToNextPage,
          ),
          // Salida directa a la app sin recorrer las tres páginas. No se
          // muestra en la última, donde el botón principal ya entra a la app.
          if (!isLast) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: _completeOnboarding,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 40),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              child: Text(context.t('skip')),
            ),
          ],
        ],
      ),
    );
  }

  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DefaultLicenseScreen()),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final String animation;

  OnboardingData({
    required this.title,
    required this.description,
    required this.animation,
  });
}
