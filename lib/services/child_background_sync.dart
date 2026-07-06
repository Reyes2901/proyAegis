import 'package:battery_plus/battery_plus.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:geolocator/geolocator.dart';

import 'package:intl/intl.dart';

import 'package:times_up_flutter/firebase_options_dev.dart';

import 'package:times_up_flutter/services/app_blocker_service.dart';

import 'package:times_up_flutter/services/app_usage_local_service.dart';

import 'package:times_up_flutter/services/app_usage_monitor_service.dart';

import 'package:times_up_flutter/services/location_history_service.dart';

import 'package:times_up_flutter/services/shared_preferences.dart';

import 'package:times_up_flutter/services/screen_rule_service.dart';
import 'package:times_up_flutter/services/usage_aggregation_service.dart';

import 'package:times_up_flutter/widgets/show_logger.dart';



/// Background-isolate sync for the linked child device.

///

/// Intervals (see [notification_service.dart] tick): GPS + battery every 5 min,

/// app usage every 10 min — apps cost more (UsageStats + icon merge).

Future<void> runBackgroundChildSync({required bool syncApps}) async {

  try {

    if (Firebase.apps.isEmpty) {

      await Firebase.initializeApp(

        options: DefaultFirebaseOptions.currentPlatform,

      );

    }



    final ctx = await CacheService.getChildSyncContext();

    final parentUid = ctx.parentUid;

    final childId = ctx.childId;

    if (parentUid == null || childId == null) {

      JHLogger.$.w('Background sync skipped: no child context in prefs');

      return;

    }



    final updates = <String, dynamic>{};

    String? batteryLevel;

    Position? lastPosition;



    if (syncApps) {

      final end = DateTime.now();

      final startHour = end.subtract(const Duration(hours: 1));

      final startDaily = end.subtract(const Duration(minutes: 10));

      try {

        final appsHour = await AppUsage.getAppUsage(startHour, end, useMock: false);

        updates['appsUsageModel'] = appsHour.map((a) => a.toMap()).toList();



        final appsDaily =

            await AppUsage.getAppUsage(startDaily, end, useMock: false);

        final increments = incrementsFromAppUsage(appsDaily);

        final dateId = DateFormat('yyyy-MM-dd').format(end);

        await applyDailyUsageIncrements(

          parentUid: parentUid,

          childId: childId,

          dateId: dateId,

          increments: increments,

        );

        await AppUsageMonitorService.instance.checkLimitsForChild(

          parentUid: parentUid,

          childId: childId,

        );

        await ScreenRuleService.refreshRulesFromFirestore(

          parentUid: parentUid,

          childId: childId,

        );

        await runAppBlockCheck();

      } catch (e) {

        JHLogger.$.e('Background app usage sync failed: $e');

      }

    }



    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {

      await Geolocator.requestPermission();

    }

    if (await Geolocator.isLocationServiceEnabled()) {

      final perm = await Geolocator.checkPermission();

      if (perm == LocationPermission.always ||

          perm == LocationPermission.whileInUse) {

        try {

          final pos = await Geolocator.getCurrentPosition(

            desiredAccuracy: LocationAccuracy.high,

          );

          lastPosition = pos;

          updates['position'] = GeoPoint(pos.latitude, pos.longitude);

        } catch (e) {

          JHLogger.$.e('Background GPS sync failed: $e');

        }

      }

    }



    try {

      final level = await Battery().batteryLevel;

      batteryLevel = level.toString();

      updates['batteryLevel'] = batteryLevel;

    } catch (e) {

      JHLogger.$.e('Background battery sync failed: $e');

    }



    if (lastPosition != null) {

      try {

        await LocationHistoryService.writeLocationPoint(

          parentUid: parentUid,

          childId: childId,

          position: lastPosition,

          batteryLevel: batteryLevel,

        );

      } catch (e) {

        JHLogger.$.e('Background location history write failed: $e');

      }

    }



    if (updates.isEmpty) return;



    final ref = FirebaseFirestore.instance.doc(

      'users/$parentUid/child/$childId',

    );

    final batch = FirebaseFirestore.instance.batch();

    batch.update(ref, updates);

    await batch.commit();

    JHLogger.$.d('Background child sync committed (${updates.keys.join(', ')})');

  } catch (e, stack) {

    JHLogger.$.e('Background sync error: $e\n$stack');

  }

}


