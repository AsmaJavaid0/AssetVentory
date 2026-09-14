import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/storage/app_preferences_service.dart';
import '../models/family_member_model.dart';
import '../models/shared_asset_model.dart';
import '../models/shared_document_model.dart';
import '../models/sharing_permissions_model.dart';
import '../../auth/models/user_model.dart';
import '../../assets/models/local_asset.dart';
import '../services/family_file_service.dart';
import 'family_repository.dart';

class SecureFamilyRepository extends FamilyRepository {
  final FamilyFileService _files;
  final FirebaseFirestore _db;
  final AppPreferencesService _preferences;
  final FirebaseFunctions _functions;

  SecureFamilyRepository({
    FamilyFileService? files,
    FirebaseFirestore? firestore,
    AppPreferencesService? preferences,
    FirebaseFunctions? functions,
  })  : _files = files ?? FamilyFileService(),
        _db = firestore ?? FirebaseFirestore.instance,
        _preferences = preferences ?? AppPreferencesService(),
        _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _sharedAssets =>
      _db.collection('shared_assets');

  CollectionReference<Map<String, dynamic>> get _families =>
      _db.collection('families');

  CollectionReference<Map<String, dynamic>> get _familyAccess =>
      _db.collection('family_access');

  String get _viewerId => FirebaseAuth.instance.currentUser?.uid ?? '';

  String _displayNameFor(FamilyMemberModel member) {
    if (_viewerId.isEmpty) return member.familyDisplayName;

    return _preferences.familyDisplayName(
      familyId: member.familyId,
      viewerId: _viewerId,
      memberUserId: member.userId,
      fallback: member.name.isNotEmpty
          ? member.name
          : member.familyDisplayName,
    );
  }

  FamilyMemberModel _forViewer(FamilyMemberModel member) {
    return member.copyWith(
      displayName: _displayNameFor(member),
    );
  }

  @override
  Future<List<FamilyMemberModel>> getFamilyMembers(
    String familyId,
  ) async {
    final members = await super.getFamilyMembers(familyId);
    return members.map(_forViewer).toList();
  }

  @override
  Stream<List<FamilyMemberModel>> streamFamilyMembers(
    String familyId,
  ) {
    return super.streamFamilyMembers(familyId).map(
          (members) => members.map(_forViewer).toList(),
        );
  }

  @override
  String getFamilyMemberDisplayName({
    required String familyId,
    required String userId,
    required String fallback,
  }) {
    if (_viewerId.isEmpty) return fallback;

    return _preferences.familyDisplayName(
      familyId: familyId,
      viewerId: _viewerId,
      memberUserId: userId,
      fallback: fallback,
    );
  }

  @override
  Future<void> updateFamilyMemberDisplayName({
    required String familyId,
    required String userId,
    required String displayName,
  }) async {
    if (_viewerId.isEmpty) {
      throw StateError(
        'You must be signed in to edit a family display name.',
      );
    }

    final trimmedName = displayName.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError(
        'Family display name cannot be empty.',
      );
    }

    if (trimmedName.length > 40) {
      throw ArgumentError(
        'Family display name must be 40 characters or less.',
      );
    }

    await _preferences.setFamilyDisplayName(
      familyId: familyId,
      viewerId: _viewerId,
      memberUserId: userId,
      displayName: trimmedName,
    );

    try {
      await super.updateFamilyMemberDisplayName(
        familyId: familyId,
        userId: userId,
        displayName: trimmedName,
      );
    } catch (_) {
      // Non-fatal if Firestore rules disallow editing
      // another member's global document.
    }

