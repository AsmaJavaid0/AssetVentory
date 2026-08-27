import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMemberModel {
  final String id;
  final String familyId;
  final String userId;
  final String name;
  final String email;
  final String photoUrl;
  final String role; // 'owner' | 'admin' | 'member'
  final DateTime joinedAt;

  const FamilyMemberModel({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.name,
    required this.email,
    this.photoUrl = '',
    this.role = 'member',
    required this.joinedAt,
  });

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || role == 'owner';

  factory FamilyMemberModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FamilyMemberModel(
      id: doc.id,
      familyId: data['familyId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
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
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
