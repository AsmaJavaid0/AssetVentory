import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/family_model.dart';
import '../models/family_member_model.dart';
import '../models/family_invitation_model.dart';
import '../models/shared_asset_model.dart';
import '../models/sharing_permissions_model.dart';
import '../../auth/models/user_model.dart';
import '../../assets/models/local_asset.dart';
import '../services/family_file_service.dart';
import 'interfaces/i_family_repository.dart';

class FamilyRepository implements IFamilyRepository {
  final FirebaseFirestore _firestore;
  final FamilyFileService _familyFileService;

  FamilyRepository({
    FirebaseFirestore? firestore,
    FamilyFileService? familyFileService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _familyFileService = familyFileService ?? FamilyFileService();

  CollectionReference<Map<String, dynamic>> get _families =>
      _firestore.collection('families');

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection('family_members');

  CollectionReference<Map<String, dynamic>> get _invitations =>
      _firestore.collection('family_invitations');

  CollectionReference<Map<String, dynamic>> get _sharedAssets =>
      _firestore.collection('shared_assets');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final code = List.generate(
      5,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return 'FAM-$code';
  }

  @override
  Future<FamilyModel?> getUserFamily(String userId) async {
    try {
      final userDoc = await _users
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 6));
      if (userDoc.exists) {
        final familyId = userDoc.data()?['familyId'] as String?;
        if (familyId != null && familyId.isNotEmpty) {
          final familyDoc = await _families
              .doc(familyId)
              .get()
              .timeout(const Duration(seconds: 6));
          if (familyDoc.exists) {
            return FamilyModel.fromFirestore(familyDoc);
          }
        }
      }

      final membership = await _members
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));

      if (membership.docs.isNotEmpty) {
        final familyId = membership.docs.first.data()['familyId'] as String;
        final familyDoc = await _families
            .doc(familyId)
            .get()
            .timeout(const Duration(seconds: 6));
        if (familyDoc.exists) {
          _users.doc(userId).set({
            'familyId': familyId,
          }, SetOptions(merge: true));
          return FamilyModel.fromFirestore(familyDoc);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<FamilyModel?> streamFamily(String familyId) {
    return _families.doc(familyId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return FamilyModel.fromFirestore(doc);
    });
  }

  @override
  Future<FamilyModel> createFamily({
    required String name,
    String? description,
    required UserModel owner,
  }) async {
    final now = DateTime.now();
    final familyId = _families.doc().id;
    final inviteCode = _generateInviteCode();

    final family = FamilyModel(
      id: familyId,
      name: name.trim(),
      description: description?.trim().isEmpty == true
          ? null
          : description?.trim(),
      ownerId: owner.id,
      inviteCode: inviteCode,
      memberCount: 1,
      createdAt: now,
      updatedAt: now,
    );

    final member = FamilyMemberModel(
      id: '${familyId}_${owner.id}',
      familyId: familyId,
      userId: owner.id,
      name: owner.name.isNotEmpty ? owner.name : owner.email.split('@').first,
      email: owner.email,
      photoUrl: owner.photoUrl,
      role: 'owner',
      joinedAt: now,
    );

    await _firestore
        .runTransaction((transaction) async {
          final userSnapshot = await transaction.get(_users.doc(owner.id));
          final existingFamilyId = userSnapshot.data()?['familyId'] as String?;
          if (existingFamilyId != null && existingFamilyId.isNotEmpty) {
            throw StateError(
              'You already belong to a family. Leave it before creating another.',
            );
          }
          transaction.set(_families.doc(familyId), family.toFirestore());
          transaction.set(_members.doc(member.id), member.toFirestore());
          transaction.set(_users.doc(owner.id), {
            'familyId': familyId,
          }, SetOptions(merge: true));
        })
        .timeout(const Duration(seconds: 12));

    return family;
  }

  @override
  Future<FamilyModel> joinFamilyByCode({
    required String inviteCode,
    required UserModel user,
  }) async {
    final normalizedCode = inviteCode.trim().toUpperCase();
    final query = await _families
        .where('inviteCode', isEqualTo: normalizedCode)
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 8));

    if (query.docs.isEmpty) {
      throw Exception('Invalid invitation code. Please check and try again.');
    }

    final familyDoc = query.docs.first;
    final family = FamilyModel.fromFirestore(familyDoc);
    final now = DateTime.now();
    final memberId = '${family.id}_${user.id}';

    final member = FamilyMemberModel(
      id: memberId,
      familyId: family.id,
      userId: user.id,
      name: user.name.isNotEmpty ? user.name : user.email.split('@').first,
      email: user.email,
      photoUrl: user.photoUrl,
      role: 'member',
      joinedAt: now,
    );

    await _joinFamilyTransaction(
      family: family,
      member: member,
      userId: user.id,
      now: now,
    );

