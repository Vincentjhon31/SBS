/// Supabase connection settings.
///
/// Defaults target the local Supabase stack (`supabase start`) reached from
/// the Android emulator via 10.0.2.2. Override at build time for a real
/// device or a hosted project:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://10.0.2.2:54321',
  );

  // The well-known local development anon key used by the Supabase CLI —
  // not a secret. Hosted projects must supply their own via --dart-define.
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );
}
