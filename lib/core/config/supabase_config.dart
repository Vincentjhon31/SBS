import 'package:flutter/foundation.dart';

/// Supabase connection settings.
///
/// Defaults target the local Supabase stack (`supabase start`):
///   - Android emulator reaches the host machine via 10.0.2.2
///   - web/desktop on the same machine use 127.0.0.1
/// Override at build time for a real device (use your PC's LAN IP) or a
/// hosted project:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
abstract final class SupabaseConfig {
  static const _urlOverride = String.fromEnvironment('SUPABASE_URL');

  static String get url {
    if (_urlOverride.isNotEmpty) return _urlOverride;
    final onAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return onAndroid ? 'http://10.0.2.2:54321' : 'http://127.0.0.1:54321';
  }

  // The well-known local development anon key used by the Supabase CLI —
  // not a secret. Hosted projects must supply their own via --dart-define.
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );
}