    return family;
  }

  @override
  Future<List<FamilyMemberModel>> getFamilyMembers(String familyId) async {
    try {
      final query = await _members
          .where('familyId', isEqualTo: familyId)
          .get()
          .timeout(const Duration(seconds: 8));
      return query.docs.map(FamilyMemberModel.fromFirestore).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Stream<List<FamilyMemberModel>> streamFamilyMembers(String familyId) {
    return _members
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(FamilyMemberModel.fromFirestore).toList(),
        );
  }

  @override
  Future<FamilyInvitationModel> sendInvitation({
    required String familyId,
    required String familyName,
    required UserModel sender,
    required String receiverEmail,
  }) async {
    final email = receiverEmail.trim().toLowerCase();
    final now = DateTime.now();
    final inviteId = _invitations.doc().id;

    String inviteCode = _generateInviteCode();
    try {
      final familyDoc = await _families
          .doc(familyId)
          .get()
          .timeout(const Duration(seconds: 6));
      inviteCode = familyDoc.data()?['inviteCode'] as String? ?? inviteCode;
    } catch (_) {}

    final invitation = FamilyInvitationModel(
      id: inviteId,
      familyId: familyId,
      familyName: familyName,
      senderId: sender.id,
      senderName: sender.name.isNotEmpty ? sender.name : sender.email,
      receiverEmail: email,
      inviteCode: inviteCode,
      status: 'pending',
      createdAt: now,
    );

    try {
      await _invitations
          .doc(inviteId)
          .set(invitation.toFirestore())
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Queued
    }

    return invitation;
  }

  @override
  Future<List<FamilyInvitationModel>> getPendingInvitationsForEmail(
    String email,
  ) async {
    if (email.isEmpty) return [];
    try {
      final query = await _invitations
          .where('receiverEmail', isEqualTo: email.trim().toLowerCase())
          .where('status', isEqualTo: 'pending')
          .get()
          .timeout(const Duration(seconds: 8));

      return query.docs.map(FamilyInvitationModel.fromFirestore).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Stream<List<FamilyInvitationModel>> streamPendingInvitationsForEmail(
    String email,
  ) {
    if (email.isEmpty) return Stream.value([]);
    return _invitations
        .where('receiverEmail', isEqualTo: email.trim().toLowerCase())
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(FamilyInvitationModel.fromFirestore).toList(),
        );
  }

  @override
  Stream<List<FamilyInvitationModel>> streamFamilySentInvitations(
    String familyId,
  ) {
    return _invitations
        .where('familyId', isEqualTo: familyId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(FamilyInvitationModel.fromFirestore).toList(),
        );
  }

  @override
  Future<FamilyModel> acceptInvitation({
    required FamilyInvitationModel invitation,
    required UserModel user,
  }) async {
    final familyDoc = await _families
        .doc(invitation.familyId)
        .get()
        .timeout(const Duration(seconds: 8));

    if (!familyDoc.exists) {
      throw Exception('This family group no longer exists.');
    }

    final family = FamilyModel.fromFirestore(familyDoc);
    final now = DateTime.now();
    final memberId = '${family.id}_${user.id}';

    final member = FamilyMemberModel(
      id: memberId,
      familyId: family.id,
      userId: user.id,
      name: user.name.isNotEmpty ? user.name : user.email.split('@').first,
      email: user.email,
      photoUrl: user.photoUrl,
      role: 'member',
      joinedAt: now,
    );

    await _joinFamilyTransaction(
      family: family,
      member: member,
      userId: user.id,
      now: now,
      invitationId: invitation.id,
    );

    return family;
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    await _invitations
        .doc(invitationId)
        .delete()
        .timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> cancelInvitation(String invitationId) async {
    await _invitations
        .doc(invitationId)
        .update({'status': 'cancelled'})
        .timeout(const Duration(seconds: 8));
  }

  @override
  Stream<List<SharedAssetModel>> streamSharedAssets(String familyId) {
    return _sharedAssets
        .where('familyId', isEqualTo: familyId)
        .orderBy('sharedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(SharedAssetModel.fromFirestore).toList(),
        );
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
    final storagePath = await _uploadSharedImage(
      familyId: familyId,
      assetId: asset.id,
      localPath: asset.imagePath,
    );

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
      await _sharedAssets
          .doc(docId)
          .set(shared.toFirestore())
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Queued
    }

    return shared;
  }

  @override
  Future<void> updateSharedAssetPermissions({
    required String sharedAssetId,
    required SharingPermissionsModel permissions,
  }) async {
    await _sharedAssets
        .doc(sharedAssetId)
        .update({
          'permissions': permissions.toMap(),
          if (!permissions.viewLocation) 'location': FieldValue.delete(),
          if (!permissions.viewDetails) 'description': FieldValue.delete(),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        })
        .timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> unshareAsset(String sharedAssetId) async {
    final doc = await _sharedAssets.doc(sharedAssetId).get();
    final data = doc.data();
    await _sharedAssets
        .doc(sharedAssetId)
        .delete()
        .timeout(const Duration(seconds: 8));

    final familyId = data?['familyId'] as String?;
    final storagePath = data?['imageStoragePath'] as String?;
    if (familyId != null && storagePath != null && storagePath.isNotEmpty) {
      try {
        await _familyFileService.deleteFile(
          familyId: familyId,
          path: storagePath,
        );
      } catch (_) {
        // Firestore unshare has already completed. The storage cleanup can be
        // retried separately without blocking the local/remote share removal.
      }
    }
  }

  Future<void> _joinFamilyTransaction({
    required FamilyModel family,
    required FamilyMemberModel member,
    required String userId,
    required DateTime now,
    String? invitationId,
  }) {
    final userRef = _users.doc(userId);
    final memberRef = _members.doc(member.id);
    final familyRef = _families.doc(family.id);
    return _firestore
        .runTransaction((transaction) async {
          final userSnapshot = await transaction.get(userRef);
          final memberSnapshot = await transaction.get(memberRef);
          final familySnapshot = await transaction.get(familyRef);
          if (!familySnapshot.exists) {
            throw StateError('This family group no longer exists.');
          }
          final currentFamilyId = userSnapshot.data()?['familyId'] as String?;
          if (currentFamilyId != null &&
              currentFamilyId.isNotEmpty &&
              currentFamilyId != family.id) {
            throw StateError(
              'You already belong to a family. Leave it before joining another.',
            );
          }
          if (!memberSnapshot.exists) {
            transaction.set(memberRef, member.toFirestore());
            transaction.update(familyRef, {
              'memberCount': FieldValue.increment(1),
              'updatedAt': Timestamp.fromDate(now),
            });
          }
          transaction.set(userRef, {
            'familyId': family.id,
          }, SetOptions(merge: true));
          if (invitationId != null) {
            transaction.update(_invitations.doc(invitationId), {
              'status': 'accepted',
            });
          }
        })
        .timeout(const Duration(seconds: 12));
  }

  Future<String?> _uploadSharedImage({
    required String familyId,
    required String assetId,
    required String? localPath,
  }) async {
    if (localPath == null ||
        localPath.isEmpty ||
        localPath.startsWith('http')) {
      return null;
    }
    final file = File(localPath);
    if (!await file.exists()) return null;

    final fileName = localPath.split(RegExp(r'[\\/]')).last;
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'bin';
    final contentType = _contentTypeForExtension(extension);

    return _familyFileService.uploadFile(
      familyId: familyId,
      assetId: assetId,
      filePath: localPath,
      fileName: fileName,
      contentType: contentType,
    );
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Future<void> leaveFamily({
    required String familyId,
    required String userId,
  }) async {
    final memberId = '${familyId}_$userId';

    try {
      final userShared = await _sharedAssets
          .where('familyId', isEqualTo: familyId)
          .where('ownerId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 6));

      for (final doc in userShared.docs) {
        await unshareAsset(doc.id);
      }

      await _firestore
          .runTransaction((transaction) async {
            final memberRef = _members.doc(memberId);
            final familyRef = _families.doc(familyId);
            final memberSnapshot = await transaction.get(memberRef);
            final familySnapshot = await transaction.get(familyRef);
            if (!memberSnapshot.exists || !familySnapshot.exists) {
              throw StateError(
                'This family membership is no longer available.',
              );
            }
            transaction.delete(memberRef);
            transaction.update(familyRef, {
              'memberCount': FieldValue.increment(-1),
              'updatedAt': Timestamp.fromDate(DateTime.now()),
            });
            transaction.update(_users.doc(userId), {
              'familyId': FieldValue.delete(),
            });
          })
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      // Queued
    } catch (e) {
      throw Exception('Failed to leave family: $e');
    }
  }

  @override
  Future<void> transferOwnership({
    required String familyId,
    required String currentOwnerId,
    required String newOwnerId,
  }) async {
    try {
      await Future.wait([
        _families.doc(familyId).update({
          'ownerId': newOwnerId,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }),
        _members.doc('${familyId}_$currentOwnerId').update({'role': 'admin'}),
        _members.doc('${familyId}_$newOwnerId').update({'role': 'owner'}),
      ]).timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Queued
    } catch (e) {
      throw Exception('Failed to transfer ownership: $e');
    }
  }

  @override
  Future<void> deleteFamily(String familyId) async {
    try {
      final shared = await _sharedAssets
          .where('familyId', isEqualTo: familyId)
          .get()
          .timeout(const Duration(seconds: 6));

      for (final doc in shared.docs) {
        await unshareAsset(doc.id);
      }

      await _families
          .doc(familyId)
          .delete()
          .timeout(const Duration(seconds: 8));

      final members = await _members
          .where('familyId', isEqualTo: familyId)
          .get()
          .timeout(const Duration(seconds: 6));

      for (final doc in members.docs) {
        final userId = doc.data()['userId'] as String?;
        if (userId != null && userId.isNotEmpty) {
          await _users.doc(userId).update({'familyId': FieldValue.delete()});
        }
        await doc.reference.delete();
      }

      final invites = await _invitations
          .where('familyId', isEqualTo: familyId)
          .get()
          .timeout(const Duration(seconds: 6));

      for (final doc in invites.docs) {
        await doc.reference.delete();
      }
    } on TimeoutException {
      // Queued
    } catch (e) {
      throw Exception('Failed to delete family: $e');
    }
  }
}
