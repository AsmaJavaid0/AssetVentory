class LocalAssetDocument {
  final String id;
  final String assetId;
  final String name;
  final String filePath;
  final String? fileType;
  final int? fileSize;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LocalAssetDocument({
    required this.id,
    required this.assetId,
    required this.name,
    required this.filePath,
    this.fileType,
    this.fileSize,
    required this.createdAt,
    required this.updatedAt,
  });
}
