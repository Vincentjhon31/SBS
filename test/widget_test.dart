import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs/app/app.dart';
import 'package:sbs/features/auth/data/auth_providers.dart';

void main() {
  testWidgets('signed-out boot redirects to the login screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // No live Supabase in widget tests: no session, silent auth stream.
          sessionGetterProvider.overrideWithValue(() => null),
          authStateStreamProvider.overrideWithValue(const Stream.empty()),
        ],
        child: const SBSApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('New citizen borrower? Register here'), findsOneWidget);
  });

  testWidgets('register link navigates to citizen registration', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionGetterProvider.overrideWithValue(() => null),
          authStateStreamProvider.overrideWithValue(const Stream.empty()),
        ],
        child: const SBSApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New citizen borrower? Register here'));
    await tester.pumpAndSettle();

    expect(find.text('Citizen Registration'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });
}
