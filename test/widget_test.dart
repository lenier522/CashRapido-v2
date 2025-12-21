import 'package:flutter_test/flutter_test.dart';
import 'package:cashrapido/main.dart';
import 'package:cashrapido/screens/onboarding_screen.dart';

void main() {
  testWidgets('Onboarding loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Force seenOnboarding to false to show the OnboardingScreen
    await tester.pumpWidget(const MyApp(seenOnboarding: false));

    // Verify that the OnboardingScreen is present
    expect(find.byType(OnboardingScreen), findsOneWidget);

    // Verify that the first slide title is present
    expect(find.text('Control Total'), findsOneWidget);

    // Verify that the counter '0' (from old template) is NOT present
    expect(find.text('0'), findsNothing);
  });
}
