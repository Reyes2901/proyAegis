import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:times_up_flutter/services/geo_locator_service.dart';

void main() {
  test('GeoLocatorService exposes permission after getInitialLocation', () {
    final geo = GeoLocatorService();
    expect(geo.permission, isA<LocationPermission>());
  });
}
