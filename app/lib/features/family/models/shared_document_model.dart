class SharedDocumentModel {
  final String id;
  final String name;
  final String? filePath;
  final String? fileType;
  final int? fileSize;
  final String? storagePath;
  final String? downloadUrl;

  const SharedDocumentModel({
    required this.id,
    required this.name,
    this.filePath,
    this.fileType,
    this.fileSize,
    this.storagePath,
    this.downloadUrl,
  });

  factory SharedDocumentModel.fromMap(Map<String, dynamic> map) {
    return SharedDocumentModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Document',
      filePath: map['filePath'] as String?,
      fileType: map['fileType'] as String?,
      fileSize: map['fileSize'] as int?,
      storagePath: map['storagePath'] as String?,
      downloadUrl: map['downloadUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (filePath != null) 'filePath': filePath,
      if (fileType != null) 'fileType': fileType,
      if (fileSize != null) 'fileSize': fileSize,
      if (storagePath != null) 'storagePath': storagePath,
      if (downloadUrl != null) 'downloadUrl': downloadUrl,
    };
  }

  SharedDocumentModel copyWith({
    String? id,
    String? name,
    String? filePath,
    String? fileType,
    int? fileSize,
    String? storagePath,
    String? downloadUrl,
  }) {
    return SharedDocumentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }
}
