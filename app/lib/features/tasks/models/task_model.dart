import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String? familyId;
  final String createdBy;
  final String? assignedTo;
  final String visibility; // 'personal' | 'assigned' | 'family'
  final String title;
  final String? assetId;
  final DateTime dueDate;
  final DateTime? dueTime;
  final String? reminderId;
  final String? notes;
  final String status; // 'pending' | 'completed' | 'overdue'
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskModel({
    required this.id,
    this.familyId,
    required this.createdBy,
    this.assignedTo,
    this.visibility = 'personal',
    required this.title,
    this.assetId,
    required this.dueDate,
    this.dueTime,
    this.reminderId,
    this.notes,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TaskModel(
      id: doc.id,
      familyId: data['familyId'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      assignedTo: data['assignedTo'] as String?,
      visibility: data['visibility'] as String? ?? 'personal',
      title: data['title'] as String? ?? '',
      assetId: data['assetId'] as String?,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueTime: (data['dueTime'] as Timestamp?)?.toDate(),
      reminderId: data['reminderId'] as String?,
      notes: data['notes'] as String?,
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'createdBy': createdBy,
      'assignedTo': assignedTo,
      'visibility': visibility,
      'title': title,
      'assetId': assetId,
      'dueDate': Timestamp.fromDate(dueDate),
      'dueTime': dueTime != null ? Timestamp.fromDate(dueTime!) : null,
      'reminderId': reminderId,
      'notes': notes,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
