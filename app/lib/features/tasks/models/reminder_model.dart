import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  final String id;
  final String ownerId;
  final String? assetId;
  final String? taskId;
  final String title;
  final DateTime reminderDate;
  final DateTime? reminderTime;
  final String? repeat;
  final String? notifyBefore;
  final String? notes;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReminderModel({
    required this.id,
    required this.ownerId,
    this.assetId,
    this.taskId,
    required this.title,
    required this.reminderDate,
    this.reminderTime,
    this.repeat,
    this.notifyBefore,
    this.notes,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReminderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ReminderModel(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      assetId: data['assetId'] as String?,
      taskId: data['taskId'] as String?,
      title: data['title'] as String? ?? '',
      reminderDate: (data['reminderDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reminderTime: (data['reminderTime'] as Timestamp?)?.toDate(),
      repeat: data['repeat'] as String?,
      notifyBefore: data['notifyBefore'] as String?,
      notes: data['notes'] as String?,
      status: data['status'] as String? ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'assetId': assetId,
      'taskId': taskId,
      'title': title,
      'reminderDate': Timestamp.fromDate(reminderDate),
      'reminderTime': reminderTime != null ? Timestamp.fromDate(reminderTime!) : null,
      'repeat': repeat,
      'notifyBefore': notifyBefore,
      'notes': notes,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