    nameUpdateNotifier.value++;
  }

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
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt': 'text/plain',
    };

    return types[extension] ?? 'application/octet-stream';
  }

  @override
  Stream<List<SharedAssetModel>> streamSharedAssets(
    String familyId,
  ) {
    return _sharedAssets
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .map((snapshot) {
      final assets = snapshot.docs
          .map(SharedAssetModel.fromFirestore)
          .toList();

      final viewerId = _viewerId;

      assets.sort((a, b) {
        final aMine = a.ownerId == viewerId;
        final bMine = b.ownerId == viewerId;

        if (aMine != bMine) {
          return aMine ? -1 : 1;
        }

        return b.sharedAt.compareTo(a.sharedAt);
      });

      return assets;
    });
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

    if (permissions.viewDetails &&
        asset.imagePath != null &&
        asset.imagePath!.isNotEmpty) {
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
        } catch (_) {
          // Asset can still be shared. The receiver can
          // resolve the private storage path later.
        }
      } catch (_) {
        storagePath = null;
        downloadUrl = null;
      }
    }

    final sharedDocs = <SharedDocumentModel>[];

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
            } catch (_) {
              docStoragePath = null;
              docDownloadUrl = null;
            }
          }

          sharedDocs.add(
            SharedDocumentModel(
              id: doc.id,
              name: doc.name,
              filePath: doc.filePath,
              fileType: doc.fileType,
              fileSize: doc.fileSize,
              storagePath: docStoragePath,
              downloadUrl: docDownloadUrl,
            ),
          );
        }
      } catch (_) {}
    }

    final shared = SharedAssetModel(
      id: docId,
      familyId: familyId,
      assetId: asset.id,
      ownerId: owner.id,
      ownerName: owner.name.isNotEmpty
          ? owner.name
          : owner.email.split('@').first,
      name: asset.name,
      categoryName: categoryName,
      emoji: asset.emoji,
      imagePath: storagePath == null ? null : asset.imagePath,
      imageUrl: downloadUrl,
      imageStoragePath: storagePath,
      location: permissions.viewLocation ? asset.location : null,
      description: permissions.viewDetails ? asset.description : null,
      documents: permissions.viewDocuments ? sharedDocs : const [],
      permissions: permissions,
      sharedAt: now,
      updatedAt: now,
    );

    try {
      await _sharedAssets
          .doc(docId)
          .set(shared.toFirestore())
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      // Preserve the PIN branch's behavior of not crashing
      // the UI on a Firestore timeout.
    }

    return shared;
  }

  @override
  Future<void> unshareAsset(String sharedAssetId) async {
    final doc = await _sharedAssets.doc(sharedAssetId).get();
    final data = doc.data();

    final familyId = data?['familyId'] as String?;
    final storagePath = data?['imageStoragePath'] as String?;

    await _sharedAssets
        .doc(sharedAssetId)
        .delete()
        .timeout(const Duration(seconds: 8));

    if (familyId != null &&
        storagePath != null &&
        storagePath.isNotEmpty) {
      try {
        await _files.deleteFile(
          familyId: familyId,
          path: storagePath,
        );
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Family Share PIN security
  // ---------------------------------------------------------------------------

  @override
  Future<void> setFamilySharePin({
    required String familyId,
    required String pin,
  }) async {
    await _functions
        .httpsCallable('setFamilySharePin')
        .call({
      'familyId': familyId,
      'pin': pin,
    });
  }

  @override
  Future<void> removeFamilySharePin(
    String familyId,
  ) async {
    await _functions
        .httpsCallable('removeFamilySharePin')
        .call({
      'familyId': familyId,
    });
  }

  @override
  Future<bool> verifyFamilySharePin({
    required String familyId,
    required String pin,
  }) async {
    final result = await _functions
        .httpsCallable('verifyFamilySharePin')
        .call({
      'familyId': familyId,
      'pin': pin,
    });

    return result.data is Map &&
        result.data['success'] == true;
  }

  @override
  Future<bool> isFamilyShareUnlocked(
    String familyId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    final family = await _families.doc(familyId).get();

    if (!family.exists) return false;

    final data = family.data() ?? {};

    if (data['pinEnabled'] != true) {
      return true;
    }

    final access = await _familyAccess
        .doc('${familyId}_${user.uid}')
        .get();

    if (!access.exists) {
      return false;
    }

    final currentVersion =
        (data['pinVersion'] as num?)?.toInt() ?? 1;

    final grantedVersion =
        (access.data()?['pinVersion'] as num?)?.toInt() ?? 0;

    return currentVersion == grantedVersion &&
        access.data()?['userId'] == user.uid;
  }

  Future<String> getSecureImageUrl(
    SharedAssetModel asset,
  ) async {
    final path = asset.imageStoragePath;

    if (path == null || path.isEmpty) {
      return asset.displayImageUrl ?? '';
    }

    return _files.getDownloadUrl(
      familyId: asset.familyId,
      path: path,
    );
  }
}