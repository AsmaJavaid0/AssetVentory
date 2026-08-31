import '../../models/family_model.dart';
import '../../models/family_member_model.dart';
import '../../models/family_invitation_model.dart';
import '../../models/shared_asset_model.dart';
import '../../models/sharing_permissions_model.dart';
import '../../../auth/models/user_model.dart';
import '../../../assets/models/local_asset.dart';

abstract class IFamilyRepository {
  /// Fetch the family for a given user ID (or null if not in a family)
  Future<FamilyModel?> getUserFamily(String userId);

  /// Stream family updates
  Stream<FamilyModel?> streamFamily(String familyId);

  /// Create a new family group and set the creator as Owner
  Future<FamilyModel> createFamily({
    required String name,
    String? description,
    required UserModel owner,
  });

  /// Join a family using an invitation code
  Future<FamilyModel> joinFamilyByCode({
    required String inviteCode,
    required UserModel user,
  });

  /// Get members of a family
  Future<List<FamilyMemberModel>> getFamilyMembers(String familyId);

  /// Stream members of a family
  Stream<List<FamilyMemberModel>> streamFamilyMembers(String familyId);

  /// Send an invitation to join a family by email
  Future<FamilyInvitationModel> sendInvitation({
    required String familyId,
    required String familyName,
    required UserModel sender,
    required String receiverEmail,
  });

  /// Get pending invitations for a specific email
  Future<List<FamilyInvitationModel>> getPendingInvitationsForEmail(String email);

  /// Stream pending invitations for a specific email
  Stream<List<FamilyInvitationModel>> streamPendingInvitationsForEmail(String email);

  /// Stream pending invitations sent from a family
  Stream<List<FamilyInvitationModel>> streamFamilySentInvitations(String familyId);

  /// Accept an invitation
  Future<FamilyModel> acceptInvitation({
    required FamilyInvitationModel invitation,
    required UserModel user,
  });

  /// Decline an invitation
  Future<void> declineInvitation(String invitationId);

  /// Cancel an invitation (by sender / admin)
  Future<void> cancelInvitation(String invitationId);

  /// Stream shared assets in a family
  Stream<List<SharedAssetModel>> streamSharedAssets(String familyId);

  /// Share a local asset with the family
  Future<SharedAssetModel> shareAsset({
    required String familyId,
    required LocalAsset asset,
    required UserModel owner,
    String? categoryName,
    required SharingPermissionsModel permissions,
  });

  /// Update permissions of an already shared asset
  Future<void> updateSharedAssetPermissions({
    required String sharedAssetId,
    required SharingPermissionsModel permissions,
  });

  /// Unshare an asset from the family
  Future<void> unshareAsset(String sharedAssetId);

  /// Leave family (or transfer ownership / delete if owner)
  Future<void> leaveFamily({
    required String familyId,
    required String userId,
  });

  /// Transfer ownership to another member
  Future<void> transferOwnership({
    required String familyId,
    required String currentOwnerId,
    required String newOwnerId,
  });

  /// Delete family (owner only)
  Future<void> deleteFamily(String familyId);
}
