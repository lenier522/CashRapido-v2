import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/localization_service.dart';
import 'main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
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
        animation: 'assets/animations/finance_3.json',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
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
                  return _buildPage(pages[index]);
                },
              ),
            ),
            _buildBottomControls(pages.length),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lottie Animation Area
          Expanded(
            flex: 3,
            child: Lottie.asset(
              data.animation,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.movie_creation_outlined,
                    size: 100,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 40),
          // Text Content
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(int pageCount) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Indicators
          Row(
            children: List.generate(
              pageCount,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 8),
                height: 8,
                width: _currentIndex == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? Colors.deepPurple
                      : Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          // Next/Done Button
          ElevatedButton(
            onPressed: () {
              if (_currentIndex == pageCount - 1) {
                _completeOnboarding();
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(20),
            ),
            child: Icon(
              _currentIndex == pageCount - 1
                  ? Icons.check
                  : Icons.arrow_forward,
              color: Colors.white,
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
    // Navigate to Home (Create a specialized replacement later)
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
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
