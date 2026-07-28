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
    required this.quantity,
    required this.availableCount,
  });

  final String itemId;

  /// 'available' | 'reserved_now' | 'out' | 'overdue' — only turns
  /// alarming once EVERY unit is occupied; check [availableCount] for the
  /// actual "X of Y" number.
  final String status;
  final DateTime? currentDue;
  final DateTime? nextReservedFrom;

  /// Total physical units (1 for a single item, more for e.g. "5 folding
  /// chairs").
  final int quantity;

  /// How many units are free right now.
  final int availableCount;

  bool get hasMultipleUnits => quantity > 1;

  factory ItemStatus.fromJson(Map<String, dynamic> json) => ItemStatus(
        itemId: json['item_id'] as String,
        status: json['status'] as String,
        currentDue: json['current_due'] == null
            ? null
            : DateTime.parse(json['current_due'] as String).toLocal(),
        nextReservedFrom: json['next_reserved_from'] == null
            ? null
            : DateTime.parse(json['next_reserved_from'] as String).toLocal(),
        quantity: json['quantity'] as int? ?? 1,
        availableCount: json['available_count'] as int? ?? 0,
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
    required this.quantity,
  });

  final String id;
  final String name;
  final String? distinguishingTag;
  final String? category;
  final String? owningDepartmentId;
  final String? departmentName;
  final String? referencePhotoPath;
  final bool active;

  /// Total physical units of this item (e.g. "5 folding chairs"). 1 for a
  /// one-of-a-kind item — the common case, and the only case before
  /// inventory support existed.
  final int quantity;

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
        quantity: json['quantity'] as int? ?? 1,
      );
}
