import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/storage/app_preferences_service.dart';
import '../models/family_member_model.dart';
import 'family_repository.dart';

class SecureFamilyRepository extends FamilyRepository {
  final AppPreferencesService _preferences;
  final FirebaseFunctions _functions;

  SecureFamilyRepository({
    AppPreferencesService? preferences,
    FirebaseFunctions? functions,
  })  : _preferences = preferences ?? AppPreferencesService(),
        _functions = functions ?? FirebaseFunctions.instance;

  String get _viewerId => FirebaseAuth.instance.currentUser?.uid ?? '';

  String _displayNameFor(FamilyMemberModel member) {
    if (_viewerId.isEmpty) return member.familyDisplayName;
    return _preferences.familyDisplayName(
      familyId: member.familyId,
      viewerId: _viewerId,
      memberUserId: member.userId,
      fallback: member.name.isNotEmpty ? member.name : member.familyDisplayName,
    );
  }

  @override
  Future<List<FamilyMemberModel>> getFamilyMembers(String familyId) async {
    final members = await super.getFamilyMembers(familyId);
    return members.map((member) => member.copyWith(displayName: _displayNameFor(member))).toList();
  }

  @override
  Stream<List<FamilyMemberModel>> streamFamilyMembers(String familyId) {
    return super.streamFamilyMembers(familyId).map(
      (members) => members.map((member) => member.copyWith(displayName: _displayNameFor(member))).toList(),
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
    if (_viewerId.isEmpty) throw StateError('You must be signed in to edit a family display name.');
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Family display name cannot be empty.');
    if (trimmed.length > 40) throw ArgumentError('Family display name must be 40 characters or less.');

    await _preferences.setFamilyDisplayName(
      familyId: familyId,
      viewerId: _viewerId,
      memberUserId: userId,
      displayName: trimmed,
    );

    try {
      await super.updateFamilyMemberDisplayName(
        familyId: familyId,
        userId: userId,
        displayName: trimmed,
      );
    } catch (_) {
      // Local family-specific names remain usable when the global update is denied.
    }
    nameUpdateNotifier.value++;
  }

  // PIN state is authoritative in families/{familyId}.pinEnabled. This
  // compatibility method must not be used as a security boundary.
  @override
  bool isFamilyPinEnabled(String familyId) => false;

  final Set<String> _unlockedFamilyIds = <String>{};

  Future<void> _call(String functionName, Map<String, dynamic> data) async {
    if (_viewerId.isEmpty) throw StateError('You must be signed in.');
    await _functions.httpsCallable(functionName).call(data);
  }

  @override
  Future<void> setFamilySharePin({
    required String familyId,
    required String pin,
  }) async {
    await _call('setFamilySharePin', {
      'familyId': familyId,
      'pin': pin,
    });
    _unlockedFamilyIds.add(familyId);
  }

  @override
  Future<void> removeFamilySharePin(String familyId) async {
    await _call('removeFamilySharePin', {'familyId': familyId});
    _unlockedFamilyIds.remove(familyId);
  }

  @override
  Future<bool> verifyFamilySharePin({
    required String familyId,
    required String pin,
  }) async {
    try {
      await _call('verifyFamilySharePin', {
        'familyId': familyId,
        'pin': pin,
      });
      _unlockedFamilyIds.add(familyId);
      return true;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'failed-precondition') return false;
      rethrow;
    }
  }

  @override
  Future<bool> isFamilyShareUnlocked(String familyId) async {
    return _unlockedFamilyIds.contains(familyId);
  }

  @override
  Future<void> lockFamilyShare(String familyId) async {
    await _call('lockFamilyShare', {'familyId': familyId});
    _unlockedFamilyIds.remove(familyId);
  }
}
