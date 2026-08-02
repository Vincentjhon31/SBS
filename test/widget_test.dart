import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs/app/app.dart';
import 'package:sbs/features/auth/data/auth_providers.dart';

/// Boots the app signed out, with no live Supabase behind it.
Future<void> _pumpSignedOut(WidgetTester tester) async {
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
  // Not pumpAndSettle: the default "blob" backdrop animates on an endless
  // loop, so the tree never goes quiescent and pumpAndSettle would spin
  // until it times out. The entrance animations also need a beat to land.
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('signed-out boot redirects to the login screen', (tester) async {
    await _pumpSignedOut(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });

  testWidgets('register link navigates to citizen registration', (
    tester,
  ) async {
    await _pumpSignedOut(tester);

    await tester.tap(find.text('Register'));
    // One pump to process the tap's onPressed/navigation, then one to
    // carry the transition and entrance animations to completion.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
