import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyDisplayNameService {
  final FirebaseFirestore _firestore;

  FamilyDisplayNameService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _aliases =>
      _firestore.collection('family_member_aliases');

  Stream<Map<String, String>> streamAliases({
    required String familyId,
    required String viewerId,
  }) {
    return _aliases
        .where('familyId', isEqualTo: familyId)
        .where('viewerId', isEqualTo: viewerId)
        .snapshots()
        .map((snapshot) {
      final aliases = <String, String>{};
      for (final doc in snapshot.docs) {
        final targetUserId = doc.data()['targetUserId'] as String?;
        final displayName = doc.data()['displayName'] as String?;
        if (targetUserId != null && displayName != null && displayName.trim().isNotEmpty) {
          aliases[targetUserId] = displayName.trim();
        }
      }
      return aliases;
    });
  }

  Future<String?> getAlias({
    required String familyId,
    required String viewerId,
    required String targetUserId,
  }) async {
    final doc = await _aliases
        .doc('${familyId}_${viewerId}_$targetUserId')
        .get()
        .timeout(const Duration(seconds: 8));
    final name = doc.data()?['displayName'] as String?;
    return name?.trim().isEmpty == true ? null : name?.trim();
  }

  Future<void> setAlias({
    required String familyId,
    required String viewerId,
    required String targetUserId,
    required String displayName,
  }) async {
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Family display name cannot be empty.');
    }
    if (trimmedName.length > 40) {
      throw ArgumentError('Family display name must be 40 characters or less.');
    }

    await _aliases.doc('${familyId}_${viewerId}_$targetUserId').set({
      'familyId': familyId,
      'viewerId': viewerId,
      'targetUserId': targetUserId,
      'displayName': trimmedName,
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 8));
  }

  Future<void> clearAlias({
    required String familyId,
    required String viewerId,
    required String targetUserId,
  }) async {
    await _aliases
        .doc('${familyId}_${viewerId}_$targetUserId')
        .delete()
        .timeout(const Duration(seconds: 8));
  }
}
