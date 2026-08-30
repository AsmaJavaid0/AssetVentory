import 'package:cloud_firestore/cloud_firestore.dart';
import 'sharing_permissions_model.dart';

class SharedAssetModel {
  final String id;
  final String familyId;
  final String assetId;
  final String ownerId;
  final String ownerName;
  final String name;
  final String? categoryName;
  final String? emoji;
  final String? imagePath;

  /// Legacy/public URL field retained for backwards compatibility.
  final String? imageUrl;

  /// Private Supabase Storage path. It is never exposed as a public URL.
  final String? imageStoragePath;
  final String? location;
  final String? description;
  final SharingPermissionsModel permissions;
  final DateTime sharedAt;
  final DateTime updatedAt;

  const SharedAssetModel({
    required this.id,
    required this.familyId,
    required this.assetId,
    required this.ownerId,
    required this.ownerName,
    required this.name,
    this.categoryName,
    this.emoji,
    this.imagePath,
    this.imageUrl,
    this.imageStoragePath,
    this.location,
    this.description,
    this.permissions = const SharingPermissionsModel(),
    required this.sharedAt,
    required this.updatedAt,
  });

  factory SharedAssetModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return SharedAssetModel(
      id: doc.id,
      familyId: data['familyId'] as String? ?? '',
      assetId: data['assetId'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      name: data['name'] as String? ?? '',
      categoryName: data['categoryName'] as String?,
      emoji: data['emoji'] as String?,
      imagePath: data['imagePath'] as String?,
      imageUrl: data['imageUrl'] as String?,
      imageStoragePath: data['imageStoragePath'] as String?,
      location: data['location'] as String?,
      description: data['description'] as String?,
      permissions: SharingPermissionsModel.fromMap(
        data['permissions'] as Map<String, dynamic>?,
      ),
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'assetId': assetId,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'name': name,
      'categoryName': categoryName,
      'emoji': emoji,
      'imagePath': imagePath,
      'imageUrl': imageUrl,
      'imageStoragePath': imageStoragePath,
      'location': permissions.viewLocation ? location : null,
      'description': permissions.viewDetails ? description : null,
      'permissions': permissions.toMap(),
      'sharedAt': Timestamp.fromDate(sharedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SharedAssetModel copyWith({
    String? id,
    String? familyId,
    String? assetId,
    String? ownerId,
    String? ownerName,
    String? name,
    String? categoryName,
    String? emoji,
    String? imagePath,
    String? imageUrl,
    String? imageStoragePath,
    String? location,
    String? description,
    SharingPermissionsModel? permissions,
    DateTime? sharedAt,
    DateTime? updatedAt,
  }) {
    return SharedAssetModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      assetId: assetId ?? this.assetId,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      name: name ?? this.name,
      categoryName: categoryName ?? this.categoryName,
      emoji: emoji ?? this.emoji,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      imageStoragePath: imageStoragePath ?? this.imageStoragePath,
      location: location ?? this.location,
      description: description ?? this.description,
      permissions: permissions ?? this.permissions,
      sharedAt: sharedAt ?? this.sharedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String? get displayImageUrl =>
      imageUrl ?? ((imagePath?.startsWith('http') ?? false) ? imagePath : null);
}
