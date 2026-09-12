class LocalAsset {
  final String id;
  final String ownerId;
  final String name;
  final String? categoryId;
  final String? emoji;
  final String? imagePath;
  final String? location;
  final String? description;
  final bool qrEnabled;
  final Map<String, String> customFields;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LocalAsset({
    required this.id,
    required this.ownerId,
    required this.name,
    this.categoryId,
    this.emoji,
    this.imagePath,
    this.location,
    this.description,
    this.qrEnabled = false,
    this.customFields = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  LocalAsset copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? categoryId,
    bool clearCategoryId = false,
    String? emoji,
    String? imagePath,
    bool clearImagePath = false,
    String? location,
    bool clearLocation = false,
    String? description,
    bool clearDescription = false,
    bool? qrEnabled,
    Map<String, String>? customFields,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocalAsset(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      emoji: emoji ?? this.emoji,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      location: clearLocation ? null : (location ?? this.location),
      description: clearDescription ? null : (description ?? this.description),
      qrEnabled: qrEnabled ?? this.qrEnabled,
      customFields: customFields ?? this.customFields,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}