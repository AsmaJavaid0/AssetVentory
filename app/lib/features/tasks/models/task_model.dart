import 'package:cloud_firestore/cloud_firestore.dart';

/// The types of tasks supported by AssetVentory.
enum TaskType {
  reminder,
  alert,
  alarm,
  generalTask,
  familyTask;

  String get label {
    switch (this) {
      case TaskType.reminder:
        return 'Reminder';
      case TaskType.alert:
        return 'Alert';
      case TaskType.alarm:
        return 'Alarm';
      case TaskType.generalTask:
        return 'General Task';
      case TaskType.familyTask:
        return 'Family Task';
    }
  }

  String get icon {
    switch (this) {
      case TaskType.reminder:
        return '🔔';
      case TaskType.alert:
        return '⚠️';
      case TaskType.alarm:
        return '⏰';
      case TaskType.generalTask:
        return '📋';
      case TaskType.familyTask:
        return '👨‍👩‍👧‍👦';
    }
  }

  String toFirestore() => name;

  static TaskType fromFirestore(String? value) {
    if (value == null) return TaskType.generalTask;
    return TaskType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TaskType.generalTask,
    );
  }
}

/// Task priority levels.
enum TaskPriority {
  low,
  medium,
  high,
  urgent;

  String get label {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }

  String toFirestore() => name;

  static TaskPriority fromFirestore(String? value) {
    if (value == null) return TaskPriority.medium;
    return TaskPriority.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TaskPriority.medium,
    );
  }
}

/// Stored task statuses. "Overdue" is derived, not stored.
enum TaskStatus {
  pending,
  inProgress,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.cancelled:
        return 'Cancelled';
    }
  }

  String toFirestore() => name;

  static TaskStatus fromFirestore(String? value) {
    if (value == null) return TaskStatus.pending;
    // Support legacy 'overdue' stored values
    if (value == 'overdue') return TaskStatus.pending;
    return TaskStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TaskStatus.pending,
    );
  }
}

/// Repeat schedule types.
enum RepeatType {
  none,
  daily,
  weekly,
  monthly,
  yearly,
  custom;

  String get label {
    switch (this) {
      case RepeatType.none:
        return 'Does not repeat';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthly:
        return 'Monthly';
      case RepeatType.yearly:
        return 'Yearly';
      case RepeatType.custom:
        return 'Custom';
    }
  }

  String toFirestore() => name;

  static RepeatType fromFirestore(String? value) {
    if (value == null) return RepeatType.none;
    return RepeatType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RepeatType.none,
    );
  }
}

/// Unified task model covering Reminders, Alerts, Alarms, General Tasks,
/// and Family Tasks. This replaces the previous separate TaskModel and
/// ReminderModel.
class TaskModel {
  final String id;
  final String title;
  final String? description;
  final TaskType taskType;
  final TaskPriority priority;
  final TaskStatus status;

  // Ownership & assignment
  final String ownerId;
  final String createdBy;
  final String? createdByName;
  final String? assignedTo;
  final String? assignedToName;
  final String? familyId;
  final String visibility; // 'personal' | 'assigned' | 'family'

  // Asset reference (local asset data snapshot for cloud display)
  final String? assetId;
  final String? assetName;
  final String? assetEmoji;

  // Scheduling
  final DateTime dueDate;
  final DateTime? dueTime;
  final bool isAllDay;

  // Reminder settings (inline, replaces separate ReminderModel)
  final bool reminderEnabled;
  final int reminderMinutesBefore; // 0 = at time of task

  // Repeat settings
  final RepeatType repeatType;
  final int? repeatInterval; // for custom repeat
  final DateTime? repeatEndDate;

  // Completion tracking
  final DateTime? completedAt;
  final String? completedBy;
  final String? completedByName;

  // Cancellation
  final DateTime? cancelledAt;

  // Snooze
  final DateTime? snoozedUntil;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.taskType = TaskType.generalTask,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    required this.ownerId,
    required this.createdBy,
    this.createdByName,
    this.assignedTo,
    this.assignedToName,
    this.familyId,
    this.visibility = 'personal',
    this.assetId,
    this.assetName,
    this.assetEmoji,
    required this.dueDate,
    this.dueTime,
    this.isAllDay = false,
    this.reminderEnabled = true,
    this.reminderMinutesBefore = 15,
    this.repeatType = RepeatType.none,
    this.repeatInterval,
    this.repeatEndDate,
    this.completedAt,
    this.completedBy,
    this.completedByName,
    this.cancelledAt,
    this.snoozedUntil,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether this task is currently overdue (derived, not stored).
  bool get isOverdue {
    if (status == TaskStatus.completed || status == TaskStatus.cancelled) {
      return false;
    }
    final effectiveDue = snoozedUntil ?? _combinedDueDateTime;
    return effectiveDue.isBefore(DateTime.now());
  }

