import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong2.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const WazeCloneApp());

class WazeCloneApp extends StatelessWidget {
  const WazeCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, primarySwatch: Colors.blue),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng _userPos = const LatLng(48.8566, 2.3522); 
  double _speed = 0.0; 
  final List<Marker> _alerts = [];
  List<LatLng> _route = [];
  String _eta = "--:--";

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
        _userPos = LatLng(pos.latitude, pos.longitude);
        _speed = pos.speed * 3.6;
        if (_route.isNotEmpty) {
          final arrival = DateTime.now().add(const Duration(minutes: 20));
          _eta = "${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}";
        }
      });
      _mapController.move(_userPos, _mapController.camera.zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPos,
              initialZoom: 14.0,
              onTap: (_, latLng) => _addAlert(latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                userAgentPackageName: 'com.bx.xper',
              ),
              PolylineLayer(polylines: [Polyline(points: _route, strokeWidth: 5.0, color: Colors.blue)]),
              MarkerLayer(markers: [
                Marker(point: _userPos, child: const Icon(Icons.navigation, color: Colors.blue, size: 40)),
                ..._alerts
              ]),
            ],
          ),

          // Recherche simplifiée
          Positioned(
            top: 50, left: 15, right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(30)),
              child: TextField(
                decoration: const InputDecoration(hintText: "Où allez-vous ?", border: InputBorder.none, suffixIcon: Icon(Icons.search)),
                onSubmitted: (_) => setState(() => _route = [_userPos, LatLng(_userPos.latitude + 0.02, _userPos.longitude + 0.02)]),
              ),
            ),
          ),

          // Compteur et infos
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                  child: Text('${_speed.toStringAsFixed(0)}\nkm/h', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (_route.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(15)),
                    child: Text("Arrivée : $_eta", style: const TextStyle(fontSize: 18, color: Colors.green)),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _addAlert(LatLng pos) {
    setState(() {
      _alerts.add(Marker(
        point: pos,
        child: GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Danger signalé !'))),
          child: const Icon(Icons.warning, color: Colors.red, size: 35),
        ),
      ));
    });
  }
}
