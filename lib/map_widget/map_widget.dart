import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'map_params.dart';

MapWidget getMapWidget(
        Stream<MapParams> to, Sink<MapParams> from, List<double> origin) =>
    MapWidget(toMap: to, fromMap: from, origin: LatLng(origin[0], origin[1]));

class MapWidget extends StatefulWidget {
  const MapWidget(
      {super.key,
      required this.toMap,
      required this.fromMap,
      required this.origin});

  final Stream<MapParams> toMap;
  final Sink<MapParams> fromMap;
  final LatLng origin;

  @override
  State<MapWidget> createState() => MapWidgetState();
}

class MapWidgetState extends State<MapWidget> {
  Marker? marker, poi;
  int? lastClick;
  final _polygon = <LatLng>[];

  LatLng? _markerCenter;
  LatLng? _markerPOI;

  final mapController = MapController();

  @override
  Widget build(BuildContext context) {
    var markers = [
      Marker(
          point: _markerCenter!,
          builder: (context) =>
              const Image(image: AssetImage('assets/pin.png'))),
    ];
    if (_markerPOI != null) {
      markers.add(Marker(
        point: _markerPOI!,
        builder: (context) =>
            const Image(image: AssetImage('assets/binoculars.png')),
      ));
    }
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
          center: _markerCenter!,
          zoom: 10,
          onTap: _onMapTap,
          onMapReady: () {
            _onMapTap(null, widget.origin);
          }),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'ch.ineiti.mountain_panorama',
        ),
        PolygonLayer(
          polygons: [
            Polygon(
              points: _polygon,
              color: Colors.green.withOpacity(0.3),
              isFilled: true,
              borderColor: Colors.green,
              borderStrokeWidth: 4,
            ),
          ],
        ),
        MarkerLayer(
          markers: markers,
        ),
      ],
    );
  }

  Future<void> _onMapTap(TapPosition? _pos, LatLng newPosition) async {
    mapController.move(newPosition, mapController.zoom);
    setState(() {
      _markerCenter = newPosition;
      _markerPOI = null;
      _polygon.clear();
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      widget.fromMap.add(MapParams.sendLocationViewpoint(newPosition));
    });
  }

  void _setPOI(LatLng pos) {
    setState(() {
      _markerPOI = pos;
      mapController.move(pos, 15);
    });
  }

  void _setPolygon(List<LatLng> poly) {
    setState(() {
      //initialize polygon
      _polygon.clear();
      _polygon.addAll(poly);
    });
  }

  void _fitHorizon(){
    setState((){
      var bounds = LatLngBounds.fromPoints(_polygon);
      // print("Bounds are: ${bounds.northWest} / ${bounds.southEast}");
      var cz = mapController.centerZoomFitBounds(bounds);
      mapController.move(cz.center, cz.zoom);
      _markerPOI = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _markerCenter = widget.origin;

    widget.toMap.listen((event) {
      event.isLocationPOI((loc) {
        _setPOI(loc);
      });
      event.isHorizon((horizon) {
        if (_markerCenter != null) {
          final m = _markerCenter!;
          horizon.insert(0, m);
          horizon.add(m);
          _setPolygon(horizon);
        }
      });
      event.isFitHorizon(() {
        _fitHorizon();
      });
    });

    Future.microtask(() async {
      var position = await _determinePosition();
      await _onMapTap(null, LatLng(position.latitude, position.longitude));
    });
  }
}

/// Determine the current position of the device.
///
/// When the location services are not enabled or permissions
/// are denied the `Future` will return an error.
Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition();
}
