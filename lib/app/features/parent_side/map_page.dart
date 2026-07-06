import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:times_up_flutter/app/helpers/marker_generator_helper.dart';
import 'package:times_up_flutter/models/child_model/child_model.dart';
import 'package:times_up_flutter/services/auth.dart';
import 'package:times_up_flutter/services/database.dart';
import 'package:times_up_flutter/services/geo_locator_service.dart';
import 'package:times_up_flutter/theme/theme.dart';
import 'package:times_up_flutter/utils/constants.dart';
import 'package:times_up_flutter/utils/geo_point_utils.dart';
import 'package:times_up_flutter/widgets/jh_animated_green_dot.dart';
import 'package:times_up_flutter/widgets/jh_display_text.dart';
import 'package:times_up_flutter/widgets/jh_header_widget.dart';
import 'package:times_up_flutter/widgets/jh_pin_marker.dart';

class MapView extends StatefulWidget {
  const MapView(
    this.initialPosition,
    this.database,
    this.auth,
    this.geo, {
    Key? key,
  }) : super(key: key);
  final Position initialPosition;
  final Database database;
  final AuthBase auth;
  final GeoLocatorService geo;

  static Widget create(
    BuildContext context, {
    required Position position,
    required Database database,
    required AuthBase auth,
  }) {
    final geoService = Provider.of<GeoLocatorService>(
      context,
      listen: false,
    );

    return MapView(
      position,
      database,
      auth,
      geoService,
    );
  }

