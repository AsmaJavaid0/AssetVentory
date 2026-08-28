import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/services/firestore_service.dart';
import '../models/task_model.dart';
import 'local_task_store.dart';
import 'task_notification_service.dart';

/// Task orchestration layer.
///
/// Personal tasks are local-only. Family tasks are the only tasks written to
/// Firestore. Local notifications are deliberately scheduled independently of
/// Firebase/network availability.
class TaskService {
  final FirestoreService _firestoreService;
  final TaskNotificationService _notificationService;
  final LocalTaskStore _localStore;

  TaskService({
    FirestoreService? firestoreService,
    TaskNotificationService? notificationService,
    LocalTaskStore? localStore,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _notificationService = notificationService ?? TaskNotificationService(),
        _localStore = localStore ?? LocalTaskStore();

  bool _isFamilyTask(TaskModel task) =>
      task.visibility == 'family' ||
      task.taskType == TaskType.familyTask ||
      (task.familyId?.isNotEmpty ?? false) &&
          (task.assignedTo?.isNotEmpty ?? false) &&
          task.assignedTo != task.createdBy;

  Stream<List<TaskModel>> streamVisibleTasks(String uid, {String? familyId}) async* {
    // Personal tasks never depend on Firebase.
    final localTasks = await _localStore.load(uid);
    final familyStream = familyId == null || familyId.isEmpty
        ? const Stream<List<TaskModel>>.empty()
        : _firestoreService.streamVisibleTasks(uid, familyId: familyId);

    // Emit local tasks immediately. Family tasks are then added when Firebase
    // has a result; a Firestore error must not hide the local list.
    yield localTasks;
    try {
      await for (final familyTasks in familyStream) {
        final currentLocal = await _localStore.load(uid);
        final merged = <String, TaskModel>{
          for (final task in currentLocal) task.id: task,
          for (final task in familyTasks)
            if (_isFamilyTask(task)) task.id: task,
        };
        yield merged.values.toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      }
    } catch (e) {
      debugPrint('Family task stream unavailable; continuing with local tasks: $e');
    }
  }

  Future<TaskModel?> getTask(String taskId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'local_user';
    final local = await _localStore.get(userId, taskId);
    if (local != null) return local;
    try {
      return await _firestoreService.getTask(taskId);
    } catch (e) {
      debugPrint('Remote task lookup unavailable: $e');
      return null;
    }
  }

  Future<String> createTask(TaskModel task) async {
    if (_isFamilyTask(task)) {
      // Explicit family assignment is the only path that touches Firestore.
      final taskId = await _firestoreService.createTask(task);
      final createdTask = task.copyWith(id: taskId);
      await _schedule(createdTask);
      return taskId;
    }

    final localTask = task.copyWith(
      familyId: null,
      assignedTo: task.createdBy,
      assignedToName: task.createdByName,
      visibility: 'personal',
      taskType: task.taskType == TaskType.familyTask
          ? TaskType.generalTask
          : task.taskType,
    );
    final taskId = await _localStore.create(localTask);
    final createdTask = localTask.copyWith(id: taskId);
    await _schedule(createdTask);
    return taskId;
  }

  Future<void> updateTask(TaskModel task) async {
    if (_isFamilyTask(task)) {
      await _firestoreService.updateTask(task);
    } else {
      await _localStore.update(task.copyWith(
        familyId: null,
        assignedTo: task.createdBy,
        visibility: 'personal',
      ));
    }

    try {
      await _notificationService.cancelTaskNotification(task.id);
      if (task.reminderEnabled && task.status == TaskStatus.pending) {
        await _schedule(task);
      }
    } catch (e) {
      debugPrint('Warning: Rescheduling notification failed: $e');
    }
  }

  Future<void> completeTask(
    TaskModel task, {
    required String completedBy,
    String? completedByName,
  }) async {
    final completed = task.copyWith(
      status: TaskStatus.completed,
      completedBy: completedBy,
      completedByName: completedByName,
      completedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (_isFamilyTask(task)) {
      await _firestoreService.completeTask(
        task.id,
        completedBy: completedBy,
        completedByName: completedByName,
      );
    } else {
      await _localStore.update(completed);
    }
    await _notificationService.cancelTaskNotification(task.id);
  }

  Future<void> snoozeTask(TaskModel task, DateTime snoozeUntil) async {
    final snoozed = task.copyWith(snoozedUntil: snoozeUntil, updatedAt: DateTime.now());
    if (_isFamilyTask(task)) {
      await _firestoreService.snoozeTask(task.id, snoozeUntil);
    } else {
      await _localStore.update(snoozed);
    }
    await _notificationService.cancelTaskNotification(task.id);
    if (snoozed.reminderEnabled) await _schedule(snoozed);
  }

  Future<void> deleteTask(TaskModel task) async {
    if (_isFamilyTask(task)) {
      await _firestoreService.deleteTask(task.id);
    } else {
      await _localStore.delete(task);
    }
    await _notificationService.cancelTaskNotification(task.id);
  }

  Future<void> _schedule(TaskModel task) async {
    if (!task.reminderEnabled) return;
    try {
      await _notificationService.scheduleTaskNotification(task);
    } catch (e) {
      debugPrint('Warning: Local notification scheduling failed: $e');
    }
  }
}
