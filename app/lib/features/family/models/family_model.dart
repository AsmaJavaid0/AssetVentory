import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyModel {
  final String id;
  final String name;
  final String? description;
  final String ownerId;
  final String inviteCode;
  final int memberCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FamilyModel({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    required this.inviteCode,
    this.memberCount = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FamilyModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      ownerId: data['ownerId'] as String? ?? '',
      inviteCode: data['inviteCode'] as String? ?? '',
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'inviteCode': inviteCode,
      'memberCount': memberCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  FamilyModel copyWith({
    String? id,
    String? name,
    String? description,
    String? ownerId,
    String? inviteCode,
    int? memberCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FamilyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      inviteCode: inviteCode ?? this.inviteCode,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