  @override
  State<StatefulWidget> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  late final AnimationController _animationController;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late bool isBottomSheetEnabled = false;
  List<Marker> allMarkers = [];
  String childAddress = 'No Address !';
  String lightMapTheme = '';
  String darkMapTheme = '';
  Timer? _cameraDebounce;
  GeoPoint? _lastCameraTarget;
  List<Map<String, dynamic>> _lastLocations = [];
  StreamSubscription<List<ChildModel>>? _childrenSub;
  Object? _streamError;
  bool _streamWaiting = true;
  List<ChildModel> _children = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _init();
    _childrenSub = widget.database.childrenStream().listen(
      (children) {
        if (!mounted) return;
        setState(() {
          _streamWaiting = false;
          _streamError = null;
          _children = children;
        });
        _onChildrenUpdated(children);
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _streamError = error;
          _streamWaiting = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _childrenSub?.cancel();
    _cameraDebounce?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _init() {
    _setMapTheme();
    widget.geo.getCurrentLocation.listen(_centerScreen);
  }

  bool get _waitingForChildLocation =>
      !_streamWaiting &&
      _streamError == null &&
      _children.isNotEmpty &&
      allMarkers.isEmpty;

  void _onChildrenUpdated(List<ChildModel> children) {
    final locations = childLocationsForMap(children);
    if (locations.length == _lastLocations.length &&
        locations.every(
          (loc) => _lastLocations.any(
            (prev) =>
                prev['id'] == loc['id'] &&
                prev['position'] == loc['position'],
          ),
        )) {
      return;
    }
    _lastLocations = locations;
    if (locations.isEmpty) {
      if (mounted) setState(() => allMarkers = []);
      return;
    }
    _refreshMarkers(locations);
    _debouncedMoveCamera(locations.first['position'] as GeoPoint);
  }

  void _debouncedMoveCamera(GeoPoint target) {
    if (!isValidGeoPoint(target)) return;
    if (_lastCameraTarget?.latitude == target.latitude &&
        _lastCameraTarget?.longitude == target.longitude) {
      return;
    }
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(seconds: 2), () {
      _lastCameraTarget = target;
      unawaited(
        _animateToChild(
          LatLng(target.latitude, target.longitude),
        ),
      );
    });
  }

  Future<void> _animateToChild(LatLng target) async {
    if (!_controller.isCompleted) return;
    final controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 16),
      ),
    );
  }

  void _refreshMarkers(List<Map<String, dynamic>> locations) {
    MarkerGenerator(
      locations.map((l) => MapMarker(l['image'].toString())).toList(),
      (bitmaps) {
        if (!mounted) return;
        setState(() {
          allMarkers = [];
          mapBitmapsToMarkers(bitmaps, locations);
        });
      },
    ).generate(context);
  }

  void _setMapTheme() {
    DefaultAssetBundle.of(context)
        .loadString('assets/map_theme/light_theme.json')
        .then((value) => lightMapTheme = value);

    DefaultAssetBundle.of(context)
        .loadString('assets/map_theme/dark_theme.json')
        .then((value) => darkMapTheme = value);
  }

  Future<void> _getAddressName(Map<String, dynamic> child) async {
    final position = child['position'] as GeoPoint?;
    if (!isValidGeoPoint(position)) return;
    final placeMarks = await placemarkFromCoordinates(
      position!.latitude,
      position.longitude,
    );

    if (placeMarks.isNotEmpty) {
      childAddress =
          '${placeMarks.first.street} ${placeMarks.first.postalCode} '
          '${placeMarks.first.country}';
    }
  }

  void _showBottomSheet(BuildContext context, Map<String, dynamic> child) {
    if (!isBottomSheetEnabled) {
      _scaffoldKey.currentState?.showBottomSheet(
        (context) => FutureBuilder<void>(
          future: _getAddressName(child),
          builder: (context, snapshot) {
            return BottomSheet(
              animationController: _animationController,
              dragHandleSize: const Size(60, 15),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              showDragHandle: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              onClosing: () {
                _dismissBottomSheet(context);
              },
              builder: (BuildContext context) => Container(
                height: 200,
                width: double.maxFinite,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        JHDisplayText(
                          text: child['id'].toString(),
                          fontSize: 23,
                          style: const TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.w500,
                          ),
                        ).hP16,
                        const AnimatedGreenDot()
                      ],
                    ).hP8,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          height: 50,
                          width: 300,
                          child: HeaderWidget(
                            title: 'Address',
                            subtitle: childAddress,
                          ),
                        ),
                        Icon(
                          Icons.verified,
                          color: Colors.greenAccent.shade700,
                        ),
                        const SizedBox(width: 4)
                      ],
                    ),
                    HeaderWidget(
                      title: 'Child ',
                      subtitle: child['name'].toString(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      );
      isBottomSheetEnabled = !isBottomSheetEnabled;
    } else {
      _dismissBottomSheet(context);
    }
  }

  void _dismissBottomSheet(BuildContext context) {
    if (mounted) {
      setState(() {
        Navigator.of(context).pop();
        isBottomSheetEnabled = !isBottomSheetEnabled;
      });
    }
  }

  void mapBitmapsToMarkers(
    List<Uint8List> bitmaps,
    List<Map<String, dynamic>> data,
  ) {
    bitmaps.asMap().forEach((i, bmp) {
      final position = data[i]['position'] as GeoPoint?;
      if (!isValidGeoPoint(position)) return;
      allMarkers.add(
        Marker(
          onTap: () => _showBottomSheet(context, data[i]),
          markerId: MarkerId(data[i]['id'] as String),
          position: LatLng(position!.latitude, position.longitude),
          icon: BitmapDescriptor.fromBytes(bmp),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_streamError != null) {
      return SafeArea(
        child: Scaffold(
          body: Center(child: Text('Error: $_streamError')),
        ),
      );
    }
    if (_streamWaiting) {
      return const SafeArea(
        child: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return SafeArea(
      child: Scaffold(
        key: _scaffoldKey,
        body: SizedBox(
          height: double.infinity,
          child: Stack(
            children: [
              Center(
                child: GoogleMap(
                  key: Keys.googleMapKeys,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      widget.initialPosition.latitude,
                      widget.initialPosition.longitude,
                    ),
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  markers: Set<Marker>.of(allMarkers),
                  onMapCreated: (controller) async {
                    if (Theme.of(context).brightness == Brightness.light) {
                      await controller.setMapStyle(lightMapTheme);
                    } else {
                      await controller.setMapStyle(darkMapTheme);
                    }
                    _controller.complete(controller);
                  },
                ),
              ),
              if (_waitingForChildLocation)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Esperando ubicación del hijo…',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _centerScreen(Position position) async {
    final controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 16,
        ),
      ),
    );
  }
}
