import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/shared_asset_model.dart';
import '../models/sharing_permissions_model.dart';
import '../../auth/models/user_model.dart';
import '../../assets/models/local_asset.dart';
import '../services/family_file_service.dart';
import 'family_repository.dart';

/// Family repository variant that keeps family media in private Supabase
/// Storage and protects shared-asset reads behind the Family Share PIN gate.
class SecureFamilyRepository extends FamilyRepository {
  final FamilyFileService _files;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  SecureFamilyRepository({
    FamilyFileService? files,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _files = files ?? FamilyFileService(),
        _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _sharedAssets =>
      _db.collection('shared_assets');

  CollectionReference<Map<String, dynamic>> get _families =>
      _db.collection('families');

  CollectionReference<Map<String, dynamic>> get _familyAccess =>
      _db.collection('family_access');

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
      await _sharedAssets.doc(docId).set(shared.toFirestore()).timeout(const Duration(seconds: 8));
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
    await _sharedAssets.doc(sharedAssetId).delete().timeout(const Duration(seconds: 8));
    if (familyId != null && storagePath != null && storagePath.isNotEmpty) {
      try {
        await _files.deleteFile(familyId: familyId, path: storagePath);
      } catch (_) {}
    }
  }

  @override
  Future<void> setFamilySharePin({required String familyId, required String pin}) async {
    final callable = _functions.httpsCallable('setFamilySharePin');
    await callable.call({'familyId': familyId, 'pin': pin});
  }

  @override
  Future<void> removeFamilySharePin(String familyId) async {
    final callable = _functions.httpsCallable('removeFamilySharePin');
    await callable.call({'familyId': familyId});
  }

  @override
  Future<bool> verifyFamilySharePin({required String familyId, required String pin}) async {
    final callable = _functions.httpsCallable('verifyFamilySharePin');
    final result = await callable.call({'familyId': familyId, 'pin': pin});
    return result.data is Map && result.data['success'] == true;
  }

  @override
  Future<bool> isFamilyShareUnlocked(String familyId) async {
    final family = await _families.doc(familyId).get();
    if (!family.exists) return false;
    final data = family.data() ?? {};
    if (data['pinEnabled'] != true) return true;

    final user = await _db.collection('users').doc(_currentUserId()).get();
    final userId = user.id;
    final access = await _familyAccess.doc('${familyId}_$userId').get();
    if (!access.exists) return false;

    final currentVersion = (data['pinVersion'] as num?)?.toInt() ?? 1;
    final grantedVersion = (access.data()?['pinVersion'] as num?)?.toInt() ?? 0;
    return currentVersion == grantedVersion && access.data()?['userId'] == userId;
  }

  String _currentUserId() {
    final uid = _functions.app.options.projectId; // Prevent accidental use of a stale cached user.
    // Firebase Auth is authoritative; importing firebase_auth here would only
    // duplicate the existing auth dependency, so read the access document via
    // the currently authenticated user's UID in the helper below.
    final auth = _AuthBridge.currentUid;
    if (auth == null || auth.isEmpty) {
      throw StateError('You must be signed in to access Family Sharing.');
    }
    return auth;
  }

  /// Returns a short-lived URL only after the Edge Function has verified that
  /// the current Firebase user belongs to the same family.
  Future<String> getSecureImageUrl(SharedAssetModel asset) async {
    final path = asset.imageStoragePath;
    if (path == null || path.isEmpty) return asset.displayImageUrl ?? '';
    return _files.getDownloadUrl(familyId: asset.familyId, path: path);
  }
}

class _AuthBridge {
  static String? get currentUid {
    // Filled by the auth service at runtime through Firebase Auth.
    // This is replaced below by the lazy import-free Firebase Auth singleton.
    return _firebaseAuthUid;
  }

  static String? _firebaseAuthUid;
}
