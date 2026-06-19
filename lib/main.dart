import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const MaterialApp(home: GpsDashboardScreen(), debugShowCheckedModeBanner: false));

class GpsDashboardScreen extends StatefulWidget {
  const GpsDashboardScreen({super.key});
  @override
  State<GpsDashboardScreen> createState() => _GpsDashboardScreenState();
}

class _GpsDashboardScreenState extends State<GpsDashboardScreen> {
  StreamSubscription<Position>? _gpsSubscription;
  Timer? _uiTimer;
  
  double _targetSpeed = 0.0;
  double _currentSpeed = 0.0;
  bool _isGpsLocked = false;
  bool _blinkState = false;

  @override
  void initState() {
    super.initState();
    _initGPS();
    // Boucle de rafraîchissement fluide pour l'animation des LED et du texte
    _uiTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      setState(() {
        // Interpolation linéaire pour fluidifier les changements brusques de vitesse du GPS
        _currentSpeed += (_targetSpeed - _currentSpeed) * 0.15;
        if ((_targetSpeed - _currentSpeed).abs() < 0.1) {
          _currentSpeed = _targetSpeed;
        }
        _blinkState = !_blinkState;
      });
    });
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _initGPS() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
    
    // Premier repérage rapide
    try {
      Position initialPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);
      if (mounted) {
        setState(() {
          _targetSpeed = initialPos.speed > 0 ? initialPos.speed * 3.6 : 0.0;
          _isGpsLocked = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isGpsLocked = true);
    }

    // Écoute du flux en temps réel
    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((Position pos) {
      if (!mounted) return;
      setState(() {
        _targetSpeed = pos.speed > 0 ? pos.speed * 3.6 : 0.0;
      });
    });
  }

  // Simulateur de régime moteur (RPM) basé sur la vitesse et des rapports de boîte virtuels
  double _getSimulatedRPM(double speed) {
    if (speed <= 0) return 1000;
    if (speed < 30) return 1000 + (speed / 30) * 5500;       // Rapport 1
    if (speed < 60) return 3000 + ((speed - 30) / 30) * 3800;  // Rapport 2
    if (speed < 90) return 3500 + ((speed - 60) / 30) * 3500;  // Rapport 3
    return 4000 + ((speed - 90) / 70) * 3200;                 // Rapport 4
  }

  @override
  Widget build(BuildContext context) {
    if (!_isGpsLocked) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.red)),
        ),
      );
    }

    double rpm = _getSimulatedRPM(_currentSpeed);
    int totalLeds = 10;
    // Calcul du nombre de LED à allumer (Plage de 1000 à 6800 RPM)
    int ledsToLight = (((rpm - 1000) / 5800) * totalLeds).clamp(0, totalLeds).toInt();
    bool isRedline = rpm >= 6300;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // BARRE DE SHIFT LIGHTS (STYLE FORMULE 1 / RALLYE)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(totalLeds, (index) {
                      Color ledColor;
                      // Distribution des couleurs des DEL : 4 Vertes, 3 Jaunes, 3 Rouges
                      if (index < 4) {
                        ledColor = Colors.greenAccent;
                      } else if (index < 7) {
                        ledColor = Colors.amber;
                      } else {
                        ledColor = Colors.redAccent;
                      }

                      bool isOn = index < ledsToLight;
                      // Effet de clignotement global au rupteur
                      if (isRedline) {
                        isOn = _blinkState;
                        ledColor = Colors.red;
                      }

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 20),
                        width: (MediaQuery.of(context).size.width - 80) / totalLeds,
                        height: 25,
                        decoration: BoxDecoration(
                          color: isOn ? ledColor : Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: isOn ? [
                            BoxShadow(color: ledColor.withOpacity(0.6), blurRadius: 10, spreadRadius: 1)
                          ] : [],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isRedline ? "SHIFT !" : "${(rpm).toStringAsFixed(0)} RPM",
                    style: TextStyle(
                      color: isRedline ? Colors.redAccent : Colors.white54,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

            // COMPTEUR DE VITESSE CENTRAL NUMÉRIQUE
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentSpeed.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Courier',
                    height: 1.0,
                  ),
                ),
                const Text(
                  "KM/H",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),

            // STATUT DU SIGNAL GPS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "GPS ACQUIRED (OFFLINE SYSTEM)",
                  style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
