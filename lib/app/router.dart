import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/approvals/data/approvals_models.dart';
import '../features/approvals/presentation/approvals_screen.dart';
import '../features/approvals/presentation/evidence_capture_screen.dart';
import '../features/approvals/presentation/evidence_viewer_screen.dart';
import '../features/auth/data/auth_providers.dart';
import '../features/auth/presentation/citizen_register_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/borrowing/presentation/my_requests_screen.dart';
import '../features/borrowing/presentation/request_form_screen.dart';
import '../features/borrowing/presentation/walkin_request_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/items/data/items_models.dart';
import '../features/items/presentation/item_calendar_screen.dart';
import '../features/items/presentation/item_form_screen.dart';
import '../features/items/presentation/items_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/data_export_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'app_shell.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const items = '/items';
  static const itemNew = '/items/new';
  static const itemEdit = '/items/edit';
  static const itemCalendar = '/items/calendar';
  static const requests = '/requests';
  static const requestNew = '/requests/new';
  static const walkinNew = '/requests/walkin';
  static const approvals = '/approvals';
  static const approvalDetail = '/approvals/detail';
  static const evidenceCapture = '/approvals/capture';
  static const evidenceView = '/evidence';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const settings = '/settings';
  static const dataExport = '/settings/export';
}

/// Re-runs the router redirect whenever the auth state changes.
class _StreamRefresh extends ChangeNotifier {
  _StreamRefresh(Stream<AuthState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _StreamRefresh(ref.watch(authStateStreamProvider));
  ref.onDispose(refresh.dispose);
  final session = ref.watch(sessionGetterProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = session() != null;
      final onAuthRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;
      if (!signedIn) return onAuthRoute ? null : AppRoutes.login;
      if (onAuthRoute || state.matchedLocation == AppRoutes.splash) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const CitizenRegisterScreen(),
      ),

      // ── Main tabs — one shared Scaffold/NavigationBar, instant switches ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeOrDashboard(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.requests,
                builder: (context, state) => const MyRequestsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.items,
                builder: (context, state) => const ItemsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.approvals,
                builder: (context, state) => const ApprovalsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Everything below is pushed on top of the active tab ──
      GoRoute(
        path: AppRoutes.requestNew,
        // extra is an OPTIONAL preselected Item — unlike itemEdit/
        // itemCalendar, this route must keep working with no extra at all
        // (the "New request" FAB doesn't pass one).
        builder: (context, state) => RequestFormScreen(
          preselectedItem: state.extra is Item ? state.extra as Item : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.walkinNew,
        builder: (context, state) => const WalkInRequestScreen(),
      ),
      GoRoute(
        path: AppRoutes.itemNew,
        builder: (context, state) => const ItemFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.itemEdit,
        redirect: (context, state) =>
            state.extra is Item ? null : AppRoutes.items,
        builder: (context, state) => ItemFormScreen(item: state.extra as Item),
      ),
      GoRoute(
        path: AppRoutes.itemCalendar,
        redirect: (context, state) =>
            state.extra is Item ? null : AppRoutes.items,
        builder: (context, state) =>
            ItemCalendarScreen(item: state.extra as Item),
      ),
      GoRoute(
        path: AppRoutes.approvalDetail,
        redirect: (context, state) =>
            state.extra is PendingApproval ? null : AppRoutes.approvals,
        builder: (context, state) =>
            ApprovalDetailScreen(request: state.extra as PendingApproval),
      ),
      GoRoute(
        path: AppRoutes.evidenceCapture,
        redirect: (context, state) =>
            state.extra is EvidenceCaptureArgs ? null : AppRoutes.approvals,
        builder: (context, state) =>
            EvidenceCaptureScreen(args: state.extra as EvidenceCaptureArgs),
      ),
      GoRoute(
        path: AppRoutes.evidenceView,
        redirect: (context, state) =>
            state.extra is EvidenceViewArgs ? null : AppRoutes.home,
        builder: (context, state) =>
            EvidenceViewerScreen(args: state.extra as EvidenceViewArgs),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.dataExport,
        redirect: (context, state) =>
            state.extra is Map<String, dynamic> ? null : AppRoutes.settings,
        builder: (context, state) =>
            DataExportScreen(data: state.extra as Map<String, dynamic>),
      ),
    ],
  );
});
