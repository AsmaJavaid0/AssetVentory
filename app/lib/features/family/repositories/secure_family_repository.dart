import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/shared_asset_model.dart';
import '../models/sharing_permissions_model.dart';
import '../../auth/models/user_model.dart';
import '../../assets/models/local_asset.dart';
import '../services/family_file_service.dart';
import 'family_repository.dart';

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

  CollectionReference<Map<String, dynamic>> get _sharedAssets => _db.collection('shared_assets');
  CollectionReference<Map<String, dynamic>> get _families => _db.collection('families');
  CollectionReference<Map<String, dynamic>> get _familyAccess => _db.collection('family_access');

  String _contentType(String path) {
    final extension = path.split('.').last.toLowerCase();
    const types = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp',
      'gif': 'image/gif', 'heic': 'image/heic', 'pdf': 'application/pdf',
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
      id: docId, familyId: familyId, assetId: asset.id, ownerId: owner.id,
      ownerName: owner.name.isNotEmpty ? owner.name : owner.email.split('@').first,
      name: asset.name, categoryName: categoryName, emoji: asset.emoji,
      imagePath: null, imageUrl: null, imageStoragePath: storagePath,
      location: asset.location, description: asset.description,
      permissions: permissions, sharedAt: now, updatedAt: now,
    );
    try {
      await _sharedAssets.doc(docId).set(shared.toFirestore()).timeout(const Duration(seconds: 8));
    } on TimeoutException {}
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
      try { await _files.deleteFile(familyId: familyId, path: storagePath); } catch (_) {}
    }
  }

  @override
  Future<void> setFamilySharePin({required String familyId, required String pin}) async {
    await _functions.httpsCallable('setFamilySharePin').call({'familyId': familyId, 'pin': pin});
  }

  @override
  Future<void> removeFamilySharePin(String familyId) async {
    await _functions.httpsCallable('removeFamilySharePin').call({'familyId': familyId});
  }

  @override
  Future<bool> verifyFamilySharePin({required String familyId, required String pin}) async {
    final result = await _functions.httpsCallable('verifyFamilySharePin').call({'familyId': familyId, 'pin': pin});
    return result.data is Map && result.data['success'] == true;
  }

  @override
  Future<bool> isFamilyShareUnlocked(String familyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final family = await _families.doc(familyId).get();
    if (!family.exists) return false;
    final data = family.data() ?? {};
    if (data['pinEnabled'] != true) return true;
    final access = await _familyAccess.doc('${familyId}_${user.uid}').get();
    if (!access.exists) return false;
    final currentVersion = (data['pinVersion'] as num?)?.toInt() ?? 1;
    final grantedVersion = (access.data()?['pinVersion'] as num?)?.toInt() ?? 0;
    return currentVersion == grantedVersion && access.data()?['userId'] == user.uid;
  }

  Future<String> getSecureImageUrl(SharedAssetModel asset) async {
    final path = asset.imageStoragePath;
    if (path == null || path.isEmpty) return asset.displayImageUrl ?? '';
    return _files.getDownloadUrl(familyId: asset.familyId, path: path);
  }
}
