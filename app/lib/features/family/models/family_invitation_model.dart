import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyInvitationModel {
  final String id;
  final String familyId;
  final String familyName;
  final String senderId;
  final String senderName;
  final String receiverEmail;
  final String inviteCode;
  final String status; // 'pending' | 'accepted' | 'declined' | 'cancelled'
  final DateTime createdAt;

  const FamilyInvitationModel({
    required this.id,
    required this.familyId,
    required this.familyName,
    required this.senderId,
    required this.senderName,
    required this.receiverEmail,
    required this.inviteCode,
    this.status = 'pending',
    required this.createdAt,
  });

  bool get isPending => status == 'pending';

  factory FamilyInvitationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FamilyInvitationModel(
      id: doc.id,
      familyId: data['familyId'] as String? ?? '',
      familyName: data['familyName'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      receiverEmail: data['receiverEmail'] as String? ?? '',
      inviteCode: data['inviteCode'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'familyName': familyName,
      'senderId': senderId,
      'senderName': senderName,
      'receiverEmail': receiverEmail,
      'inviteCode': inviteCode,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  FamilyInvitationModel copyWith({
    String? id,
    String? familyId,
    String? familyName,
    String? senderId,
    String? senderName,
    String? receiverEmail,
    String? inviteCode,
    String? status,
    DateTime? createdAt,
  }) {
    return FamilyInvitationModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      familyName: familyName ?? this.familyName,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverEmail: receiverEmail ?? this.receiverEmail,
      inviteCode: inviteCode ?? this.inviteCode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
