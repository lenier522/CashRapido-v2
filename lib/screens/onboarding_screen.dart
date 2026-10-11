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

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  late final AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      NotificationService().requestPermissions();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final Color surfaceColor = isDark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;

    final List<OnboardingData> pages = [
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

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxHeight < 600;
            return Column(
              children: [
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
                      return _buildPage(pages[index], constraints, isCompact);
                    },
                  ),
                ),
                _buildBottomControls(pages.length, surfaceColor),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPage(
    OnboardingData data,
    BoxConstraints constraints,
    bool isCompact,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final Color textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    // Calculate responsive sizes
    final double horizontalPadding = constraints.maxWidth * 0.08;
    final int animationFlex = isCompact ? 2 : 3;
    final int textFlex = isCompact ? 1 : 2;
    final double topSpacing = isCompact ? AppSpacing.lg : AppSpacing.xl * 2;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: topSpacing),
          // Lottie Animation Area
          Expanded(
            flex: animationFlex,
            child: Center(
              child: Lottie.asset(
                data.animation,
                controller: _lottieController
                  ..duration = const Duration(seconds: 2)
                  ..repeat(),
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.movie_creation_outlined,
                    size: constraints.maxWidth * 0.3,
                    color: textSecondary.withValues(alpha: 0.5),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.xl),
          // Text Content
          Expanded(
            flex: textFlex,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    data.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      height: 1.2,
                    ),
                  ),
                ),
                SizedBox(height: isCompact ? AppSpacing.sm : AppSpacing.md),
                Flexible(
                  child: Text(
                    data.description,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? AppSpacing.sm : AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildBottomControls(int pageCount, Color surfaceColor) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Indicators
          Row(
            children: List.generate(
              pageCount,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                height: 8,
                width: _currentIndex == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? AppColors.primary
                      : (isDark
                            ? AppColors.primaryDark.withValues(alpha: 0.3)
                            : AppColors.primaryLight),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          // Next/Done Button - Fixed size circular button to avoid infinite width
          SizedBox(
            width: 56,
            height: 56,
            child: Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () {
                  if (_currentIndex == pageCount - 1) {
                    _completeOnboarding();
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: Center(
                  child: Icon(
                    _currentIndex == pageCount - 1
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
