import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:times_up_flutter/services/api_path.dart';
import 'package:times_up_flutter/utils/location_history_utils.dart';

class LocationHistoryEntry {
  const LocationHistoryEntry({
    required this.id,
    required this.capturedAt,
    required this.position,
    this.accuracy,
    this.source,
    this.batteryLevel,
  });

  factory LocationHistoryEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return LocationHistoryEntry(
      id: doc.id,
      capturedAt: (data['capturedAt'] as Timestamp).toDate(),
      position: data['position'] as GeoPoint,
      accuracy: (data['accuracy'] as num?)?.toDouble(),
      source: data['source'] as String?,
      batteryLevel: data['batteryLevel'] as String?,
    );
  }

  final String id;
  final DateTime capturedAt;
  final GeoPoint position;
  final double? accuracy;
  final String? source;
  final String? batteryLevel;
}

abstract class LocationHistoryService {
  static Future<void> writeLocationPoint({
    required String parentUid,
    required String childId,
    required Position position,
    String? batteryLevel,
  }) async {
    final capturedAt = position.timestamp;
    final docId = locationHistoryDocId(capturedAt);
    final ref = FirebaseFirestore.instance.doc(
      '${APIPath.locationHistory(parentUid, childId)}/$docId',
    );
    await ref.set({
      'capturedAt': Timestamp.fromDate(capturedAt),
      'position': GeoPoint(position.latitude, position.longitude),
      'accuracy': position.accuracy,
      'source': 'background',
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
    });
  }

  /// Range query on [capturedAt]; single-field index is sufficient.
  static Future<List<LocationHistoryEntry>> fetchLocationHistory({
    required String parentUid,
    required String childId,
    required DateTime since,
    int limit = 100,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collection(APIPath.locationHistory(parentUid, childId))
        .where('capturedAt', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('capturedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(LocationHistoryEntry.fromFirestore).toList();
  }
}
