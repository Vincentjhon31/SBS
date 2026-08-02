import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Raw auth-change stream; overridable in tests so widgets never touch
/// Supabase.instance directly.
final authStateStreamProvider = Provider<Stream<AuthState>>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
);

final authStateChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authStateStreamProvider),
);

/// Getter (not a cached value) so the router redirect always sees the
/// current session.
final sessionGetterProvider = Provider<Session? Function()>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return () => client.auth.currentSession;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.username,
    required this.userType,
    required this.themeColor,
    required this.backgroundStyle,
    required this.isSuperadmin,
    required this.active,
  });

  final String id;
  final String fullName;

  /// The handle citizens sign in with. Null for staff, who sign in with
  /// an email, and for citizens registered before the username change.
  final String? username;

  final String userType;

  /// 'blue' | 'purple' | 'teal' | 'coral' | 'green' — server-synced accent
  /// color preference.
  final String themeColor;

  /// 'glossy' | 'blob' | 'solid' — server-synced background style
  /// preference (mirrors [themeColor]'s sync pattern).
  final String backgroundStyle;

  /// Cross-department oversight tier layered on top of staff — see
  /// supabase/migrations/*_superadmin.sql.
  final bool isSuperadmin;

  /// Reversible account deactivation (Users management) — false means
  /// staff have disabled this account; [AccountActiveGate] force-signs
  /// out and explains when this flips false under a live session.
  final bool active;

  bool get isStaff => userType == 'staff';

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        username: json['username'] as String?,
        userType: json['user_type'] as String,
        themeColor: json['theme_color'] as String? ?? 'blue',
        backgroundStyle: json['background_style'] as String? ?? 'glossy',
        isSuperadmin: json['is_superadmin'] as bool? ?? false,
        active: json['active'] as bool? ?? true,
      );
}

final myProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateChangesProvider);
  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) return null;
  final data =
      await client.from('profiles').select().eq('id', user.id).maybeSingle();
  return data == null ? null : Profile.fromJson(data);
});

/// Citizen verification status for the signed-in user; null for staff.
final myCitizenVerifiedProvider = FutureProvider<bool?>((ref) async {
  final profile = await ref.watch(myProfileProvider.future);
  if (profile == null || profile.isStaff) return null;
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('citizen_profiles')
      .select('verified')
      .eq('id', profile.id)
      .maybeSingle();
  return (data?['verified'] as bool?) ?? false;
});