  /// The display-ready status that accounts for derived overdue.
  String get displayStatus {
    if (isOverdue) return 'Overdue';
    return status.label;
  }

  /// Combined due date + time for comparison purposes.
  DateTime get _combinedDueDateTime {
    if (dueTime != null) {
      return DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        dueTime!.hour,
        dueTime!.minute,
      );
    }
    // All-day tasks are overdue after the day ends
    return DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59, 59);
  }

  /// The effective due date/time for notification scheduling.
  DateTime get effectiveDueDateTime => snoozedUntil ?? _combinedDueDateTime;

  /// Whether this is a family-related task.
  bool get isFamilyTask =>
      taskType == TaskType.familyTask ||
      (assignedTo != null && assignedTo!.isNotEmpty);

  /// Whether the task is due today.
  bool get isDueToday {
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  /// Whether the task is upcoming (in the future, not today).
  bool get isUpcoming {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return taskDay.isAfter(today);
  }

  factory TaskModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return TaskModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      taskType: TaskType.fromFirestore(data['taskType'] as String?),
      priority: TaskPriority.fromFirestore(data['priority'] as String?),
      status: TaskStatus.fromFirestore(data['status'] as String?),
      ownerId: data['ownerId'] as String? ?? data['createdBy'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String?,
      assignedTo: data['assignedTo'] as String?,
      assignedToName: data['assignedToName'] as String?,
      familyId: data['familyId'] as String?,
      visibility: data['visibility'] as String? ?? 'personal',
      assetId: data['assetId'] as String?,
      assetName: data['assetName'] as String?,
      assetEmoji: data['assetEmoji'] as String?,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueTime: (data['dueTime'] as Timestamp?)?.toDate(),
      isAllDay: data['isAllDay'] as bool? ?? false,
      reminderEnabled: data['reminderEnabled'] as bool? ?? true,
      reminderMinutesBefore:
          (data['reminderMinutesBefore'] as num?)?.toInt() ?? 15,
      repeatType: RepeatType.fromFirestore(data['repeatType'] as String?),
      repeatInterval: (data['repeatInterval'] as num?)?.toInt(),
      repeatEndDate: (data['repeatEndDate'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      completedBy: data['completedBy'] as String?,
      completedByName: data['completedByName'] as String?,
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      snoozedUntil: (data['snoozedUntil'] as Timestamp?)?.toDate(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'taskType': taskType.toFirestore(),
      'priority': priority.toFirestore(),
      'status': status.toFirestore(),
      'ownerId': ownerId,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'familyId': familyId,
      'visibility': visibility,
      'assetId': assetId,
      'assetName': assetName,
      'assetEmoji': assetEmoji,
      'dueDate': Timestamp.fromDate(dueDate),
      'dueTime': dueTime != null ? Timestamp.fromDate(dueTime!) : null,
      'isAllDay': isAllDay,
      'reminderEnabled': reminderEnabled,
      'reminderMinutesBefore': reminderMinutesBefore,
      'repeatType': repeatType.toFirestore(),
      'repeatInterval': repeatInterval,
      'repeatEndDate':
          repeatEndDate != null ? Timestamp.fromDate(repeatEndDate!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'completedBy': completedBy,
      'completedByName': completedByName,
      'cancelledAt':
          cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'snoozedUntil':
          snoozedUntil != null ? Timestamp.fromDate(snoozedUntil!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    TaskType? taskType,
    TaskPriority? priority,
    TaskStatus? status,
    String? ownerId,
    String? createdBy,
    String? createdByName,
    String? assignedTo,
    String? assignedToName,
    String? familyId,
    String? visibility,
    String? assetId,
    String? assetName,
    String? assetEmoji,
    DateTime? dueDate,
    DateTime? dueTime,
    bool? isAllDay,
    bool? reminderEnabled,
    int? reminderMinutesBefore,
    RepeatType? repeatType,
    int? repeatInterval,
    DateTime? repeatEndDate,
    DateTime? completedAt,
    String? completedBy,
    String? completedByName,
    DateTime? cancelledAt,
    DateTime? snoozedUntil,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      taskType: taskType ?? this.taskType,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      familyId: familyId ?? this.familyId,
      visibility: visibility ?? this.visibility,
      assetId: assetId ?? this.assetId,
      assetName: assetName ?? this.assetName,
      assetEmoji: assetEmoji ?? this.assetEmoji,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      isAllDay: isAllDay ?? this.isAllDay,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      repeatType: repeatType ?? this.repeatType,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatEndDate: repeatEndDate ?? this.repeatEndDate,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      completedByName: completedByName ?? this.completedByName,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
