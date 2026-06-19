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
      title: 'CustomNav',
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
  double _currentSpeed = 0.0; // En km/h
  
  List<Marker> _alertMarkers = [];
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

  // Initialisation du suivi GPS en temps réel via les satellites
  Future<void> _initGPS() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.none) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return;
    }

    // Écoute des mouvements de l'utilisateur
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5)
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
        // Conversion m/s en km/h
        _currentSpeed = position.speed * 3.6; 
        
        // Mise à jour de l'itinéraire en temps réel si une destination existe
        if (_routePoints.isNotEmpty) {
          _updateNavigationMetrics();
        }
      });
      _mapController.move(_userPosition, _mapController.camera.zoom);
    });
  }

  // Calcul des km restants et de l'Heure d'arrivée (ETA)
  void _updateNavigationMetrics() {
    final Distance distance = const Distance();
    // Distance en mètres convertie en km
    double meters = distance.as(LengthUnit.Meter, _userPosition, _routePoints.last);
    
    setState(() {
      _kmRemaining = meters / 1000;
      if (_currentSpeed > 10) {
        // Calcul du temps estimé basé sur la vitesse actuelle
        int minutesRemaining = (meters / (position) { return _currentSpeed / 3.6; } as double).round() ~/ 60;
        _eta = DateFormat('HH:mm').format(DateTime.now().add(Duration(minutes: minutesRemaining)));
      } else {
        // Simulation standard si l'utilisateur est à l'arrêt
        _eta = DateFormat('HH:mm').format(DateTime.now().add(const Duration(minutes: 25)));
      }
    });
  }

  // Tracer l'itinéraire (Ici simulé en ligne droite pour le mode hors-ligne pur)
  void _startNavigation(LatLng destination) {
    setState(() {
      _routePoints = [_userPosition, destination];
      _updateNavigationMetrics();
    });
    _mapController.move(_userPosition, 15.0);
  }

  // Ajouter une alerte à l'endroit exact du clic
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
    
    // NOTE TECHNIQUE : C'est ici que vous ajouteriez la dépendance Firebase Cloud Firestore 
    // pour envoyer la position de l'alerte à tout le monde sans avoir de serveur à gérer :
    // FirebaseFirestore.instance.collection('alerts').add({'lat': position.latitude, 'lng': position.longitude, 'type': type, 'comment': customComment});
  }

  @override
  Widget build(BuildContext context) {
    // Style de carte OpenStreetMap (Online / Sauvegardable en local pour le Hors-ligne)
    String tileUrl = widget.isDarkMode 
      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
      : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      body: Stack(
        children: [
          // 1. LA CARTE (Bien visible)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition,
              initialZoom: 14.0,
              onTap: (tapPosition, latLng) {
                // Menu contextuel au clic précis pour poser une alerte
                _showAlertDialog(latLng);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'com.example.customnav',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(points: _routePoints, strokeWidth: 6.0, color: Colors.blue.shade700),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Icône de l'utilisateur qui bouge
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

          // 2. BARRE DE RECHERCHE DESTINATION (Haut de l'écran)
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black2Break)]),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _destinationController,
                      style: const TextStyle(fontSize: 20), // Gros texte
                      decoration: const InputDecoration(hintText: "Où allez-vous ?", border: InputBorder.none),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, size: 30),
                    onPressed: () {
                      // Simulation d'une destination à 5km au Nord pour l'exemple
                      LatLng dest = LatLng(_userPosition.latitude + 0.04, _userPosition.longitude + 0.04);
                      _startNavigation(dest);
                    },
                  )
                ],
              ),
            ),
          ),

          // 3. COMPTEUR DE VITESSE (Style Waze, en bas à gauche)
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

          // 4. PANNEAU DE NAVIGATION (En bas de l'écran)
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

          // 5. BOUTONS D'ACTIONS (Flottants à droite, uniquement des icônes)
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
                  onPressed: () => _showAlertDialog(_userPosition), // Alerte rapide sur la position actuelle
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Pop-up d'alerte intuitive
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
                      // LIGNE PERSONNALISABLE : Ajoutez ici vos propres types de signalements personnalisés (ex: Météo, Radar, Police, etc.)
                      _addAlert('personnalise', position, 'Zone de danger temporaire');
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
