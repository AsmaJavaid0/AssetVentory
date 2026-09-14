import 'package:flutter/foundation.dart';

import '../../models/family_model.dart';
import '../../models/family_member_model.dart';
import '../../models/family_invitation_model.dart';
import '../../models/shared_asset_model.dart';
import '../../models/sharing_permissions_model.dart';
import '../../../auth/models/user_model.dart';
import '../../../assets/models/local_asset.dart';

abstract class IFamilyRepository {
  /// Notifier that increments when a family member display name is updated.
  ValueNotifier<int> get nameUpdateNotifier;

  /// Fetch the family for a given user ID (or null if not in a family).
  Future<FamilyModel?> getUserFamily(String userId);

  Stream<FamilyModel?> streamFamily(String familyId);

  Future<FamilyModel> createFamily({
    required String name,
    String? description,
    required UserModel owner,
  });

  Future<FamilyModel> joinFamilyByCode({
    required String inviteCode,
    required UserModel user,
  });

  Future<List<FamilyMemberModel>> getFamilyMembers(String familyId);

  Stream<List<FamilyMemberModel>> streamFamilyMembers(String familyId);

  /// Get effective display name for a family member.
  String getFamilyMemberDisplayName({
    required String familyId,
    required String userId,
    required String fallback,
  });

  /// Update the family display name shown to other family members.
  Future<void> updateFamilyMemberDisplayName({
    required String familyId,
    required String userId,
    required String displayName,
  });

  /// Send an invitation to join a family by email.
  Future<FamilyInvitationModel> sendInvitation({
    required String familyId,
    required String familyName,
    required UserModel sender,
    required String receiverEmail,
  });

  /// Get pending invitations for a specific email.
  Future<List<FamilyInvitationModel>> getPendingInvitationsForEmail(
    String email,
  );

  Stream<List<FamilyInvitationModel>> streamPendingInvitationsForEmail(
    String email,
  );

  Stream<List<FamilyInvitationModel>> streamFamilySentInvitations(
    String familyId,
  );

  Future<FamilyModel> acceptInvitation({
    required FamilyInvitationModel invitation,
    required UserModel user,
  });

  Future<void> declineInvitation(String invitationId);

  Future<void> cancelInvitation(String invitationId);

  Stream<List<SharedAssetModel>> streamSharedAssets(String familyId);

  Future<SharedAssetModel> shareAsset({
    required String familyId,
    required LocalAsset asset,
    required UserModel owner,
    String? categoryName,
    required SharingPermissionsModel permissions,
  });

  Future<void> updateSharedAssetPermissions({
    required String sharedAssetId,
    required SharingPermissionsModel permissions,
  });

  Future<void> unshareAsset(String sharedAssetId);

  // Family Share PIN security.
  // Default implementations keep existing repository variants
  // source-compatible; the secure repository overrides them.
  Future<void> setFamilySharePin({
    required String familyId,
    required String pin,
  }) => throw UnimplementedError();

  Future<void> removeFamilySharePin(String familyId) =>
      throw UnimplementedError();

  Future<bool> verifyFamilySharePin({
    required String familyId,
    required String pin,
  }) => throw UnimplementedError();

  Future<bool> isFamilyShareUnlocked(String familyId) =>
      throw UnimplementedError();

  Future<void> leaveFamily({
    required String familyId,
    required String userId,
  });

  Future<void> transferOwnership({
    required String familyId,
    required String currentOwnerId,
    required String newOwnerId,
  });

  Future<void> deleteFamily(String familyId);
}