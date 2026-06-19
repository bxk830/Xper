import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

void main() => runApp(const WazeCloneApp());

class WazeCloneApp extends StatefulWidget {
  const WazeCloneApp({super.key});

  @override
  State<WazeCloneApp> createState() => _WazeCloneAppState();
}

class _WazeCloneAppState extends State<WazeCloneApp> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        primarySwatch: Colors.blue,
      ),
      home: MapScreen(
        isDarkMode: _isDarkMode,
        onThemeChanged: (val) => setState(() => _isDarkMode = val),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const MapScreen({super.key, required this.isDarkMode, required this.onThemeChanged});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng _userPosition = const LatLng(48.8566, 2.3522); // Paris par défaut
  double _currentSpeed = 0.0; 
  
  final List<Marker> _alertMarkers = [];
  List<LatLng> _routePoints = [];
  
  double _kmRemaining = 0.0;
  String _eta = "--:--";
  
  final TextEditingController _destinationController = TextEditingController();
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _initGPS();
  }

  Future<void> _initGPS() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.none) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5)
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
        _currentSpeed = position.speed * 3.6; // Conversion m/s en km/h
        
        if (_routePoints.isNotEmpty) {
          _updateNavigationMetrics();
        }
      });
      _mapController.move(_userPosition, _mapController.camera.zoom);
    });
  }

  void _updateNavigationMetrics() {
    const Distance distance = Distance();
    double meters = distance.as(LengthUnit.Meter, _userPosition, _routePoints.last);
    
    setState(() {
      _kmRemaining = meters / 1000;
      if (_currentSpeed > 10) {
        double speedMps = _currentSpeed / 3.6;
        int minutesRemaining = (meters / speedMps) ~/ 60;
        _eta = DateFormat('HH:mm').format(DateTime.now().add(Duration(minutes: minutesRemaining)));
      } else {
        _eta = DateFormat('HH:mm').format(DateTime.now().add(const Duration(minutes: 25)));
      }
    });
  }

  void _startNavigation(LatLng destination) {
    setState(() {
      _routePoints = [_userPosition, destination];
      _updateNavigationMetrics();
    });
    _mapController.move(_userPosition, 15.0);
  }

  void _addAlert(String type, LatLng position, String customComment) {
    IconData icon;
    Color color;

    switch (type) {
      case 'accident':
        icon = Icons.warning;
        color = Colors.red;
        break;
      case 'travaux':
        icon = Icons.construction;
        color = Colors.orange;
        break;
      default:
        icon = Icons.info;
        color = Colors.blue;
    }

    setState(() {
      _alertMarkers.add(
        Marker(
          point: position,
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$type : $customComment', style: const TextStyle(fontSize: 18))),
              );
            },
            child: Icon(icon, color: color, size: 40),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    String tileUrl = widget.isDarkMode 
      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
      : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition,
              initialZoom: 14.0,
              onTap: (tapPosition, latLng) => _showAlertDialog(latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.bx.xper',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(points: _routePoints, strokeWidth: 6.0, color: Colors.blue.shade700),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userPosition,
                    width: 60,
                    height: 60,
                    child: const Icon(Icons.navigation, color: Colors.blue, size: 45), 
                  ),
                  ..._alertMarkers
                ],
              ),
            ],
          ),

          // Barre de recherche
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)]),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _destinationController,
                      style: const TextStyle(fontSize: 20),
                      decoration: const InputDecoration(hintText: "Où allez-vous ?", border: InputBorder.none),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, size: 30),
                    onPressed: () {
                      LatLng dest = LatLng(_userPosition.latitude + 0.04, _userPosition.longitude + 0.04);
                      _startNavigation(dest);
                    },
                  )
                ],
              ),
            ),
          ),

          // Compteur de vitesse
          Positioned(
            bottom: 120,
            left: 20,
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${_currentSpeed.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const Text('km/h', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),

          // Panneau Infos d'arrivée
          if (_routePoints.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 15,
              right: 15,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text("ARRIVÉE", style: TextStyle(fontSize: 14, color: Colors.grey)),
                        Text(_eta, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text("DISTANCE", style: TextStyle(fontSize: 14, color: Colors.grey)),
                        Text('${_kmRemaining.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 35),
                      onPressed: () => setState(() => _routePoints.clear()),
                    )
                  ],
                ),
              ),
            ),

          // Boutons d'actions
          Positioned(
            bottom: _routePoints.isNotEmpty ? 140 : 30,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "theme",
                  backgroundColor: Colors.blue,
                  child: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
                  onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
                ),
                const SizedBox(height: 15),
                FloatingActionButton(
                  heroTag: "report",
                  backgroundColor: Colors.redAccent,
                  child: const Icon(Icons.add_location_alt, color: Colors.white, size: 30),
                  onPressed: () => _showAlertDialog(_userPosition),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showAlertDialog(LatLng position) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Signaler un danger", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.warning, color: Colors.red, size: 50),
                    onPressed: () {
                      _addAlert('accident', position, 'Collision signalée');
                      Navigator.pop(context);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.construction, color: Colors.orange, size: 50),
                    onPressed: () {
                      _addAlert('travaux', position, 'Voie rétrécie');
                      Navigator.pop(context);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility_off, color: Colors.blue, size: 50),
                    onPressed: () {
                      // LIGNE PERSONNALISABLE : Modifiez le texte ci-dessous pour changer votre troisième type d'alerte.
                      _addAlert('personnalise', position, 'Danger temporaire sur la route');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _destinationController.dispose();
    super.dispose();
  }
}
