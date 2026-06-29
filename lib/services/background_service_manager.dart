import 'package:times_up_flutter/services/notification_service.dart';
import 'package:times_up_flutter/services/shared_preferences.dart';
import 'package:times_up_flutter/widgets/show_logger.dart';

/// Owns foreground background-service lifecycle, independent of UI routes.
class BackgroundServiceManager {
  BackgroundServiceManager._();

  static final BackgroundServiceManager instance = BackgroundServiceManager._();

  bool _configured = false;

  void markConfigured() {
    _configured = true;
  }

  /// Call from main after binding is initialized.
  static Future<void> initializeAppServices() async {
    final notificationService = NotificationService();
    await notificationService.initialize();
    instance.markConfigured();
    await notificationService.configureFirebaseMessaging();
    await instance.startIfChildDevice();
  }

  /// Starts monitoring on child devices after configure has registered FGS type.
  Future<void> startIfChildDevice() async {
    if (!_configured) {
      JHLogger.$.w('BackgroundServiceManager: configure not done yet');
      return;
    }
    final isParent = await CacheService.getParentOrChild();
    if (isParent) return;

    // ponytail: one event-loop turn — avoid configure+start same frame (API 36)
    await Future<void>.delayed(Duration.zero);
    await NotificationService().startBackgroundMonitoring();
  }
}
