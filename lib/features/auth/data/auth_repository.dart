import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/offline_cache.dart';

/// Domain for the synthetic, never-delivered email a citizen's auth
/// account is registered under — email confirmations are disabled
/// project-wide, so nothing ever needs to reach this address. Must match
/// the formula in the `resolve_login_identifier` SQL function exactly.
const _citizenEmailDomain = 'citizens.sbs.internal';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Staff sign in with their real email; citizens sign in with their
  /// username. [identifier] is whichever the user typed — an `@` marks it
  /// as an email, otherwise it's resolved to the citizen's synthetic email
  /// via the `resolve_login_identifier` RPC first.
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final trimmed = identifier.trim();
    if (trimmed.contains('@')) {
      await _client.auth.signInWithPassword(
        email: trimmed,
        password: password,
      );
      return;
    }
    final email = await _client.rpc(
      'resolve_login_identifier',
      params: {'p_username': trimmed},
    ) as String?;
    if (email == null) {
      throw const AuthException('Invalid login credentials');
    }
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Signing out drops the offline cache too — these devices get shared
  /// between approvers, and the next one to sign in must not find the
  /// previous one's queue sitting on disk.
  Future<void> signOut() async {
    await _client.auth.signOut();
    await OfflineCache.clearAll();
  }

  /// Checks whether a username is free to register, for live validation
  /// on the registration form.
  Future<bool> isUsernameAvailable(String username) async {
    final available = await _client.rpc(
      'username_available',
      params: {'p_username': username},
    ) as bool;
    return available;
  }

  /// Citizen self-registration: creates the auth account (the DB trigger
  /// creates the profiles row), uploads the ID photo to the private
  /// id-photos bucket, then stores the verification details. Citizens have
  /// no email on file — the account is registered under a synthetic email
  /// derived from the username purely so Supabase Auth (which requires an
  /// identifier) has one; the app never uses it directly.
  Future<void> registerCitizen({
    required String username,
    required String password,
    required String fullName,
    required String contactNumber,
    required String idType,
    required String idNumber,
    required Uint8List idPhotoBytes,
    String idPhotoContentType = 'image/jpeg',
  }) async {
    final normalizedUsername = username.trim().toLowerCase();
    final response = await _client.auth.signUp(
      email: '$normalizedUsername@$_citizenEmailDomain',
      password: password,
      data: {
        'full_name': fullName,
        'username': normalizedUsername,
        'user_type': 'citizen',
      },
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Sign-up did not return a user.');
    }

    final photoPath = '${user.id}/id_photo.jpg';
    await _client.storage.from('id-photos').uploadBinary(
          photoPath,
          idPhotoBytes,
          fileOptions: FileOptions(
            contentType: idPhotoContentType,
            upsert: true,
          ),
        );

    await _client.from('citizen_profiles').insert({
      'id': user.id,
      'contact_number': contactNumber,
      'id_type': idType,
      'id_number': idNumber,
      'id_photo_path': photoPath,
    });
  }
}
