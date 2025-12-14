import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../core/utils/logger.dart';

/// Service for handling local push notifications.
/// Schedules daily reminders for completing challenges.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Notification channel for Android
  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Daily Reminders';
  static const String _channelDescription =
      'Reminders to complete your daily challenge';

  /// Notification ID for daily reminder
  static const int _dailyReminderId = 1001;

  /// Initialize the notification service.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone data
    tz_data.initializeTimeZones();

    // Set local timezone - use IST for India, fallback to UTC
    try {
      // Try to use Asia/Kolkata for India
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      logger.i('Timezone set to: Asia/Kolkata');
    } catch (e) {
      // Fallback to UTC if location not found
      tz.setLocalLocation(tz.UTC);
      logger.w('Timezone fallback to UTC: $e');
    }

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    _isInitialized = true;
    logger.i('NotificationService initialized successfully');
  }

  /// Create Android notification channel.
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  /// Request notification permissions (especially for iOS).
  Future<bool> requestPermissions() async {
    // Request permission for iOS
    final iosPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    // Request permission for Android 13+
    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? true;
    }

    return true;
  }

  /// Schedule daily reminder at the specified time.
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await cancelDailyReminder();

    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    logger.i('=== SCHEDULING NOTIFICATION ===');
    logger.i('Current time: $now');
    logger.i(
      'Requested time: ${time.hour}:${time.minute.toString().padLeft(2, '0')}',
    );
    logger.i('Scheduled DateTime: $scheduledDate');
    logger.i('TZ Scheduled DateTime: $tzScheduledDate');
    logger.i('Timezone: ${tz.local.name}');

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        'Time to build your confidence! Complete today\'s challenge and keep your streak going. 🎯',
        contentTitle: '🎬 Daily Challenge Awaits!',
        htmlFormatBigText: false,
        htmlFormatContentTitle: false,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      _dailyReminderId,
      '🎬 Daily Challenge Awaits!',
      'Time to build your confidence! Complete today\'s challenge. 🎯',
      tzScheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    // Verify the notification was scheduled
    final pending = await _notifications.pendingNotificationRequests();
    logger.i('Pending notifications after scheduling: ${pending.length}');
    for (final p in pending) {
      logger.i('  - ID: ${p.id}, Title: ${p.title}');
    }
    logger.i('=== NOTIFICATION SCHEDULED ===');
  }

  /// Cancel the daily reminder.
  Future<void> cancelDailyReminder() async {
    await _notifications.cancel(_dailyReminderId);
    logger.d('Daily reminder cancelled');
  }

  /// Cancel all notifications.
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    logger.d('All notifications cancelled');
  }

  /// Show an immediate test notification.
  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      '🎬 Test Notification',
      'Notifications are working! You\'ll be reminded to complete your daily challenge.',
      notificationDetails,
    );

    logger.i('Test notification shown');
  }

  /// Check if notifications are scheduled.
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Handle notification tap.
  void _onNotificationTapped(NotificationResponse response) {
    logger.d('Notification tapped: ${response.payload}');
    // Navigation can be handled here if needed
  }
}
