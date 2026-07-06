import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:times_up_flutter/models/child_model/child_model.dart';
import 'package:times_up_flutter/services/database.dart';
import 'package:times_up_flutter/services/location_history_service.dart';
import 'package:times_up_flutter/theme/theme.dart';
import 'package:times_up_flutter/utils/geo_point_utils.dart';
import 'package:times_up_flutter/widgets/jh_display_text.dart';
import 'package:times_up_flutter/widgets/jh_empty_content.dart';
import 'package:times_up_flutter/widgets/jh_header_widget.dart';

enum LocationHistoryRange { last24h, last7d }

extension on LocationHistoryRange {
  Duration get duration => switch (this) {
        LocationHistoryRange.last24h => const Duration(hours: 24),
        LocationHistoryRange.last7d => const Duration(days: 7),
      };

  String get label => switch (this) {
        LocationHistoryRange.last24h => '24h',
        LocationHistoryRange.last7d => '7 days',
      };
}

class LocationHistoryPage extends StatefulWidget {
  const LocationHistoryPage({
    required this.database,
    required this.childModel,
    Key? key,
  }) : super(key: key);

  final Database database;
  final ChildModel childModel;

  static Future<void> show(BuildContext context, ChildModel model) async {
    final database = Provider.of<Database>(context, listen: false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LocationHistoryPage(
          database: database,
          childModel: model,
        ),
      ),
    );
  }

  @override
  State<LocationHistoryPage> createState() => _LocationHistoryPageState();
}

class _LocationHistoryPageState extends State<LocationHistoryPage> {
  LocationHistoryRange _range = LocationHistoryRange.last24h;
  late Future<List<LocationHistoryEntry>> _historyFuture;
  String lightMapTheme = '';
  String darkMapTheme = '';

  @override
  void initState() {
    super.initState();
    _reload();
    _loadMapThemes();
  }

  void _reload() {
    final since = DateTime.now().subtract(_range.duration);
    _historyFuture = widget.database.getLocationHistory(
      childId: widget.childModel.id,
      since: since,
    );
  }

  void _loadMapThemes() {
    rootBundle.loadString('assets/map_theme/light_theme.json').then((v) {
      if (mounted) setState(() => lightMapTheme = v);
    });
    rootBundle.loadString('assets/map_theme/dark_theme.json').then((v) {
      if (mounted) setState(() => darkMapTheme = v);
    });
  }

  void _onRangeChanged(LocationHistoryRange range) {
    if (_range == range) return;
    setState(() {
      _range = range;
      _reload();
    });
  }

  Set<Marker> _buildMarkers(List<LocationHistoryEntry> entries) {
    return entries
        .where((e) => isValidGeoPoint(e.position))
        .map(
          (e) => Marker(
            markerId: MarkerId(e.id),
            position: LatLng(e.position.latitude, e.position.longitude),
            infoWindow: InfoWindow(
              title: DateFormat('MMM d, HH:mm').format(e.capturedAt),
            ),
          ),
        )
        .toSet();
  }

  CameraPosition _initialCamera(List<LocationHistoryEntry> entries) {
    if (entries.isNotEmpty && isValidGeoPoint(entries.first.position)) {
      final p = entries.first.position;
      return CameraPosition(
        target: LatLng(p.latitude, p.longitude),
        zoom: 13,
      );
    }
    final live = widget.childModel.position;
    if (live != null && isValidGeoPoint(live)) {
      return CameraPosition(
        target: LatLng(live.latitude, live.longitude),
        zoom: 13,
      );
    }
    return const CameraPosition(target: LatLng(0, 0), zoom: 2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.childModel.name} — history'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<LocationHistoryRange>(
              segments: LocationHistoryRange.values
                  .map((r) => ButtonSegment(value: r, label: Text(r.label)))
                  .toList(),
              selected: {_range},
              onSelectionChanged: (s) => _onRangeChanged(s.first),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LocationHistoryEntry>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return JHEmptyContent(
                    title: 'Error',
                    message: snapshot.error.toString(),
                  );
                }
                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return const JHEmptyContent(
                    title: 'No location history',
                    message: 'Points appear after background GPS sync (~5 min).',
                  );
                }
                return Column(
                  children: [
                    SizedBox(
                      height: 260,
                      child: GoogleMap(
                        initialCameraPosition: _initialCamera(entries),
                        markers: _buildMarkers(entries),
                        myLocationEnabled: false,
                        onMapCreated: (controller) async {
                          final style = theme.brightness == Brightness.light
                              ? lightMapTheme
                              : darkMapTheme;
                          if (style.isNotEmpty) {
                            await controller.setMapStyle(style);
                          }
                        },
                      ),
                    ),
                    const HeaderWidget(
                      title: 'Recent points',
                      subtitle: 'Tap marker for time',
                    ).hP8,
                    Expanded(
                      child: ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, i) =>
                            _HistoryListTile(entry: entries[i]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryListTile extends StatelessWidget {
  const _HistoryListTile({required this.entry});

  final LocationHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _resolveAddress(entry.position),
      builder: (context, snap) {
        final address = snap.data ?? '…';
        return ListTile(
          leading: Icon(Icons.place, color: CustomColors.indigoPrimary),
          title: JHDisplayText(
            text: DateFormat('EEE, MMM d — HH:mm').format(entry.capturedAt),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(address),
          trailing: entry.batteryLevel != null
              ? Text('${entry.batteryLevel}%')
              : null,
        );
      },
    );
  }

  static Future<String> _resolveAddress(GeoPoint point) async {
    try {
      final marks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (marks.isEmpty) return '${point.latitude}, ${point.longitude}';
      final p = marks.first;
      return '${p.street ?? ''} ${p.locality ?? ''}'.trim();
    } catch (_) {
      return '${point.latitude.toStringAsFixed(4)}, '
          '${point.longitude.toStringAsFixed(4)}';
    }
  }
}
