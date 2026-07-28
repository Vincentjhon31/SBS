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

  /// All departments regardless of active state — for the department
  /// management screen, where staff need to see (and possibly reactivate)
  /// deactivated ones too, unlike the item-assignment dropdown above.
  Future<List<Department>> fetchAllDepartments() async {
    final rows = await _client
        .from('departments')
        .select()
        .order('name', ascending: true);
    return [for (final row in rows) Department.fromJson(row)];
  }

  /// Also enrolls the caller as the new department's first approver (via
  /// the create_department RPC) — otherwise it'd have zero members and be
  /// unusable (invisible in the item form's department dropdown, and
  /// unmanageable) until someone added one through Studio.
  Future<void> createDepartment(String name) async {
    await _client.rpc('create_department', params: {'dept_name': name.trim()});
  }

  Future<void> renameDepartment(String id, String name) async {
    await _client.from('departments').update({'name': name.trim()}).eq('id', id);
  }

  Future<void> setDepartmentActive(String id, bool active) async {
    await _client.from('departments').update({'active': active}).eq('id', id);
  }

  /// Hard-deletes when nothing references the department; the RPC raises
  /// with `hint: 'deactivate'` otherwise (caught by the caller to offer
  /// [setDepartmentActive] instead — mirrors [deleteItem]).
  Future<void> deleteDepartment(String id) =>
      _client.rpc('delete_department', params: {'dept': id});

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
    int quantity = 1,
  }) async {
    final row = await _client
        .from('items')
        .insert({
          'name': name.trim(),
          'distinguishing_tag': _nullIfBlank(distinguishingTag),
          'category': _nullIfBlank(category),
          'owning_department_id': owningDepartmentId,
          'quantity': quantity,
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
    required int quantity,
  }) async {
    await _client.from('items').update({
      'name': name.trim(),
      'distinguishing_tag': _nullIfBlank(distinguishingTag),
      'category': _nullIfBlank(category),
      'owning_department_id': owningDepartmentId,
      'active': active,
      'quantity': quantity,
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

  /// Permanently deletes an item. The RPC only allows this for items with
  /// no borrow history (it raises otherwise — the caller should offer to
  /// deactivate instead). Best-effort removes the reference photo too;
  /// a leftover object is harmless if that cleanup fails.
  Future<void> deleteItem(String itemId, {String? referencePhotoPath}) async {
    await _client.rpc('delete_item', params: {'item': itemId});
    if (referencePhotoPath != null) {
      try {
        await _client.storage.from('item-photos').remove([referencePhotoPath]);
      } catch (_) {
        // Orphaned photo is acceptable; the row is already gone.
      }
    }
  }

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
