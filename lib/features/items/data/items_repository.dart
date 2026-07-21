import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'items_models.dart';

class ItemsRepository {
  ItemsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Item>> fetchItems() async {
    final rows = await _client
        .from('items')
        .select('*, departments(name)')
        .order('name', ascending: true);
    return [for (final row in rows) Item.fromJson(row)];
  }

  Future<List<Department>> fetchDepartments() async {
    final rows = await _client
        .from('departments')
        .select()
        .eq('active', true)
        .order('name', ascending: true);
    return [for (final row in rows) Department.fromJson(row)];
  }

  /// Departments the current user can assign items to (their memberships).
  Future<Set<String>> fetchMyDepartmentIds() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {};
    final rows = await _client
        .from('department_members')
        .select('department_id')
        .eq('user_id', uid);
    return {for (final row in rows) row['department_id'] as String};
  }

  Future<Item> createItem({
    required String name,
    String? distinguishingTag,
    String? category,
    String? owningDepartmentId,
  }) async {
    final row = await _client
        .from('items')
        .insert({
          'name': name.trim(),
          'distinguishing_tag': _nullIfBlank(distinguishingTag),
          'category': _nullIfBlank(category),
          'owning_department_id': owningDepartmentId,
          'created_by': _client.auth.currentUser!.id,
        })
        .select('*, departments(name)')
        .single();
    return Item.fromJson(row);
  }

  Future<void> updateItem(
    String id, {
    required String name,
    String? distinguishingTag,
    String? category,
    String? owningDepartmentId,
    required bool active,
  }) async {
    await _client.from('items').update({
      'name': name.trim(),
      'distinguishing_tag': _nullIfBlank(distinguishingTag),
      'category': _nullIfBlank(category),
      'owning_department_id': owningDepartmentId,
      'active': active,
    }).eq('id', id);
  }

  /// Uploads a reference photo and records its path on the item.
  Future<void> uploadReferencePhoto(
    String itemId,
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final path = '$itemId/reference.jpg';
    await _client.storage.from('item-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    await _client
        .from('items')
        .update({'reference_photo_path': path}).eq('id', itemId);
  }

  /// Item photos live in a private bucket; render via short-lived signed URLs.
  Future<String> signedPhotoUrl(String path) =>
      _client.storage.from('item-photos').createSignedUrl(path, 3600);

  /// Live status per active item (identity-free, server-derived).
  Future<Map<String, ItemStatus>> fetchStatuses() async {
    final rows = await _client.rpc('items_status') as List;
    return {
      for (final row in rows)
        (row as Map<String, dynamic>)['item_id'] as String:
            ItemStatus.fromJson(row),
    };
  }

  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
