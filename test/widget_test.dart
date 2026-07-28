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
    // Not pumpAndSettle: the default "blob" backdrop animates on an
    // endless loop, so the tree never goes quiescent and pumpAndSettle
    // would spin until it times out.
    await tester.pump(const Duration(seconds: 1));

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
    // Not pumpAndSettle: the default "blob" backdrop animates on an
    // endless loop, so the tree never goes quiescent and pumpAndSettle
    // would spin until it times out.
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('New citizen borrower? Register here'));
    // Not pumpAndSettle (see above) — one pump to process the tap's
    // onPressed/navigation, then one to carry the push transition to
    // completion.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Citizen Registration'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });
}
