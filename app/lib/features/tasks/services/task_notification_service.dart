import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as timezone;
import '../../../core/di/service_locator.dart';
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
    try {
      final dynamic tzResult = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = tzResult is String ? tzResult : tzResult.toString();
      timezone.setLocalLocation(timezone.getLocation(timeZoneName));
      debugPrint('TaskNotificationService: Timezone set to $timeZoneName');
    } catch (e) {
      debugPrint('TaskNotificationService: Timezone detection fallback: $e');
      final now = DateTime.now();
      final offsetMillis = now.timeZoneOffset.inMilliseconds;
      timezone.Location? matchedLoc;
      for (final loc in timezone.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == offsetMillis) {
          matchedLoc = loc;
          break;
        }
      }
      timezone.setLocalLocation(matchedLoc ?? timezone.getLocation('UTC'));
      debugPrint('TaskNotificationService: Timezone fallback to ${timezone.local.name}');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: darwinSettings, macOS: darwinSettings),
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final actionId = response.actionId;
        final payload = response.payload;

        if (actionId == 'dismiss_alarm' && payload != null && payload.isNotEmpty) {
          await cancelTaskNotification(payload);
          return;
        }

        if (actionId == 'snooze_10' && payload != null && payload.isNotEmpty) {
          await cancelTaskNotification(payload);
          try {
            final taskService = serviceLocator.taskService;
            final task = await taskService.getTask(payload);
            if (task != null) {
              await taskService.snoozeTask(task, DateTime.now().add(const Duration(minutes: 10)));
            }
          } catch (e) {
            debugPrint('Error snoozing task from alarm action: $e');
          }
          return;
        }

        if (payload != null && payload.isNotEmpty) {
          _onNotificationSelected?.call(payload);
        }
      },
    );

    final android = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Delete legacy notification channels to clear cached sounds
    try {
      await android?.deleteNotificationChannel('task_alarms_channel');
      await android?.deleteNotificationChannel('task_reminders_channel');
    } catch (_) {}

    const defaultAlarmSound = UriAndroidNotificationSound('content://settings/system/alarm_alert');

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'assetventory_alarm_clock_v2',
        'AssetVentory Alarm Clock',
        description: 'Loud alarm clock ringtone for scheduled tasks',
        importance: Importance.max,
        playSound: true,
        sound: defaultAlarmSound,
        enableVibration: true,
        enableLights: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'assetventory_reminders_v2',
        'AssetVentory Reminders',
        description: 'Notifications and reminders for scheduled tasks',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        audioAttributesUsage: AudioAttributesUsage.notification,
      ),
    );
    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();

    if (Platform.isAndroid) {
      final android = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final notificationGranted = await android?.requestNotificationsPermission() ?? false;
      try {
        await android?.requestExactAlarmsPermission();
      } catch (_) {}
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
        debugPrint('Task reminder: exact alarm permission not granted, will attempt schedule with fallback.');
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
      debugPrint('Task reminder not scheduled: notification permission is disabled.');
      return;
    }

    final now = DateTime.now();
    final effectiveDue = task.effectiveDueDateTime;

    // If the task itself is in the past by more than 1 minute, don't schedule
    if (effectiveDue.isBefore(now.subtract(const Duration(minutes: 1)))) {
      debugPrint('Task reminder not scheduled because task due time has passed: $effectiveDue');
      return;
    }

    DateTime scheduledDateTime = effectiveDue.subtract(Duration(minutes: task.reminderMinutesBefore));

    // If the scheduled pre-reminder time is already in the past, but the due time is upcoming or right now:
    if (!scheduledDateTime.isAfter(now)) {
      if (effectiveDue.isAfter(now)) {
        scheduledDateTime = effectiveDue;
      } else {
        // Due right now: schedule 2 seconds ahead so zonedSchedule accepts it
        scheduledDateTime = now.add(const Duration(seconds: 2));
      }
    }

    final bool isAlarm = task.taskType == TaskType.alarm;
    final String channelId = isAlarm ? 'assetventory_alarm_clock_v2' : 'assetventory_reminders_v2';
    final String channelName = isAlarm ? 'AssetVentory Alarm Clock' : 'AssetVentory Reminders';
    const defaultAlarmSound = UriAndroidNotificationSound('content://settings/system/alarm_alert');

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Notifications and alarms for asset tasks',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: isAlarm ? defaultAlarmSound : null,
        enableVibration: true,
        enableLights: true,
        fullScreenIntent: true,
        ongoing: isAlarm,
        autoCancel: !isAlarm,
        category: isAlarm ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
        audioAttributesUsage: isAlarm ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
        actions: isAlarm
            ? <AndroidNotificationAction>[
                const AndroidNotificationAction(
                  'dismiss_alarm',
                  'Stop Alarm ⏹️',
                  cancelNotification: true,
                  showsUserInterface: false,
                ),
                const AndroidNotificationAction(
                  'snooze_10',
                  'Snooze 10m ⏳',
                  cancelNotification: true,
                  showsUserInterface: false,
                ),
              ]
            : null,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: isAlarm ? InterruptionLevel.critical : InterruptionLevel.timeSensitive,
      ),
      macOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    final notificationId = _generateNotificationId(task.id);
    final scheduled = timezone.TZDateTime.from(scheduledDateTime, timezone.local);

    // Cancel any previous notification with this ID before scheduling a new one
    await _notificationsPlugin.cancel(notificationId);

    try {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        '${task.taskType.icon} ${task.title}',
        task.assetName != null ? 'Asset: ${task.assetName}' : (task.description?.isNotEmpty == true ? task.description! : 'Scheduled Task Alarm'),
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: task.id,
      );
      debugPrint('Task alarm successfully scheduled for $scheduled (id=$notificationId, isAlarm=$isAlarm, tz=${timezone.local.name})');
    } catch (e) {
      debugPrint('Exact alarm scheduling failed with exactAllowWhileIdle ($e), falling back to inexact schedule');
      try {
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          '${task.taskType.icon} ${task.title}',
          task.assetName != null ? 'Asset: ${task.assetName}' : (task.description?.isNotEmpty == true ? task.description! : 'Scheduled Task Alarm'),
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: task.id,
        );
        debugPrint('Task alarm fallback scheduled for $scheduled');
      } catch (fallbackError) {
        debugPrint('Fallback zonedSchedule failed: $fallbackError');
      }
    }
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
