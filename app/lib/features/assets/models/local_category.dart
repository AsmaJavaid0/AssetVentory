

class LocalCategory {
  final String id;
  final String ownerId;
  final String name;
  final String? emoji;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LocalCategory({
    required this.id,
    required this.ownerId,
    required this.name,
    this.emoji,
    required this.createdAt,
    required this.updatedAt,
  });
}