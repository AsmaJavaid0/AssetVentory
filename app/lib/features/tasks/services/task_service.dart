import 'package:flutter/foundation.dart';
import '../../auth/services/firestore_service.dart';
import '../models/task_model.dart';
import 'task_notification_service.dart';

class TaskService {
  final FirestoreService _firestoreService;
  final TaskNotificationService _notificationService;

  TaskService({
    FirestoreService? firestoreService,
    TaskNotificationService? notificationService,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _notificationService = notificationService ?? TaskNotificationService();

  /// Stream visible tasks for a user
  Stream<List<TaskModel>> streamVisibleTasks(String uid, {String? familyId}) {
    return _firestoreService.streamVisibleTasks(uid, familyId: familyId);
  }

  /// Get single task by ID
  Future<TaskModel?> getTask(String taskId) async {
    return await _firestoreService.getTask(taskId);
  }

  /// Create a new task and schedule local notification if enabled
  Future<String> createTask(TaskModel task) async {
    try {
      final taskId = await _firestoreService.createTask(task);
      final createdTask = task.copyWith(id: taskId);

      // Schedule local notification non-blocking if reminder is enabled
      if (createdTask.reminderEnabled) {
        try {
          await _notificationService
              .scheduleTaskNotification(createdTask)
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          debugPrint('Warning: Local notification scheduling failed: $e');
        }
      }

      return taskId;
    } catch (e) {
      debugPrint('Error in TaskService.createTask: $e');
      rethrow;
    }
  }

  /// Update task and reschedule notifications
  Future<void> updateTask(TaskModel task) async {
    try {
      await _firestoreService.updateTask(task);

      // Recalculate and reschedule notification non-blocking
      try {
        await _notificationService
            .cancelTaskNotification(task.id)
            .timeout(const Duration(seconds: 2));
        if (task.reminderEnabled && task.status == TaskStatus.pending) {
          await _notificationService
              .scheduleTaskNotification(task)
              .timeout(const Duration(seconds: 3));
        }
      } catch (e) {
        debugPrint('Warning: Rescheduling notification failed: $e');
      }
    } catch (e) {
      debugPrint('Error in TaskService.updateTask: $e');
      rethrow;
    }
  }

  /// Mark task as completed
  Future<void> completeTask(
    TaskModel task, {
    required String completedBy,
    String? completedByName,
  }) async {
    try {
      await _firestoreService.completeTask(
        task.id,
        completedBy: completedBy,
        completedByName: completedByName,
      );

      // Cancel scheduled local notification when completed
      await _notificationService.cancelTaskNotification(task.id);
    } catch (e) {
      debugPrint('Error in TaskService.completeTask: $e');
      rethrow;
    }
  }

  /// Snooze task to a new target time
  Future<void> snoozeTask(TaskModel task, DateTime snoozeUntil) async {
    try {
      await _firestoreService.snoozeTask(task.id, snoozeUntil);

      final snoozedTask = task.copyWith(snoozedUntil: snoozeUntil);
      await _notificationService.cancelTaskNotification(task.id);
      if (snoozedTask.reminderEnabled) {
        await _notificationService.scheduleTaskNotification(snoozedTask);
      }
    } catch (e) {
      debugPrint('Error in TaskService.snoozeTask: $e');
      rethrow;
    }
  }

  /// Delete task and cancel notification
  Future<void> deleteTask(TaskModel task) async {
    try {
      await _firestoreService.deleteTask(task.id);
      await _notificationService.cancelTaskNotification(task.id);
    } catch (e) {
      debugPrint('Error in TaskService.deleteTask: $e');
      rethrow;
    }
  }
}
