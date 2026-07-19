import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Citizen self-registration: creates the auth account (the DB trigger
  /// creates the profiles row), uploads the ID photo to the private
  /// id-photos bucket, then stores the verification details.
  Future<void> registerCitizen({
    required String email,
    required String password,
    required String fullName,
    required String contactNumber,
    required String idType,
    required String idNumber,
    required Uint8List idPhotoBytes,
    String idPhotoContentType = 'image/jpeg',
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'user_type': 'citizen'},
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
