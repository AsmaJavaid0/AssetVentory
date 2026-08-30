import 'package:cloud_firestore/cloud_firestore.dart';
import 'sharing_permissions_model.dart';

class SharedAssetModel {
  final String id;
  final String familyId;
  final String assetId; // Original local asset id
  final String ownerId;
  final String ownerName;
  final String name;
  final String? categoryName;
  final String? emoji;
  final String? imagePath;

  /// A Firebase Storage URL for the family copy of the image.  Unlike
  /// [imagePath], this is available to every member of the family.
  final String? imageUrl;
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
      // `imagePath` was used by older builds and may be an absolute path on
      // the owner's device. Keep reading it for backwards compatibility, but
      // prefer the remote URL for all new shared assets.
      imagePath: data['imagePath'] as String?,
      imageUrl: data['imageUrl'] as String?,
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
      location: location ?? this.location,
      description: description ?? this.description,
      permissions: permissions ?? this.permissions,
      sharedAt: sharedAt ?? this.sharedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// The image that can safely be rendered in the family space.
  String? get displayImageUrl =>
      imageUrl ?? ((imagePath?.startsWith('http') ?? false) ? imagePath : null);
}
