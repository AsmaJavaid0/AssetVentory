import 'package:cloud_firestore/cloud_firestore.dart';

/// The types of tasks supported by AssetVentory.
enum TaskType { reminder, alert, alarm, generalTask, familyTask;
  String get label => switch (this) { TaskType.reminder => 'Reminder', TaskType.alert => 'Alert', TaskType.alarm => 'Alarm', TaskType.generalTask => 'General Task', TaskType.familyTask => 'Family Task' };
  String get icon => switch (this) { TaskType.reminder => '🔔', TaskType.alert => '⚠️', TaskType.alarm => '⏰', TaskType.generalTask => '📋', TaskType.familyTask => '👨‍👩‍👧‍👦' };
  String toFirestore() => name;
  static TaskType fromFirestore(String? value) => TaskType.values.firstWhere((e) => e.name == value, orElse: () => TaskType.generalTask);
}
enum TaskPriority { low, medium, high, urgent;
  String get label => switch (this) { TaskPriority.low => 'Low', TaskPriority.medium => 'Medium', TaskPriority.high => 'High', TaskPriority.urgent => 'Urgent' };
  String toFirestore() => name;
  static TaskPriority fromFirestore(String? value) => TaskPriority.values.firstWhere((e) => e.name == value, orElse: () => TaskPriority.medium);
}
enum TaskStatus { pending, inProgress, completed, cancelled;
  String get label => switch (this) { TaskStatus.pending => 'Pending', TaskStatus.inProgress => 'In Progress', TaskStatus.completed => 'Completed', TaskStatus.cancelled => 'Cancelled' };
  String toFirestore() => name;
  static TaskStatus fromFirestore(String? value) { if (value == 'overdue') return TaskStatus.pending; return TaskStatus.values.firstWhere((e) => e.name == value, orElse: () => TaskStatus.pending); }
}
enum RepeatType { none, daily, weekly, monthly, yearly, custom;
  String get label => switch (this) { RepeatType.none => 'Does not repeat', RepeatType.daily => 'Daily', RepeatType.weekly => 'Weekly', RepeatType.monthly => 'Monthly', RepeatType.yearly => 'Yearly', RepeatType.custom => 'Custom' };
  String toFirestore() => name;
  static RepeatType fromFirestore(String? value) => RepeatType.values.firstWhere((e) => e.name == value, orElse: () => RepeatType.none);
}

class TaskModel {
  final String id, title, ownerId, createdBy, visibility;
  final String? description, createdByName, assignedTo, assignedToName, familyId, assetId, assetName, assetEmoji, completedBy, completedByName;
  final TaskType taskType; final TaskPriority priority; final TaskStatus status;
  final DateTime dueDate, createdAt, updatedAt;
  final DateTime? dueTime, repeatEndDate, completedAt, cancelledAt, snoozedUntil;
  final bool isAllDay, reminderEnabled;
  final int reminderMinutesBefore; final RepeatType repeatType; final int? repeatInterval;

  TaskModel({required this.id, required this.title, this.description, this.taskType = TaskType.generalTask, this.priority = TaskPriority.medium, this.status = TaskStatus.pending, required this.ownerId, required this.createdBy, this.createdByName, this.assignedTo, this.assignedToName, this.familyId, this.visibility = 'personal', this.assetId, this.assetName, this.assetEmoji, required this.dueDate, this.dueTime, this.isAllDay = false, this.reminderEnabled = true, this.reminderMinutesBefore = 15, this.repeatType = RepeatType.none, this.repeatInterval, this.repeatEndDate, this.completedAt, this.completedBy, this.completedByName, this.cancelledAt, this.snoozedUntil, required this.createdAt, required this.updatedAt});

  DateTime get _combinedDueDateTime => dueTime == null ? DateTime(dueDate.year, dueDate.month, dueDate.day, 23, 59, 59) : DateTime(dueDate.year, dueDate.month, dueDate.day, dueTime!.hour, dueTime!.minute);
  DateTime get effectiveDueDateTime => snoozedUntil ?? _combinedDueDateTime;
  bool get isOverdue => status != TaskStatus.completed && status != TaskStatus.cancelled && effectiveDueDateTime.isBefore(DateTime.now());
  String get displayStatus => isOverdue ? 'Overdue' : status.label;
  bool get isFamilyTask => taskType == TaskType.familyTask || (assignedTo?.isNotEmpty ?? false);
  bool get isDueToday { final n = DateTime.now(); return dueDate.year == n.year && dueDate.month == n.month && dueDate.day == n.day; }
  bool get isUpcoming { final n = DateTime.now(); return DateTime(dueDate.year, dueDate.month, dueDate.day).isAfter(DateTime(n.year, n.month, n.day)); }

