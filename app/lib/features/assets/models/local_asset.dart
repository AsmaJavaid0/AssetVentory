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
    String? emoji,
    String? imagePath,
    String? location,
    String? description,
    bool? qrEnabled,
    Map<String, String>? customFields,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocalAsset(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      emoji: emoji ?? this.emoji,
      imagePath: imagePath ?? this.imagePath,
      location: location ?? this.location,
      description: description ?? this.description,
      qrEnabled: qrEnabled ?? this.qrEnabled,
      customFields: customFields ?? this.customFields,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}