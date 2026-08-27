import 'package:flutter/foundation.dart';
import '../../auth/services/firestore_service.dart';
import '../models/task_model.dart';
import 'task_notification_service.dart';

class TaskService {
  final FirestoreService _firestoreService;
  final TaskNotificationService _notificationService;
  TaskService({FirestoreService? firestoreService, TaskNotificationService? notificationService}) : _firestoreService = firestoreService ?? FirestoreService(), _notificationService = notificationService ?? TaskNotificationService();

  Stream<List<TaskModel>> streamVisibleTasks(String uid, {String? familyId}) => _firestoreService.streamVisibleTasks(uid, familyId: familyId);
  Future<TaskModel?> getTask(String taskId) => _firestoreService.getTask(taskId);

  Future<String> createTask(TaskModel task) async {
    final taskId = await _firestoreService.createTask(task);
    final createdTask = task.copyWith(id: taskId);
    if (createdTask.reminderEnabled) {
      try { await _notificationService.scheduleTaskNotification(createdTask); }
      catch (e) { debugPrint('Warning: Local notification scheduling failed: $e'); }
    }
    return taskId;
  }

  Future<void> updateTask(TaskModel task) async {
    await _firestoreService.updateTask(task);
    try {
      await _notificationService.cancelTaskNotification(task.id);
      if (task.reminderEnabled && task.status == TaskStatus.pending) await _notificationService.scheduleTaskNotification(task);
    } catch (e) { debugPrint('Warning: Rescheduling notification failed: $e'); }
  }

  Future<void> completeTask(TaskModel task, {required String completedBy, String? completedByName}) async {
    await _firestoreService.completeTask(task.id, completedBy: completedBy, completedByName: completedByName);
    await _notificationService.cancelTaskNotification(task.id);
  }

  Future<void> snoozeTask(TaskModel task, DateTime snoozeUntil) async {
    await _firestoreService.snoozeTask(task.id, snoozeUntil);
    final snoozedTask = task.copyWith(snoozedUntil: snoozeUntil);
    await _notificationService.cancelTaskNotification(task.id);
    if (snoozedTask.reminderEnabled) await _notificationService.scheduleTaskNotification(snoozedTask);
  }

  Future<void> deleteTask(TaskModel task) async {
    await _firestoreService.deleteTask(task.id);
    await _notificationService.cancelTaskNotification(task.id);
  }
}
