// ignore_for_file: avoid_dynamic_calls

import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:times_up_flutter/firebase_options_dev.dart';
import 'package:times_up_flutter/services/app_blocker_service.dart';
import 'package:times_up_flutter/services/child_background_sync.dart';
import 'package:times_up_flutter/services/screen_rule_service.dart';
import 'package:times_up_flutter/widgets/show_logger.dart';

const notificationChannelId = 'high_importance_channel';
const notificationChannelTitle = 'High Importance Notifications';
const notificationId = 800;

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  notificationChannelId,
  notificationChannelTitle,
  description: 'This channel is used for important notifications.',
  importance: Importance.max,
);

bool _backgroundLocalNotificationsReady = false;

Future<void> _ensureLocalNotificationsReady() async {
  if (_backgroundLocalNotificationsReady) return;
  await NotificationService.flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/parental_launch'),
    ),
  );
  await NotificationService.flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  _backgroundLocalNotificationsReady = true;
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await _ensureLocalNotificationsReady();
  await _handleBlockedAppsData(message.data);
  await showRemoteMessageNotification(message);
}

Future<void> _handleBlockedAppsData(Map<String, dynamic> data) async {
  if (data['type'] != 'blocked_apps') return;
  final packageName = data['packageName'] as String? ?? '';
  final blockedRaw = data['blocked'];
  final blocked = blockedRaw == true ||
      blockedRaw == 'true' ||
      blockedRaw == 1 ||
      blockedRaw == '1';
  await AppBlockerService.instance.applyFcmUpdate(
    packageName: packageName,
    blocked: blocked,
  );
}

Future<void> showRemoteMessageNotification(RemoteMessage message) async {
  final notification = message.notification;
  final title = notification?.title ??
      message.data['title'] ??
      'Notification';
  final body = notification?.body ??
      message.data['message'] ??
      message.data['body'] ??
      '';
  if (title.isEmpty && body.isEmpty) return;

  final androidDetails = AndroidNotificationDetails(
    channel.id,
    channel.name,
    icon: notification?.android?.smallIcon ?? 'parental_launch',
    color: Colors.black,
    channelDescription: channel.description,
    importance: Importance.max,
    priority: Priority.high,
    colorized: true,
  );

  await NotificationService.flutterLocalNotificationsPlugin.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(android: androidDetails),
  );
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // ponytail: 1-min tick — GPS+battery @5m, app usage @10m, FGS toast @15m
  var tick = 0;
  Timer.periodic(const Duration(seconds: 2), (_) async {
    await runAppBlockCheck();
  });
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    tick++;
    await ScreenRuleService.checkRulesFromCache();
    if (tick % 5 == 0) {
      await runBackgroundChildSync(syncApps: false);
    }
    if (tick % 10 == 0) {
      await runBackgroundChildSync(syncApps: true);
    }
    if (tick % 15 == 0) {
      await NotificationService.flutterLocalNotificationsPlugin.show(
        notificationId,
        'Times Up - Monitoring',
        'Tracking App Usage and live location',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            notificationChannelId,
            notificationChannelTitle,
            icon: 'parental_launch',
            ongoing: true,
            importance: Importance.max,
          ),
        ),
      );
    }
  });
}

class NotificationService {
  factory NotificationService() {
    return _singleton;
  }

  NotificationService._internal();
  static final NotificationService _singleton = NotificationService._internal();

  /// Child UI registers this to open the notifications drawer on FCM tap.
  static void Function()? onOpenNotifications;

  // Here the set up for cloud Messaging Android is being configured
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    try {
      final service = FlutterBackgroundService();
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/parental_launch'),
        ),
      );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // ponytail: autoStart off — configure persists FGS type before any start (API 36).
      await service.configure(
        iosConfiguration: IosConfiguration(autoStart: false),
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          autoStartOnBoot: true,
          isForegroundMode: true,
          notificationChannelId: notificationChannelId,
          initialNotificationTitle: 'Times Up Flutter Launched',
          initialNotificationContent: 'The app is tracking metadata',
          foregroundServiceNotificationId: notificationId,
        ),
      );
    } catch (e) {
      JHLogger.$.e(e);
    }
  }

  /// Starts the foreground monitoring service after [initialize] has run.
  Future<void> startBackgroundMonitoring() async {
    try {
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }
    } catch (e) {
      JHLogger.$.e(e);
    }
  }

// Lazy — Firebase must be initialized in main before first use.
  FirebaseMessaging get messaging => FirebaseMessaging.instance;

  Future<void> _requestPermissions() async {
    final androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
  }

  void _handleNotificationOpened(RemoteMessage message) {
    onOpenNotifications?.call();
  }

  /// Foreground and tap handlers — background uses [firebaseMessagingBackgroundHandler].
  Future<void> configureFirebaseMessaging({
    Future<void> Function(String token)? onTokenRefresh,
  }) async {
    try {
      await _requestPermissions();
      FirebaseMessaging.onMessage.listen((message) async {
        await _handleBlockedAppsData(message.data);
        await showRemoteMessageNotification(message);
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);
      if (onTokenRefresh != null) {
        FirebaseMessaging.instance.onTokenRefresh.listen(onTokenRefresh);
      }
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationOpened(initialMessage);
      }
    } on Exception catch (e) {
      throw Exception(e.toString());
    }
  }
}
