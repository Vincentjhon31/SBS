import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/admin/presentation/audit_log_screen.dart';
import '../features/admin/presentation/broadcast_screen.dart';
import '../features/admin/presentation/reports_screen.dart';
import '../features/admin/presentation/system_settings_screen.dart';
import '../features/admin/presentation/users_screen.dart';
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
import '../features/landing/presentation/landing_screen.dart';
import '../features/items/presentation/departments_screen.dart';
import '../features/items/presentation/item_calendar_screen.dart';
import '../features/items/presentation/item_form_screen.dart';
import '../features/items/presentation/items_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/about_screen.dart';
import '../features/settings/presentation/privacy_policy_screen.dart';
import '../features/settings/presentation/profile_info_screen.dart';
import '../features/settings/presentation/security_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'app_shell.dart';

abstract final class AppRoutes {
  static const landing = '/';
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const items = '/items';
  static const borrowItems = '/items/borrow';
  static const scheduleItems = '/items/schedule';
  static const itemNew = '/items/new';
  static const itemEdit = '/items/edit';
  static const itemCalendar = '/items/calendar';
  static const departments = '/items/departments';
  static const users = '/admin/users';
  static const auditLog = '/admin/audit-log';
  static const broadcast = '/admin/broadcast';
  static const reports = '/admin/reports';
  static const systemSettings = '/admin/settings';
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
  static const profileInfo = '/profile/info';
  static const security = '/profile/security';
  static const privacyPolicy = '/profile/privacy';
  static const about = '/profile/about';
}

/// The router's Navigator.
///
/// App-wide listeners (the in-app notification modal, the deactivated-
/// account gate) live in MaterialApp.router's `builder`, which sits
/// *above* this Navigator — so their own BuildContext has no Navigator
/// ancestor and showDialog() throws. They reach the Navigator through
/// this key instead.
final rootNavigatorKey = GlobalKey<NavigatorState>();

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
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = session() != null;
      // The marketing landing page only makes sense on web (native users
      // already "installed" the app from somewhere and should go straight
      // to sign-in) and only while signed out.
      final onAuthRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          (kIsWeb && state.matchedLocation == AppRoutes.landing);
      if (!signedIn) {
        if (onAuthRoute) return null;
        return kIsWeb ? AppRoutes.landing : AppRoutes.login;
      }
      if (onAuthRoute || state.matchedLocation == AppRoutes.splash) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.landing,
        builder: (context, state) => const LandingScreen(),
      ),
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
        path: AppRoutes.borrowItems,
        builder: (context, state) =>
            const ItemsScreen(flowFilter: ItemFlowType.borrow),
      ),
      GoRoute(
        path: AppRoutes.scheduleItems,
        builder: (context, state) =>
            const ItemsScreen(flowFilter: ItemFlowType.schedule),
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
        path: AppRoutes.departments,
        builder: (context, state) => const DepartmentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.users,
        builder: (context, state) => const UsersScreen(),
      ),
      GoRoute(
        path: AppRoutes.auditLog,
        builder: (context, state) => const AuditLogScreen(),
      ),
      GoRoute(
        path: AppRoutes.broadcast,
        builder: (context, state) => const BroadcastScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.systemSettings,
        builder: (context, state) => const SystemSettingsScreen(),
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
        path: AppRoutes.profileInfo,
        builder: (context, state) => const ProfileInfoScreen(),
      ),
      GoRoute(
        path: AppRoutes.security,
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const AboutScreen(),
      ),
    ],
  );
});