  factory TaskModel.fromFirestore(DocumentSnapshot<Map<String,dynamic>> doc) { final d = doc.data() ?? {}; return TaskModel(id: doc.id, title: d['title'] as String? ?? '', description: d['description'] as String?, taskType: TaskType.fromFirestore(d['taskType'] as String?), priority: TaskPriority.fromFirestore(d['priority'] as String?), status: TaskStatus.fromFirestore(d['status'] as String?), ownerId: d['ownerId'] as String? ?? d['createdBy'] as String? ?? '', createdBy: d['createdBy'] as String? ?? '', createdByName: d['createdByName'] as String?, assignedTo: d['assignedTo'] as String?, assignedToName: d['assignedToName'] as String?, familyId: d['familyId'] as String?, visibility: d['visibility'] as String? ?? 'personal', assetId: d['assetId'] as String?, assetName: d['assetName'] as String?, assetEmoji: d['assetEmoji'] as String?, dueDate: (d['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(), dueTime: (d['dueTime'] as Timestamp?)?.toDate(), isAllDay: d['isAllDay'] as bool? ?? false, reminderEnabled: d['reminderEnabled'] as bool? ?? true, reminderMinutesBefore: (d['reminderMinutesBefore'] as num?)?.toInt() ?? 15, repeatType: RepeatType.fromFirestore(d['repeatType'] as String?), repeatInterval: (d['repeatInterval'] as num?)?.toInt(), repeatEndDate: (d['repeatEndDate'] as Timestamp?)?.toDate(), completedAt: (d['completedAt'] as Timestamp?)?.toDate(), completedBy: d['completedBy'] as String?, completedByName: d['completedByName'] as String?, cancelledAt: (d['cancelledAt'] as Timestamp?)?.toDate(), snoozedUntil: (d['snoozedUntil'] as Timestamp?)?.toDate(), createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(), updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now()); }

  Map<String,dynamic> toFirestore() => {'title':title,'description':description,'taskType':taskType.toFirestore(),'priority':priority.toFirestore(),'status':status.toFirestore(),'ownerId':ownerId,'createdBy':createdBy,'createdByName':createdByName,'assignedTo':assignedTo,'assignedToName':assignedToName,'familyId':familyId,'visibility':visibility,'assetId':assetId,'assetName':assetName,'assetEmoji':assetEmoji,'dueDate':Timestamp.fromDate(dueDate),'dueTime':dueTime == null ? null : Timestamp.fromDate(dueTime!), 'isAllDay':isAllDay,'reminderEnabled':reminderEnabled,'reminderMinutesBefore':reminderMinutesBefore,'repeatType':repeatType.toFirestore(),'repeatInterval':repeatInterval,'repeatEndDate':repeatEndDate == null ? null : Timestamp.fromDate(repeatEndDate!), 'completedAt':completedAt == null ? null : Timestamp.fromDate(completedAt!), 'completedBy':completedBy,'completedByName':completedByName,'cancelledAt':cancelledAt == null ? null : Timestamp.fromDate(cancelledAt!), 'snoozedUntil':snoozedUntil == null ? null : Timestamp.fromDate(snoozedUntil!), 'createdAt':Timestamp.fromDate(createdAt),'updatedAt':Timestamp.fromDate(updatedAt)};

  TaskModel copyWith({String? id,String? title,String? description,TaskType? taskType,TaskPriority? priority,TaskStatus? status,String? ownerId,String? createdBy,String? createdByName,String? assignedTo,String? assignedToName,String? familyId,String? visibility,String? assetId,String? assetName,String? assetEmoji,DateTime? dueDate,DateTime? dueTime,bool? isAllDay,bool? reminderEnabled,int? reminderMinutesBefore,RepeatType? repeatType,int? repeatInterval,DateTime? repeatEndDate,DateTime? completedAt,String? completedBy,String? completedByName,DateTime? cancelledAt,DateTime? snoozedUntil,DateTime? createdAt,DateTime? updatedAt}) => TaskModel(id:id ?? this.id,title:title ?? this.title,description:description ?? this.description,taskType:taskType ?? this.taskType,priority:priority ?? this.priority,status:status ?? this.status,ownerId:ownerId ?? this.ownerId,createdBy:createdBy ?? this.createdBy,createdByName:createdByName ?? this.createdByName,assignedTo:assignedTo ?? this.assignedTo,assignedToName:assignedToName ?? this.assignedToName,familyId:familyId ?? this.familyId,visibility:visibility ?? this.visibility,assetId:assetId ?? this.assetId,assetName:assetName ?? this.assetName,assetEmoji:assetEmoji ?? this.assetEmoji,dueDate:dueDate ?? this.dueDate,dueTime:dueTime ?? this.dueTime,isAllDay:isAllDay ?? this.isAllDay,reminderEnabled:reminderEnabled ?? this.reminderEnabled,reminderMinutesBefore:reminderMinutesBefore ?? this.reminderMinutesBefore,repeatType:repeatType ?? this.repeatType,repeatInterval:repeatInterval ?? this.repeatInterval,repeatEndDate:repeatEndDate ?? this.repeatEndDate,completedAt:completedAt ?? this.completedAt,completedBy:completedBy ?? this.completedBy,completedByName:completedByName ?? this.completedByName,cancelledAt:cancelledAt ?? this.cancelledAt,snoozedUntil:snoozedUntil ?? this.snoozedUntil,createdAt:createdAt ?? this.createdAt,updatedAt:updatedAt ?? this.updatedAt);
}
