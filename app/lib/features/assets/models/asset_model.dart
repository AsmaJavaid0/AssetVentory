import 'package:cloud_firestore/cloud_firestore.dart';

class AssetModel {
  final String id;
  final String ownerId;
  final String name;
  final String? categoryId;
  final String? emoji;
  final String? imageUrl;
  final String? location;
  final String? description;
  final bool qrEnabled;
  final Map<String, String> customFields;
  final DateTime createdAt;
  final DateTime updatedAt;

  AssetModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.categoryId,
    this.emoji,
    this.imageUrl,
    this.location,
    this.description,
    this.qrEnabled = false,
    this.customFields = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory AssetModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    
    // Parse customFields map safely
    final rawCustomFields = data['customFields'] as Map<String, dynamic>? ?? {};
    final parsedCustomFields = rawCustomFields.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    return AssetModel(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      categoryId: data['categoryId'] as String?,
      emoji: data['emoji'] as String?,
      imageUrl: data['imageUrl'] as String?,
      location: data['location'] as String?,
      description: data['description'] as String?,
      qrEnabled: data['qrEnabled'] as bool? ?? false,
      customFields: parsedCustomFields,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  AssetModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? categoryId,
    String? emoji,
    String? imageUrl,
    String? location,
    String? description,
    bool? qrEnabled,
    Map<String, String>? customFields,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssetModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      emoji: emoji ?? this.emoji,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      description: description ?? this.description,
      qrEnabled: qrEnabled ?? this.qrEnabled,
      customFields: customFields ?? this.customFields,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'name': name,
      'categoryId': categoryId,
      'emoji': emoji,
      'imageUrl': imageUrl,
      'location': location,
      'description': description,
      'qrEnabled': qrEnabled,
      'customFields': customFields,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
