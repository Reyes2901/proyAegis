import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:times_up_flutter/services/geo_locator_service.dart';
import 'package:times_up_flutter/widgets/show_alert_dialog.dart';

/// Requests location; prompts for GPS or app settings when unavailable.
Future<Position?> requestLocationWithSettingsPrompt(
  BuildContext context,
  GeoLocatorService geo,
) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    if (context.mounted) {
      await showGpsDisabledDialog(context);
    }
    return null;
  }

  try {
    final position = await geo.getInitialLocation();
    if (position != null) return position;

    if (geo.permission == LocationPermission.deniedForever && context.mounted) {
      await showLocationSettingsDialog(context);
    }
    return null;
  } catch (e) {
    if (e.toString().toLowerCase().contains('location service') &&
        context.mounted) {
      await showGpsDisabledDialog(context);
    }
    return null;
  }
}

Future<void> showGpsDisabledDialog(BuildContext context) async {
  final open = await showAlertDialog(
    context,
    title: 'GPS desactivado',
    content:
        'Para vincular al niño, activa el GPS en los ajustes del dispositivo.',
    defaultActionText: 'Abrir ajustes',
    cancelActionText: 'Cancelar',
  );
  if (open == true) {
    await Geolocator.openLocationSettings();
  }
}

Future<void> showLocationSettingsDialog(BuildContext context) async {
  final open = await showAlertDialog(
    context,
    title: 'Location disabled',
    content:
        'Location access is permanently denied. Open settings to enable it.',
    defaultActionText: 'Open settings',
    cancelActionText: 'Not now',
  );
  if (open == true) {
    await Geolocator.openAppSettings();
  }
}
