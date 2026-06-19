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
  StreamSubscription<Position>? _gpsSubscription;
  
  // Variables d'état
  LatLng _pos = const LatLng(0, 0); 
  double _speed = 0.0;
  List<LatLng> _route = [];
  bool _isGpsLocked = false;

  @override
  void initState() {
    super.initState();
    _initGPS();
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initGPS() async {
    // 1. Vérification du service de localisation
    if (!await Geolocator.isLocationServiceEnabled()) {
      return;
    }
    
    // 2. Gestion stricte des permissions
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.none) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return;
    }
    
    // 3. Fix GPS immédiat au démarrage (Comme Waze)
    try {
      Position initialPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation
      );
      if (mounted) {
        setState(() {
          _pos = LatLng(initialPos.latitude, initialPos.longitude);
          _isGpsLocked = true;
        });
      }
    } catch (e) {
      // En cas d'échec du fix immédiat, on force le déblocage de l'interface
      setState(() {
        _isGpsLocked = true;
      });
    }

    // 4. Flux de mise à jour en mouvement
    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, 
        distanceFilter: 2, // Sensibilité accrue à 2 mètres pour coller à la route
      ),
    ).listen((Position pos) {
      if (!mounted) return;
      setState(() {
        _pos = LatLng(pos.latitude, pos.longitude);
        _speed = pos.speed > 0 ? pos.speed * 3.6 : 0.0;
      });
      _controller.move(_pos, _controller.camera.zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Écran d'attente pendant l'acquisition du signal GPS initial
    if (!_isGpsLocked) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Cartographie
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _pos, 
              initialZoom: 16.0, // Zoom plus proche pour la navigation
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _route, 
                    strokeWidth: 4.0, 
                    color: Colors.blue,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _pos, 
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.navigation, 
                      color: Colors.blue, 
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Barre de recherche supérieure
          Positioned(
            top: 50, 
            left: 15, 
            right: 15,
            child: Card(
              color: Colors.black87,
              elevation: 4,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: "Ou allez-vous ?", 
                  hintStyle: TextStyle(color: Colors.white54),
                  contentPadding: EdgeInsets.all(15), 
                  border: InputBorder.none, 
                  suffixIcon: Icon(Icons.search, color: Colors.white),
                ),
                style: const TextStyle(color: Colors.white),
                onSubmitted: (value) {
                  if (value.trim().isEmpty) return;
                  setState(() {
                    _route = [
                      _pos, 
                      LatLng(_pos.latitude + 0.01, _pos.longitude + 0.01),
                    ];
                  });
                },
              ),
            ),
          ),
          
          // Compteur de vitesse
          Positioned(
            bottom: 30, 
            left: 20,
            child: CircleAvatar(
              radius: 35,
              backgroundColor: Colors.black87,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _speed.toStringAsFixed(0), 
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 22,
                    ),
                  ),
                  const Text(
                    'km/h', 
                    style: TextStyle(
                      color: Colors.white70, 
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
