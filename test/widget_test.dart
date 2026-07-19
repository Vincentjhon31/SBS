import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs/app/app.dart';
import 'package:sbs/core/constants/app_constants.dart';

void main() {
  testWidgets('app boots to splash and lands on home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SBSApp()));

    expect(find.text(AppConstants.appFullName), findsOneWidget);

    // Let the splash timer fire and the route transition settle.
    await tester.pump(AppConstants.splashDuration);
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(
      find.text('v${AppConstants.appVersion} — Phase 1 foundation'),
      findsOneWidget,
    );
  });
}
