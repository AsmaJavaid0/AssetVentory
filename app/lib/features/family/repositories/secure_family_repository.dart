import 'package:flutter/foundation.dart';

import '../../../core/storage/app_preferences_service.dart';
import '../models/family_model.dart';
import '../models/family_member_model.dart';
import 'family_repository.dart';

/// Family Share PIN is a local privacy lock for this device/user.
/// It does not participate in Family Share synchronization or Firestore access.
class SecureFamilyRepository extends FamilyRepository {
  final AppPreferencesService _preferences;
  final Map<String, bool> _pinEnabledByFamily = <String, bool>{};
  final Set<String> _unlockedFamilyIds = <String>{};

  SecureFamilyRepository({AppPreferencesService? preferences})
      : _preferences = preferences ?? AppPreferencesService();

  String get _viewerId => serviceLocatorCurrentUserId();

  Future<void> _cachePinState(String familyId) async {
    if (_viewerId.isEmpty) return;
    final pin = await _preferences.getFamilySharePin(
      familyId: familyId,
      viewerId: _viewerId,
    );
    final enabled = pin != null && pin.isNotEmpty;
    _pinEnabledByFamily[familyId] = enabled;
    if (!enabled) {
      _unlockedFamilyIds.add(familyId);
    }
  }

  @override
  Future<FamilyModel?> getUserFamily(String userId) async {
    final family = await super.getUserFamily(userId);
    if (family != null) await _cachePinState(family.id);
    return family;
  }

  @override
  Stream<FamilyModel?> streamFamily(String familyId) {
    return super.streamFamily(familyId).asyncMap((family) async {
      if (family != null) await _cachePinState(family.id);
      return family;
    });
  }

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
    return members
        .map((member) => member.copyWith(displayName: _displayNameFor(member)))
        .toList();
  }

  @override
  Stream<List<FamilyMemberModel>> streamFamilyMembers(String familyId) {
    return super.streamFamilyMembers(familyId).map(
      (members) => members
          .map((member) => member.copyWith(displayName: _displayNameFor(member)))
          .toList(),
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
      throw StateError('You must be signed in to edit a family display name.');
    }
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Family display name cannot be empty.');
    if (trimmed.length > 40) {
      throw ArgumentError('Family display name must be 40 characters or less.');
    }

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
    } catch (_) {}
    nameUpdateNotifier.value++;
  }

  @override
  bool isFamilyPinEnabled(String familyId) =>
      _pinEnabledByFamily[familyId] ?? false;

  @override
  Future<void> setFamilySharePin({
    required String familyId,
    required String pin,
  }) async {
    final normalized = pin.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(normalized)) {
      throw ArgumentError('PIN must contain 4–6 digits.');
    }
    if (_viewerId.isEmpty) throw StateError('You must be signed in.');

    await _preferences.setFamilySharePin(
      familyId: familyId,
      viewerId: _viewerId,
      pin: normalized,
    );
    _pinEnabledByFamily[familyId] = true;
    _unlockedFamilyIds.add(familyId);
  }

  @override
  Future<void> removeFamilySharePin(String familyId) async {
    if (_viewerId.isEmpty) throw StateError('You must be signed in.');
    await _preferences.removeFamilySharePin(
      familyId: familyId,
      viewerId: _viewerId,
    );
    _pinEnabledByFamily[familyId] = false;
    _unlockedFamilyIds.add(familyId);
  }

  @override
  Future<bool> verifyFamilySharePin({
    required String familyId,
    required String pin,
  }) async {
    if (_viewerId.isEmpty) return false;
    final savedPin = await _preferences.getFamilySharePin(
      familyId: familyId,
      viewerId: _viewerId,
    );
    if (savedPin == null || savedPin.isEmpty) return true;

    final valid = savedPin == pin.trim();
    if (valid) {
      _pinEnabledByFamily[familyId] = true;
      _unlockedFamilyIds.add(familyId);
    }
    return valid;
  }

  @override
  Future<bool> isFamilyShareUnlocked(String familyId) async {
    if (_viewerId.isEmpty) return false;

    final savedPin = await _preferences.getFamilySharePin(
      familyId: familyId,
      viewerId: _viewerId,
    );
    final enabled = savedPin != null && savedPin.isNotEmpty;
    _pinEnabledByFamily[familyId] = enabled;

    if (!enabled) return true;
    return _unlockedFamilyIds.contains(familyId);
  }

  @override
  Future<void> lockFamilyShare(String familyId) async {
    if (_pinEnabledByFamily[familyId] == true) {
      _unlockedFamilyIds.remove(familyId);
    }
  }
}

// Kept here to avoid coupling FamilyRepository to authentication details.
// The service locator already exposes the currently signed-in user.
String serviceLocatorCurrentUserId() {
  final user = serviceLocator.userRepository.currentUser;
  return user?.id ?? '';
}
