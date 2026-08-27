import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/task_model.dart';

typedef NotificationSelectCallback = void Function(String? taskId);

class TaskNotificationService {
  static final TaskNotificationService _instance = TaskNotificationService._internal();
  factory TaskNotificationService() => _instance;
  TaskNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  NotificationSelectCallback? _onNotificationSelected;

  void setNotificationSelectCallback(NotificationSelectCallback callback) {
    _onNotificationSelected = callback;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize Timezones
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          _onNotificationSelected?.call(response.payload);
        }
      },
    );

    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS || Platform.isMacOS) {
      final darwinImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await darwinImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  int _generateNotificationId(String taskId) {
    return taskId.hashCode.abs() % 2147483647;
  }

  Future<void> scheduleTaskNotification(TaskModel task) async {
    if (!task.reminderEnabled || task.status == TaskStatus.completed || task.status == TaskStatus.cancelled) {
      await cancelTaskNotification(task.id);
      return;
    }

    await initialize();

    final scheduledDateTime = task.effectiveDueDateTime.subtract(
      Duration(minutes: task.reminderMinutesBefore),
    );

    // If the scheduled time is in the past, don't schedule
    if (scheduledDateTime.isBefore(DateTime.now())) {
      return;
    }

    final notificationId = _generateNotificationId(task.id);

    final androidDetails = AndroidNotificationDetails(
      'task_reminders_channel',
      'Task Reminders',
      channelDescription: 'Notifications for upcoming asset tasks and reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final tzDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        '${task.taskType.icon} ${task.title}',
        task.assetName != null ? 'Asset: ${task.assetName}' : task.description ?? 'Scheduled Task',
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: task.id,
      );
    } catch (e) {
      debugPrint('Error scheduling local notification: $e');
    }
  }

  Future<void> cancelTaskNotification(String taskId) async {
    await initialize();
    final notificationId = _generateNotificationId(taskId);
    await _notificationsPlugin.cancel(notificationId);
  }

  Future<void> cancelAllNotifications() async {
    await initialize();
    await _notificationsPlugin.cancelAll();
  }
}
