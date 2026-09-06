import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/di/service_locator.dart';
import '../models/shared_asset_model.dart';
import '../models/shared_document_model.dart';
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
    String? downloadUrl;
    if (permissions.viewDetails && asset.imagePath != null && asset.imagePath!.isNotEmpty) {
      try {
        storagePath = await _files.uploadFile(
          familyId: familyId,
          assetId: asset.id,
          filePath: asset.imagePath!,
          fileName: asset.imagePath!.split(RegExp(r'[\\/]')).last,
          contentType: _contentType(asset.imagePath!),
        );
        try {
          downloadUrl = await _files.getDownloadUrl(
            familyId: familyId,
            path: storagePath,
          );
        } catch (_) {}
      } catch (e) {
        // Fallback: media upload might fail on network, but keep asset share working
      }
    }

    List<SharedDocumentModel> sharedDocs = [];
    if (permissions.viewDocuments) {
      try {
        final localDocs = await serviceLocator.assetDocumentRepository
            .getDocuments(asset.id);
        for (final doc in localDocs) {
          String? docStoragePath;
          String? docDownloadUrl;
          if (File(doc.filePath).existsSync()) {
            try {
              docStoragePath = await _files.uploadFile(
                familyId: familyId,
                assetId: asset.id,
                filePath: doc.filePath,
                fileName: doc.filePath.split(RegExp(r'[\\/]')).last,
                contentType: _contentType(doc.filePath),
              );
              try {
                docDownloadUrl = await _files.getDownloadUrl(
                  familyId: familyId,
                  path: docStoragePath,
                );
              } catch (_) {}
            } catch (e) {
              // File upload fallback
            }
          }
          sharedDocs.add(SharedDocumentModel(
            id: doc.id,
            name: doc.name,
            filePath: doc.filePath,
            fileType: doc.fileType,
            fileSize: doc.fileSize,
            storagePath: docStoragePath,
            downloadUrl: docDownloadUrl,
          ));
        }
      } catch (e) {
        // Continue if document fetch fails
      }
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
      imagePath: permissions.viewDetails ? asset.imagePath : null,
      imageUrl: permissions.viewDetails ? downloadUrl : null,
      imageStoragePath: permissions.viewDetails ? storagePath : null,
      location: permissions.viewLocation ? asset.location : null,
      description: permissions.viewDetails ? asset.description : null,
      documents: permissions.viewDocuments ? sharedDocs : const [],
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
