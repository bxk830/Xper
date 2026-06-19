import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong2.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const MaterialApp(home: MapScreen(), debugShowCheckedModeBanner: false));

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _controller = MapController();
  LatLng _pos = const LatLng(48.8566, 2.3522);
  double _speed = 0.0;
  List<LatLng> _route = [];

  @override
  void initState() {
    super.initState();
    _initGPS();
  }

  Future<void> _initGPS() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.none) perm = await Geolocator.requestPermission();
    
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5)
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _pos = LatLng(pos.latitude, pos.longitude);
        _speed = pos.speed * 3.6;
      });
      _controller.move(_pos, _controller.camera.zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(initialCenter: _pos, initialZoom: 14.0),
            children: [
              TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'),
              PolylineLayer(polylines: [Polyline(points: _route, strokeWidth: 4.0, color: Colors.blue)]),
              MarkerLayer(markers: [Marker(point: _pos, child: const Icon(Icons.navigation, color: Colors.blue, size: 40))]),
            ],
          ),
          Positioned(
            top: 50, left: 15, right: 15,
            child: Card(
              color: Colors.black87,
              child: TextField(
                decoration: const InputDecoration(hintText: "Ou allez-vous ?", contentPadding: EdgeInsets.all(15), border: InputBorder.none, suffixIcon: Icon(Icons.search, color: Colors.white)),
                style: const TextStyle(color: Colors.white),
                onSubmitted: (_) => setState(() => _route = [_pos, LatLng(_pos.latitude + 0.02, _pos.longitude + 0.02)]),
              ),
            ),
          ),
          Positioned(
            bottom: 30, left: 20,
            child: CircleAvatar(
              radius: 35,
              backgroundColor: Colors.black87,
              child: Text('${_speed.toStringAsFixed(0)}\nkm/h', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
