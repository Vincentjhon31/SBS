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
