import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/task_model.dart';

/// Persistent device-only storage for personal tasks.
///
/// This store deliberately has no Firebase dependency. Personal tasks and
/// their scheduled notifications can therefore continue working when the
/// device is offline or Firebase permissions are unavailable.
class LocalTaskStore {
  static const _keyPrefix = 'assetventory.local_tasks.';
  static final LocalTaskStore _instance = LocalTaskStore._internal();
  factory LocalTaskStore() => _instance;
  LocalTaskStore._internal();

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  final StreamController<String> _changes = StreamController<String>.broadcast();
  final Uuid _uuid = const Uuid();

  String _key(String ownerId) => '$_keyPrefix$ownerId';

  Stream<List<TaskModel>> watch(String ownerId) async* {
    yield await load(ownerId);
    await for (final changedOwner in _changes.stream) {
      if (changedOwner == ownerId) {
        yield await load(ownerId);
      }
    }
  }

  Future<List<TaskModel>> load(String ownerId) async {
    final raw = await _prefs.getString(_key(ownerId));
    if (raw == null || raw.isEmpty) return <TaskModel>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <TaskModel>[];
      return decoded
          .whereType<Map>()
          .map((item) => _fromJson(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    } catch (_) {
      return <TaskModel>[];
    }
  }

  Future<String> create(TaskModel task) async {
    final id = task.id.isEmpty ? _uuid.v4() : task.id;
    final stored = task.copyWith(id: id);
    final tasks = await load(stored.ownerId);
    tasks.removeWhere((existing) => existing.id == id);
    tasks.add(stored);
    await _save(stored.ownerId, tasks);
    return id;
  }

  Future<void> update(TaskModel task) async {
    final tasks = await load(task.ownerId);
    final index = tasks.indexWhere((existing) => existing.id == task.id);
    if (index == -1) {
      tasks.add(task);
    } else {
      tasks[index] = task;
    }
    await _save(task.ownerId, tasks);
  }

  Future<TaskModel?> get(String ownerId, String taskId) async {
    final tasks = await load(ownerId);
    for (final task in tasks) {
      if (task.id == taskId) return task;
    }
    return null;
  }

  Future<void> delete(TaskModel task) async {
    final tasks = await load(task.ownerId);
    tasks.removeWhere((existing) => existing.id == task.id);
    await _save(task.ownerId, tasks);
  }

  Future<void> _save(String ownerId, List<TaskModel> tasks) async {
    await _prefs.setString(
      _key(ownerId),
      jsonEncode(tasks.map(_toJson).toList()),
    );
    _changes.add(ownerId);
  }

  Map<String, dynamic> _toJson(TaskModel task) => {
        'id': task.id,
        'title': task.title,
        'description': task.description,
        'taskType': task.taskType.name,
        'priority': task.priority.name,
        'status': task.status.name,
        'ownerId': task.ownerId,
        'createdBy': task.createdBy,
        'createdByName': task.createdByName,
        'assignedTo': task.assignedTo,
        'assignedToName': task.assignedToName,
        'familyId': task.familyId,
        'visibility': task.visibility,
        'assetId': task.assetId,
        'assetName': task.assetName,
        'assetEmoji': task.assetEmoji,
        'dueDate': task.dueDate.millisecondsSinceEpoch,
        'dueTime': task.dueTime?.millisecondsSinceEpoch,
        'isAllDay': task.isAllDay,
        'reminderEnabled': task.reminderEnabled,
        'reminderMinutesBefore': task.reminderMinutesBefore,
        'repeatType': task.repeatType.name,
        'repeatInterval': task.repeatInterval,
        'repeatEndDate': task.repeatEndDate?.millisecondsSinceEpoch,
        'completedAt': task.completedAt?.millisecondsSinceEpoch,
        'completedBy': task.completedBy,
        'completedByName': task.completedByName,
        'cancelledAt': task.cancelledAt?.millisecondsSinceEpoch,
        'snoozedUntil': task.snoozedUntil?.millisecondsSinceEpoch,
        'createdAt': task.createdAt.millisecondsSinceEpoch,
        'updatedAt': task.updatedAt.millisecondsSinceEpoch,
      };

  TaskModel _fromJson(Map<String, dynamic> d) => TaskModel(
        id: d['id'] as String? ?? '',
        title: d['title'] as String? ?? '',
        description: d['description'] as String?,
        taskType: TaskType.fromFirestore(d['taskType'] as String?),
        priority: TaskPriority.fromFirestore(d['priority'] as String?),
        status: TaskStatus.fromFirestore(d['status'] as String?),
        ownerId: d['ownerId'] as String? ?? '',
        createdBy: d['createdBy'] as String? ?? '',
        createdByName: d['createdByName'] as String?,
        assignedTo: d['assignedTo'] as String?,
        assignedToName: d['assignedToName'] as String?,
        familyId: d['familyId'] as String?,
        visibility: d['visibility'] as String? ?? 'personal',
        assetId: d['assetId'] as String?,
        assetName: d['assetName'] as String?,
        assetEmoji: d['assetEmoji'] as String?,
        dueDate: DateTime.fromMillisecondsSinceEpoch(
          (d['dueDate'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        ),
        dueTime: _date(d['dueTime']),
        isAllDay: d['isAllDay'] as bool? ?? false,
        reminderEnabled: d['reminderEnabled'] as bool? ?? true,
        reminderMinutesBefore: (d['reminderMinutesBefore'] as num?)?.toInt() ?? 15,
        repeatType: RepeatType.fromFirestore(d['repeatType'] as String?),
        repeatInterval: (d['repeatInterval'] as num?)?.toInt(),
        repeatEndDate: _date(d['repeatEndDate']),
        completedAt: _date(d['completedAt']),
        completedBy: d['completedBy'] as String?,
        completedByName: d['completedByName'] as String?,
        cancelledAt: _date(d['cancelledAt']),
        snoozedUntil: _date(d['snoozedUntil']),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (d['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (d['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );

  DateTime? _date(dynamic value) => value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
      : null;
}
