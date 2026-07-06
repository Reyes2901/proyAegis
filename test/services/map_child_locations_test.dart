import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:times_up_flutter/models/child_model/child_model.dart';
import 'package:times_up_flutter/utils/geo_point_utils.dart';

void main() {
  test('isValidGeoPoint rejects null', () {
    expect(isValidGeoPoint(null), isFalse);
  });

  test('isValidGeoPoint accepts in-range coordinates', () {
    expect(isValidGeoPoint(const GeoPoint(0, 0)), isTrue);
    expect(isValidGeoPoint(const GeoPoint(-33.8, 151.2)), isTrue);
    expect(isValidGeoPoint(const GeoPoint(90, 180)), isTrue);
  });

  test('childLocationsForMap skips children without valid position', () {
    final children = [
      const ChildModel(
        id: 'a',
        name: 'A',
        email: 'a@test.com',
        image: null,
        position: GeoPoint(10, 20),
      ),
      const ChildModel(
        id: 'b',
        name: 'B',
        email: 'b@test.com',
        image: null,
      ),
    ];

    final locations = childLocationsForMap(children);
    expect(locations.length, 1);
    expect(locations.first['id'], 'a');
    expect(locations.first['position'], const GeoPoint(10, 20));
  });
}
