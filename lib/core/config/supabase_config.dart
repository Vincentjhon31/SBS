/// Supabase connection settings.
///
/// Defaults target the HOSTED SBS project — plain `flutter run` /
/// `flutter build apk` just work against it, no flags needed.
///
/// To point at the local Docker Supabase stack (`supabase start`) for
/// development/testing instead, override both at build time:
///   flutter run --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=`your local anon key`
/// On the Android emulator, local Docker is reached via 10.0.2.2 instead
/// of 127.0.0.1; on a physical device, use your PC's LAN IP.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ppbrkgnikipfhppvdwfp.supabase.co',
  );

  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_jkhW75i_rCCDqBlvmU3BYw_NnJyH43N',
  );
}
