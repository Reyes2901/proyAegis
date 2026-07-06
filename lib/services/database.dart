import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:times_up_flutter/models/blocked_app_model.dart';
import 'package:times_up_flutter/models/child_model/child_model.dart';
import 'package:times_up_flutter/models/email_model.dart';
import 'package:times_up_flutter/models/notification_model/notification_model.dart';
import 'package:times_up_flutter/models/screen_rule_model.dart';
import 'package:times_up_flutter/models/time_rule_model.dart';
import 'package:times_up_flutter/services/api_path.dart';
import 'package:times_up_flutter/services/app_usage_service.dart';
import 'package:times_up_flutter/services/auth.dart';
import 'package:times_up_flutter/services/firestore_service.dart';
import 'package:times_up_flutter/services/geo_locator_service.dart';
import 'package:times_up_flutter/services/location_history_service.dart';
import 'package:times_up_flutter/services/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:times_up_flutter/utils/constants.dart';
import 'package:times_up_flutter/widgets/show_logger.dart';

abstract class Database {
  ChildModel? get currentChild;

  Future<void> setChild(ChildModel model);

  Future<void> linkChildKey(String key);

  Future<void> updateChild(ChildModel model);

  Future<void> deleteChild(ChildModel model);

  Future<void> deleteNotification(String timestamp);

  Future<void> sendEmail({required EmailModel email});

  Stream<List<ChildModel>> childrenStream();

  Stream<List<NotificationModel>> notificationStream({String childId});

  Stream<ChildModel> childStream({required String childId});

  static String childKey(String key) => 'childKeys/$key';

  Future<void> setNotification(
    NotificationModel notification,
    ChildModel model,
  );

  Future<void> liveUpdateChild(
    ChildModel model,
    AppUsageService apps,
  );

  Future<ChildModel> getUserCurrentChild(
    String key,
    AppUsageService apps,
    GeoPoint latLong, {
    String? battery,
  });

  /// Restores FCM token refresh listener after app restart (linked child).
  Future<void> ensureFcmTokenListener();

  Future<List<LocationHistoryEntry>> getLocationHistory({
    required String childId,
    required DateTime since,
    int limit = 100,
  });

  Future<Map<String, dynamic>?> getAppUsageDaily({
    required String childId,
    required String dateId,
  });

  Future<List<Map<String, dynamic>?>> getAppUsageDailyRange({
    required String childId,
    required List<String> dateIds,
  });

  Future<void> setBlockedApp(
    String childId,
    String packageName,
    bool blocked,
  );

  Stream<List<BlockedApp>> getBlockedAppsStream(String childId);

  Future<void> setTimeRule(
    String childId,
    String packageName,
    int dailyLimitMinutes,
    List<int> daysOfWeek,
  );

  Future<void> deleteTimeRule(String childId, String packageName);

  Stream<List<TimeRule>> getTimeRulesStream(String childId);

  Future<void> setScreenRule(String childId, ScreenRule rule);

  Future<void> deleteScreenRule(String childId, String ruleId);

  Stream<List<ScreenRule>> getScreenRulesStream(String childId);

  Future<int> getDailyUsageMinutes(String childId, DateTime date);

  Future<Map<String, int>> getDailyUsageByApp(String childId, DateTime date);
}

class FireStoreDatabase implements Database {
  factory FireStoreDatabase({required String uid, required AuthBase auth}) {
    return _singleton ??= FireStoreDatabase._internal(uid, auth);
  }

  FireStoreDatabase._internal(this.uid, this.auth) {
    if (auth.isFirstLogin) {
      sendEmail(
        email: EmailModel(
          emailIds: [auth.currentUser!.email!],
          subject: EmailConstants.subject,
          text: EmailConstants.text,
          html: EmailConstants.html(
            auth.currentUser!.displayName ?? auth.currentUser!.email!,
          ),
        ),
      ).then((value) => auth.setFirstLogin(isFirstLogin: false));
    }
  }
  static FireStoreDatabase? _singleton;
  GeoLocatorService geo = GeoLocatorService();
  final String uid;
  final AuthBase auth;
  ChildModel? _child;
  String? _linkedParentUid;
  StreamSubscription<String>? _tokenRefreshSub;
  final _service = FireStoreService.instance;

