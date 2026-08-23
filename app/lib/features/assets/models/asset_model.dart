import 'package:cloud_firestore/cloud_firestore.dart';

class AssetModel {
  final String id;
  final String ownerId;
  final String name;
  final String? categoryId;
  final String? emoji;
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
      location: data['location'] as String?,
      description: data['description'] as String?,
      qrEnabled: data['qrEnabled'] as bool? ?? false,
      customFields: parsedCustomFields,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'name': name,
      'categoryId': categoryId,
      'emoji': emoji,
      'location': location,
      'description': description,
      'qrEnabled': qrEnabled,
      'customFields': customFields,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
