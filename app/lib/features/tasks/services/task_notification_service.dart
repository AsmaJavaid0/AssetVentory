import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as timezone;
import '../models/task_model.dart';

typedef NotificationSelectCallback = void Function(String? taskId);

class TaskNotificationService {
  static final TaskNotificationService _instance = TaskNotificationService._internal();
  factory TaskNotificationService() => _instance;
  TaskNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _permissionRequested = false;
  NotificationSelectCallback? _onNotificationSelected;

  void setNotificationSelectCallback(NotificationSelectCallback callback) => _onNotificationSelected = callback;

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    final deviceTimeZone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(deviceTimeZone.identifier));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notificationsPlugin.initialize(
      InitializationSettings(android: androidSettings, iOS: darwinSettings, macOS: darwinSettings),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _onNotificationSelected?.call(payload);
      },
    );

    final android = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'task_reminders_channel',
        'Task Reminders',
        description: 'Notifications for upcoming asset tasks and reminders',
        importance: Importance.high,
      ),
    );
    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();

    if (Platform.isAndroid) {
      final android = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final notificationGranted = await android?.requestNotificationsPermission() ?? false;
      if (notificationGranted) {
        await android?.requestExactAlarmsPermission();
      }
      _permissionRequested = true;
      return notificationGranted;
    }

    if (Platform.isIOS || Platform.isMacOS) {
      final darwin = _notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final granted = await darwin?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      _permissionRequested = true;
      return granted;
    }

    return true;
  }

  Future<bool> ensureReadyForScheduling() async {
    await initialize();
    if (!_permissionRequested) await requestPermissions();

    if (Platform.isAndroid) {
      final android = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await android?.areNotificationsEnabled() ?? true;
      if (!enabled) return false;

      final exactAlarmGranted = await android?.canScheduleExactNotifications() ?? true;
      if (!exactAlarmGranted) {
        debugPrint('Task reminder not scheduled: exact alarm permission is disabled.');
        return false;
      }
    }
    return true;
  }

  int _generateNotificationId(String taskId) => taskId.hashCode.abs() % 2147483647;

  Future<void> scheduleTaskNotification(TaskModel task) async {
    if (!task.reminderEnabled || task.status == TaskStatus.completed || task.status == TaskStatus.cancelled) {
      await cancelTaskNotification(task.id);
      return;
    }
    if (!await ensureReadyForScheduling()) {
      debugPrint('Task reminder not scheduled: notification/alarm permission is disabled.');
      return;
    }

    final scheduledDateTime = task.effectiveDueDateTime.subtract(Duration(minutes: task.reminderMinutesBefore));
    if (!scheduledDateTime.isAfter(DateTime.now())) {
      debugPrint('Task reminder not scheduled because its reminder time is in the past: $scheduledDateTime');
      return;
    }

    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        'task_reminders_channel',
        'Task Reminders',
        channelDescription: 'Notifications for upcoming asset tasks and reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      macOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    final notificationId = _generateNotificationId(task.id);
    final scheduled = timezone.TZDateTime.from(scheduledDateTime, timezone.local);

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      '${task.taskType.icon} ${task.title}',
      task.assetName != null ? 'Asset: ${task.assetName}' : task.description ?? 'Scheduled Task',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: task.id,
    );

    debugPrint('Task reminder scheduled for $scheduled (id=$notificationId, tz=${timezone.local.name})');
  }

  Future<void> cancelTaskNotification(String taskId) async {
    await initialize();
    await _notificationsPlugin.cancel(_generateNotificationId(taskId));
  }

  Future<void> cancelAllNotifications() async {
    await initialize();
    await _notificationsPlugin.cancelAll();
  }
}
