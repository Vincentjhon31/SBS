class Department {
  const Department({required this.id, required this.name, required this.active});

  final String id;
  final String name;
  final bool active;

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        id: json['id'] as String,
        name: json['name'] as String,
        active: json['active'] as bool? ?? true,
      );
}

/// Live availability of an item, derived server-side without exposing
/// borrower identity.
class ItemStatus {
  const ItemStatus({
    required this.itemId,
    required this.status,
    this.currentDue,
    this.nextReservedFrom,
  });

  final String itemId;

  /// 'available' | 'reserved_now' | 'out' | 'overdue'
  final String status;
  final DateTime? currentDue;
  final DateTime? nextReservedFrom;

  factory ItemStatus.fromJson(Map<String, dynamic> json) => ItemStatus(
        itemId: json['item_id'] as String,
        status: json['status'] as String,
        currentDue: json['current_due'] == null
            ? null
            : DateTime.parse(json['current_due'] as String).toLocal(),
        nextReservedFrom: json['next_reserved_from'] == null
            ? null
            : DateTime.parse(json['next_reserved_from'] as String).toLocal(),
      );
}

class Item {
  const Item({
    required this.id,
    required this.name,
    this.distinguishingTag,
    this.category,
    this.owningDepartmentId,
    this.departmentName,
    this.referencePhotoPath,
    required this.active,
  });

  final String id;
  final String name;
  final String? distinguishingTag;
  final String? category;
  final String? owningDepartmentId;
  final String? departmentName;
  final String? referencePhotoPath;
  final bool active;

  /// "Multicab (SKA-1234)" — the human identity of the item.
  String get displayName =>
      distinguishingTag == null || distinguishingTag!.isEmpty
          ? name
          : '$name ($distinguishingTag)';

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as String,
        name: json['name'] as String,
        distinguishingTag: json['distinguishing_tag'] as String?,
        category: json['category'] as String?,
        owningDepartmentId: json['owning_department_id'] as String?,
        departmentName:
            (json['departments'] as Map<String, dynamic>?)?['name'] as String?,
        referencePhotoPath: json['reference_photo_path'] as String?,
        active: json['active'] as bool? ?? true,
      );
}