  String get _ownerUid => _linkedParentUid ?? uid;

  String _childDocPath(String childId) => APIPath.child(_ownerUid, childId);

  @override
  ChildModel? get currentChild => _child;

  @override
  Future<void> setChild(ChildModel model) async {
    try {
      final jsonData = model.toJson();
      JHLogger.$.i('Saving child with JSON: $jsonData');
      await FirebaseFirestore.instance.doc(_childDocPath(model.id)).set(jsonData);
      JHLogger.$.i('Child saved successfully');
    } catch (e, stack) {
      JHLogger.$.e('Error in setChild: $e\n$stack');
    }
  }

  @override
  Future<void> linkChildKey(String key) async {
    await FirebaseFirestore.instance.doc(APIPath.childKey(key)).set({
      'parentUid': uid,
      'childId': key,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateChild(ChildModel model) async {
    try {
      final jsonData = model.toJson();
      await FirebaseFirestore.instance.doc(_childDocPath(model.id)).update(jsonData);
    } catch (e, stack) {
      JHLogger.$.e('Error in updateChild: $e\n$stack');
    }
  }

  @override
  Future<void> setNotification(
    NotificationModel notification,
    ChildModel child,
  ) async {
    await _service.setNotificationFunction(
      path: APIPath.notificationsStream(_ownerUid, child.id),
      data: notification.toJson(),
    );
  }

  @override
  Future<void> sendEmail({required EmailModel email}) async {
    await _service.sendEmail(
      path: APIPath.mail(),
      data: email.toJson(),
    );
  }

  Future<void> setTokenOnFireStore(Map<String, dynamic> token) async {
    await FirebaseFirestore.instance
        .collection('DeviceTokens')
        .doc(token['id'] as String)
        .set(token, SetOptions(merge: true));
  }

  @override
  Future<void> deleteChild(ChildModel model) async {
    // Eliminar el documento de Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_linkedParentUid ?? uid)
        .collection('child')
        .doc(model.id)
        .delete();
    // Eliminar childKeys si existe
    try {
      await FirebaseFirestore.instance
          .doc(APIPath.childKey(model.id))
          .delete();
    } catch (e) {
      // Ignorar si no existe
    }
    // Eliminar imagen solo si la URL es válida
    final imageUrl = model.image;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      } catch (e) {
        JHLogger.$.e('Error deleting image: $e');
      }
    }
  }

  @override
  Future<void> deleteNotification(String timestamp) async {
    await _service.deleteData(path: APIPath.notifications(uid, timestamp));
  }

  @override
  Stream<ChildModel> childStream({required String childId}) =>
      _service.documentStream(
        path: _childDocPath(childId),
        builder: (data, documentId) => ChildModel.fromJson(data),
      );

  @override
  Stream<List<NotificationModel>> notificationStream({String? childId}) {
    return _service.notificationStream(
      path: APIPath.notificationsStream(_ownerUid, childId ?? ''),
      builder: (data, documentId) => NotificationModel.fromJson(data),
    );
  }

  @override
  Stream<List<ChildModel>> childrenStream() => _service.collectionStream(
        path: APIPath.children(uid),
        builder: ChildModel.fromJson,
      );

  @override
  Future<void> liveUpdateChild(
    ChildModel model,
    AppUsageService apps,
  ) async {
    await apps.getAppUsageService();

    final point = await geo.getCurrentLocation.last;
    final currentLocation = GeoPoint(point.latitude, point.longitude);

    _child = ChildModel(
      id: model.id,
      name: model.name,
      email: model.email,
      token: model.token,
      position: currentLocation,
      appsUsageModel: apps.info,
      image: model.image,
      batteryLevel: model.batteryLevel,
    );

    await updateChild(_child!);
    JHLogger.$.e('Child Updated : $_child');
  }

  @override
  Future<ChildModel> getUserCurrentChild(
    String key,
    AppUsageService apps,
    GeoPoint latLong, {
    String? battery,
  }) async {
    final deviceUid = auth.currentUser?.uid;
    if (deviceUid == null) {
      throw Exception('User not authenticated');
    }
    final token = await auth.setToken();
    await apps.getAppUsageService();

    final keyDoc =
        await FirebaseFirestore.instance.doc(APIPath.childKey(key)).get();
    if (!keyDoc.exists) {
      JHLogger.$.e('No child found for key: $key');
      throw Exception('Child not found for key: $key');
    }

    final keyData = keyDoc.data()!;
    final parentUid = keyData['parentUid'] as String;
    final childId = keyData['childId'] as String? ?? key;
    _linkedParentUid = parentUid;

    await setTokenOnFireStore({
      'id': deviceUid,
      'parentUid': parentUid,
      'childId': childId,
      'device_token': token,
    });

    _listenTokenRefresh(
      deviceUid: deviceUid,
      parentUid: parentUid,
      childId: childId,
    );

    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(parentUid)
        .collection('child')
        .doc(childId)
        .get();

    if (!docSnapshot.exists) {
      JHLogger.$.e('No child profile for key: $key under parent $parentUid');
      throw Exception('Child not found for key: $key');
    }

    final data = docSnapshot.data()!;
    final email = (data['email'] as String?) ?? '';
    final name = (data['name'] as String?) ?? '';
    final image = (data['image'] as String?) ?? '';

    final appUsageList = apps.info;

    JHLogger.$.i(
      'Creating ChildModel with data: id=$childId, name=$name, email=$email, '
      'image=$image, position=$latLong, token=$token, battery=$battery',
    );

    final childModel = ChildModel(
      id: childId,
      name: name,
      email: email,
      image: image,
      position: latLong,
      appsUsageModel: appUsageList,
      token: token,
      batteryLevel: battery ?? '',
    );

    JHLogger.$.i('ChildModel created successfully');
    await FirebaseFirestore.instance.doc(_childDocPath(childId)).set(
      {
        ...childModel.toJson(),
        'linkedChildUid': deviceUid,
      },
      SetOptions(merge: true),
    );
    JHLogger.$.i('Child saved to Firestore');

    _child = childModel;
    await CacheService.setChildSyncContext(
      parentUid: parentUid,
      childId: childId,
    );
    return childModel;
  }

  @override
  Future<void> ensureFcmTokenListener() async {
    if (_tokenRefreshSub != null) return;
    final ctx = await CacheService.getChildSyncContext();
    final deviceUid = auth.currentUser?.uid;
    if (ctx.parentUid == null || ctx.childId == null || deviceUid == null) {
      return;
    }
    _linkedParentUid ??= ctx.parentUid;
    _listenTokenRefresh(
      deviceUid: deviceUid,
      parentUid: ctx.parentUid!,
      childId: ctx.childId!,
    );
  }

  void _listenTokenRefresh({
    required String deviceUid,
    required String parentUid,
    required String childId,
  }) {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await setTokenOnFireStore({
        'id': deviceUid,
        'parentUid': parentUid,
        'childId': childId,
        'device_token': newToken,
      });
      final current = _child;
      if (current != null) {
        await updateChild(current.copyWith(token: newToken));
        _child = current.copyWith(token: newToken);
      }
    });
  }

  Stream<ChildModel> streamChild({required String childId}) {
    final parentUid = _linkedParentUid ?? uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(parentUid)
        .collection('child')
        .doc(childId)
        .snapshots()
        .map((doc) => ChildModel.fromJson(doc.data()!));
  }

  @override
  Future<List<LocationHistoryEntry>> getLocationHistory({
    required String childId,
    required DateTime since,
    int limit = 100,
  }) =>
      LocationHistoryService.fetchLocationHistory(
        parentUid: uid,
        childId: childId,
        since: since,
        limit: limit,
      );

  @override
  Future<Map<String, dynamic>?> getAppUsageDaily({
    required String childId,
    required String dateId,
  }) async {
    final snap = await FirebaseFirestore.instance
        .doc(APIPath.appUsageDaily(uid, childId, dateId))
        .get();
    return snap.exists ? snap.data() : null;
  }

  @override
  Future<List<Map<String, dynamic>?>> getAppUsageDailyRange({
    required String childId,
    required List<String> dateIds,
  }) async {
    final snaps = await Future.wait(
      dateIds.map(
        (dateId) => FirebaseFirestore.instance
            .doc(APIPath.appUsageDaily(uid, childId, dateId))
            .get(),
      ),
    );
    return snaps.map((s) => s.exists ? s.data() : null).toList();
  }

  @override
  Future<void> setBlockedApp(
    String childId,
    String packageName,
    bool blocked,
  ) =>
      _service.setData(
        path: APIPath.blockedApps(_ownerUid, childId, packageName),
        data: {
          'packageName': packageName,
          'blocked': blocked,
          'blockedAt': FieldValue.serverTimestamp(),
          'source': 'parent',
        },
      );

  @override
  Stream<List<BlockedApp>> getBlockedAppsStream(String childId) =>
      _service.collectionStream(
        path: APIPath.blockedApps(_ownerUid, childId),
        builder: BlockedApp.fromJson,
      );

  @override
  Future<void> setTimeRule(
    String childId,
    String packageName,
    int dailyLimitMinutes,
    List<int> daysOfWeek,
  ) =>
      _service.setData(
        path: APIPath.timeRule(_ownerUid, childId, packageName),
        data: {
          'packageName': packageName,
          'dailyLimitMinutes': dailyLimitMinutes,
          'daysOfWeek': daysOfWeek,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

  @override
  Future<void> deleteTimeRule(String childId, String packageName) async {
    await FirebaseFirestore.instance
        .doc(APIPath.timeRule(_ownerUid, childId, packageName))
        .delete();
  }

  @override
  Stream<List<TimeRule>> getTimeRulesStream(String childId) {
    return FirebaseFirestore.instance
        .collection(APIPath.timeRules(_ownerUid, childId))
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TimeRule.fromJson(d.data(), docId: d.id))
              .where((r) => r.packageName.isNotEmpty)
              .toList(),
        );
  }

  @override
  Future<void> setScreenRule(String childId, ScreenRule rule) async {
    final ruleId = rule.id.isEmpty
        ? FirebaseFirestore.instance.collection('_').doc().id
        : rule.id;
    await _service.setData(
      path: APIPath.screenRule(_ownerUid, childId, ruleId),
      data: {
        ...rule.copyWith(id: ruleId).toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  @override
  Future<void> deleteScreenRule(String childId, String ruleId) async {
    await FirebaseFirestore.instance
        .doc(APIPath.screenRule(_ownerUid, childId, ruleId))
        .delete();
  }

  @override
  Stream<List<ScreenRule>> getScreenRulesStream(String childId) {
    return FirebaseFirestore.instance
        .collection(APIPath.screenRules(_ownerUid, childId))
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ScreenRule.fromJson(d.data(), docId: d.id))
              .where((r) => r.id.isNotEmpty)
              .toList(),
        );
  }

  @override
  Future<int> getDailyUsageMinutes(String childId, DateTime date) async {
    final doc = await getAppUsageDaily(
      childId: childId,
      dateId: DateFormat('yyyy-MM-dd').format(date),
    );
    return (doc?['totalMinutes'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<Map<String, int>> getDailyUsageByApp(
    String childId,
    DateTime date,
  ) async {
    final doc = await getAppUsageDaily(
      childId: childId,
      dateId: DateFormat('yyyy-MM-dd').format(date),
    );
    final raw = doc?['byApp'];
    if (raw is! Map) return {};
    return raw.map(
      (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
    );
  }
}
