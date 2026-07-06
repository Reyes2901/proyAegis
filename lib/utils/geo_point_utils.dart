import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:times_up_flutter/models/child_model/child_model.dart';

/// Returns true when [point] has finite lat/lng within valid WGS-84 bounds.
bool isValidGeoPoint(GeoPoint? point) {
  if (point == null) return false;
  final lat = point.latitude;
  final lng = point.longitude;
  if (!lat.isFinite || !lng.isFinite) return false;
  if (lat < -90 || lat > 90) return false;
  if (lng < -180 || lng > 180) return false;
  return true;
}

/// Maps [children] with a non-null, valid [ChildModel.position] to marker payloads.
List<Map<String, dynamic>> childLocationsForMap(List<ChildModel> children) {
  return children
      .where((c) => isValidGeoPoint(c.position))
      .map(
        (c) => {
          'id': c.id,
          'name': c.name,
          'image': c.image ?? '',
          'position': c.position,
        },
      )
      .toList();
}
