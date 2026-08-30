import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/family_model.dart';
import '../models/shared_asset_model.dart';
import '../models/sharing_permissions_model.dart';
import '../../auth/models/user_model.dart';
import '../../assets/models/local_asset.dart';
import '../services/family_file_service.dart';
import 'family_repository.dart';

/// Family repository variant that keeps family media in a private Supabase
/// Storage bucket. Firebase Auth/Firestore remain the source of identity and
/// family membership.
class SecureFamilyRepository extends FamilyRepository {
  final FamilyFileService _files;
  final FirebaseFirestore _db;

  SecureFamilyRepository({
    FamilyFileService? files,
    FirebaseFirestore? firestore,
  })  : _files = files ?? FamilyFileService(),
        _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sharedAssets =>
      _db.collection('shared_assets');

  String _contentType(String path) {
    final extension = path.split('.').last.toLowerCase();
    const types = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
      'heic': 'image/heic',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt': 'text/plain',
    };
    return types[extension] ?? 'application/octet-stream';
  }

  @override
  Future<SharedAssetModel> shareAsset({
    required String familyId,
    required LocalAsset asset,
    required UserModel owner,
    String? categoryName,
    required SharingPermissionsModel permissions,
  }) async {
    final now = DateTime.now();
    final docId = '${familyId}_${asset.id}';

    String? storagePath;
    if (asset.imagePath != null && asset.imagePath!.isNotEmpty) {
      storagePath = await _files.uploadFile(
        familyId: familyId,
        assetId: asset.id,
        filePath: asset.imagePath!,
        fileName: asset.imagePath!.split(RegExp(r'[\\/]')).last,
        contentType: _contentType(asset.imagePath!),
      );
    }

    final shared = SharedAssetModel(
      id: docId,
      familyId: familyId,
      assetId: asset.id,
      ownerId: owner.id,
      ownerName: owner.name.isNotEmpty ? owner.name : owner.email.split('@').first,
      name: asset.name,
      categoryName: categoryName,
      emoji: asset.emoji,
      imagePath: null,
      imageUrl: null,
      imageStoragePath: storagePath,
      location: asset.location,
      description: asset.description,
      permissions: permissions,
      sharedAt: now,
      updatedAt: now,
    );

    try {
      await _sharedAssets.doc(docId).set(shared.toFirestore())
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Firestore may queue the write while offline.
    }

    return shared;
  }

  @override
  Future<void> unshareAsset(String sharedAssetId) async {
    final doc = await _sharedAssets.doc(sharedAssetId).get();
    final data = doc.data();
    final familyId = data?['familyId'] as String?;
    final storagePath = data?['imageStoragePath'] as String?;

    await _sharedAssets.doc(sharedAssetId).delete()
        .timeout(const Duration(seconds: 8));

    if (familyId != null && storagePath != null && storagePath.isNotEmpty) {
      try {
        await _files.deleteFile(familyId: familyId, path: storagePath);
      } catch (_) {
        // Firestore sharing state is already removed. Storage cleanup can be
        // retried later without blocking the user's unshare action.
      }
    }
  }

  /// Returns a short-lived URL only after the Edge Function has verified that
  /// the current Firebase user belongs to the same family.
  Future<String> getSecureImageUrl(SharedAssetModel asset) async {
    final path = asset.imageStoragePath;
    if (path == null || path.isEmpty) {
      return asset.displayImageUrl ?? '';
    }
    return _files.getDownloadUrl(familyId: asset.familyId, path: path);
  }
}
