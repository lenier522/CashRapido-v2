import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cashrapido/screens/onboarding_screen.dart';
import 'package:cashrapido/services/localization_service.dart';

void main() {
  testWidgets('Onboarding loads correctly', (WidgetTester tester) async {
    // Build the OnboardingScreen directly with localizations
    await tester.pumpWidget(
      MaterialApp(
        home: const OnboardingScreen(),
        locale: const Locale('es'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es'), Locale('en'), Locale('fr')],
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));

    // Verify that the OnboardingScreen is present
    expect(find.byType(OnboardingScreen), findsOneWidget);

    // Verify that the first slide title is present
    expect(find.text('Control Total'), findsOneWidget);

    // Verify that the counter '0' (from old template) is NOT present
    expect(find.text('0'), findsNothing);
  });
}
