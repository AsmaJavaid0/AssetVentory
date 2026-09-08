import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMemberModel {
  final String id;
  final String familyId;
  final String userId;
  final String name;
  final String displayName;
  final String email;
  final String photoUrl;
  final String role; // 'owner' | 'admin' | 'member'
  final DateTime joinedAt;

  const FamilyMemberModel({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.name,
    String? displayName,
    required this.email,
    this.photoUrl = '',
    this.role = 'member',
    required this.joinedAt,
  }) : displayName = displayName ?? name;

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || role == 'owner';

  String get familyDisplayName =>
      displayName.trim().isNotEmpty ? displayName.trim() : name;

  factory FamilyMemberModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final name = data['name'] as String? ?? '';
    final storedDisplayName = data['displayName'] as String?;
    return FamilyMemberModel(
      id: doc.id,
      familyId: data['familyId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      name: name,
      displayName: storedDisplayName?.trim().isNotEmpty == true
          ? storedDisplayName
          : name,
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
      role: data['role'] as String? ?? 'member',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'userId': userId,
      'name': name,
      'displayName': familyDisplayName,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  FamilyMemberModel copyWith({
    String? id,
    String? familyId,
    String? userId,
    String? name,
    String? displayName,
    String? email,
    String? photoUrl,
    String? role,
    DateTime? joinedAt,
  }) {
    return FamilyMemberModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
