import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:safora_app/maps/compas_maps.dart' show FlutterMapCompass;
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:safora_app/maps/nominatim_services.dart' show NominatimService;

class mapsPage extends StatefulWidget {
  const mapsPage({super.key});

  @override
  State<mapsPage> createState() => _mapsPageState();
}

class _mapsPageState extends State<mapsPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FlutterTts _tts = FlutterTts();

  LatLng? _currentLatLng;
  LatLng? _selectedLatLng;
  List<LatLng> _routePoints = [];
  List<List<LatLng>> _allRoutes = []; // Semua rute
  int _selectedRouteIndex = 0; // Rute yang dipilih user
  int _currentStepIndex = 0;
  List<Map<String, dynamic>> _steps = [];
  bool _isLoading = true;
  String _currentInstruction = ''; // Ini nanti menggantikan teks 0 km

  StreamSubscription<Position>? _positionStream;

  LatLng _center = const LatLng(-6.1754, 106.8272); // Default Monas

  String formatDistance(double meters, {bool inM = false}) {
    final formatter = NumberFormat('#,##0');
    return '${formatter.format(meters)} meter';
  }


  @override
  void initState() {
    super.initState();
    NominatimService.configure(); // setup Nominatim
    _getUserLocation();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    setState(() => _isLoading = true);

    await _getUserLocation(); // tunggu lokasi user
    // Bisa tambah async lain misal _loadSavedRoutes() atau data awal

    setState(() => _isLoading = false);
  }

  Future<void> _getUserLocation() async {
    setState(() => _isLoading = true);

    try {
      // Cek apakah layanan lokasi aktif
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("❌ Layanan lokasi tidak aktif");
        setState(() => _isLoading = false);
        return;
      }

      // Cek izin lokasi
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("❌ Izin lokasi ditolak");
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("❌ Izin lokasi ditolak permanen");
        setState(() => _isLoading = false);
        return;
      }

      // Ambil posisi user
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (mounted) { // pastikan widget masih aktif
        setState(() {
          _currentLatLng = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });

        // Pindahkan kamera peta ke posisi user
        _mapController.move(_currentLatLng!, 15);
      }
    } catch (e) {
      debugPrint("❌ Error getting location: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 🔍 Pencarian lokasi pakai NominatimService
  Future<List<Map<String, dynamic>>> _searchLocation(String query) async {
    final results = await NominatimService.searchLocation(query);
    return results.map((res) {
      return {
        'name': res.displayName ?? 'Tanpa nama',
        'lat': double.tryParse(res.lat ?? '0') ?? 0,
        'lon': double.tryParse(res.lon ?? '0') ?? 0,
      };
    }).toList();
  }

  /// 🛣️ Ambil rute dari OSRM
  Future<List<LatLng>> _getRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
          '?overview=full&geometries=geojson',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List coords = data['routes'][0]['geometry']['coordinates'];
      return coords.map((c) => LatLng(c[1], c[0])).toList();
    } else {
      throw Exception("Gagal memuat rute");
    }
  }

  void _speakInstruction(String instruction) async {
    await _tts.setLanguage("id-ID");
    await _tts.speak(instruction);
  }

  // void _checkNextStep() {
  //   if (_currentStepIndex >= _steps.length) {
  //     setState(() => _currentInstruction = "Anda telah sampai tujuan");
  //     _tts.speak("Anda telah sampai tujuan");
  //     return;
  //   }
  //
  //   final step = _steps[_currentStepIndex];
  //   final distance = Distance().as(LengthUnit.Meter, _currentLatLng!, step['location']);
  //
  //   if (distance < 20) { // kalau sudah dekat step berikutnya
  //     setState(() => _currentInstruction = step['instruction']); // update teks
  //     _speakInstruction(step['instruction']); // suara TTS
  //     _currentStepIndex++;
  //   }
  // }

  // void _startNavigation() {
  //   const locationSettings = LocationSettings(
  //     accuracy: LocationAccuracy.best, // bisa high, medium, low
  //     distanceFilter: 5, // update setiap 5 meter
  //   );
  //
  //   _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
  //       .listen((Position position) {
  //     setState(() {
  //       _currentLatLng = LatLng(position.latitude, position.longitude);
  //       _mapController.move(_currentLatLng!, 17);
  //     });
  //
  //     // _checkNextStep();
  //   });
  // }

  /// 📍 Saat lokasi dipilih dari hasil pencarian
  void _onLocationSelected(double lat, double lon, String name) async {
    final newPosition = LatLng(lat, lon);
    _mapController.move(newPosition, 15);

    setState(() {
      _selectedLatLng = newPosition;
      _center = newPosition;
      _allRoutes = [];
      _selectedRouteIndex = 0;
      _isLoading = true;
    });

    if (_currentLatLng != null) {
      final route = await _getRoute(_currentLatLng!, newPosition);
      setState(() async {
        _routePoints = await _getRoute(_currentLatLng!, newPosition);
      });

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
            '${_currentLatLng!.longitude},${_currentLatLng!.latitude};${newPosition.longitude},${newPosition.latitude}'
            '?overview=full&geometries=geojson&alternatives=true',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List routes = data['routes'];
        final List<List<LatLng>> tempRoutes = [];
        for (var r in routes) {
          final coords = r['geometry']['coordinates'];
          tempRoutes.add(coords.map((c) => LatLng(c[1], c[0])).toList());
        }
        setState(() {
          _allRoutes = tempRoutes;
          _routePoints = _allRoutes.first; // default rute pertama
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final mapHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFE4F0FF),
      body: SafeArea(
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                  _currentLatLng ?? const LatLng(-6.1754, 106.8272),
                  initialZoom: 14,
                  // interactionOptions:
                  // const InteractionOptions(flags: InteractiveFlag.all),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.safora',
                  ),

                  // Marker user
                  if (_currentLatLng != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLatLng!,
                          width: 18,
                          height: 18,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 13,
                                height: 13,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Marker tujuan
                  if (_selectedLatLng != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLatLng!,
                          width: 18,
                          height: 18,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                            size: 30,
                          ),
                        ),
                      ],
                    ),

                  // Polyline rute
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: Colors.blueAccent,
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Compass
            Positioned(
              top: 80,
              right: 8,
              child: FlutterMapCompass(
                mapController: _mapController,
                size: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),

            // Search bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: TypeAheadField<Map<String, dynamic>>(
                  controller: _searchController,
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        prefixIcon:
                        const Icon(Icons.search, color: Colors.black54),
                        hintText: "Cari lokasi...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                      ),
                    );
                  },
                  suggestionsCallback: _searchLocation,
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      leading: const Icon(Icons.location_on,
                          color: Colors.blueAccent),
                      title: Text(
                        suggestion['name'],
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                  onSelected: (suggestion) {
                    _onLocationSelected(suggestion['lat'], suggestion['lon'],
                        suggestion['name']);
                    _searchController.text = suggestion['name'];
                    FocusScope.of(context).unfocus();
                  },
                  debounceDuration: const Duration(milliseconds: 400),
                ),
              ),
            ),

            // Button lokasi user
            Positioned(
              top: mapHeight * 0.21,
              right: 18,
              child: Container(
                width: 51,
                height: 51,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: FloatingActionButton(
                    heroTag: 'locateMe',
                    backgroundColor: Colors.white,
                    elevation: 0,
                    onPressed: _getUserLocation,
                    shape: const CircleBorder(),
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blueAccent,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),

            // Navigation card
            // if (_selectedLatLng != null)
            //   Positioned(
            //     bottom: 20,
            //     left: 0,
            //     right: 0,
            //     child: Padding(
            //       padding: const EdgeInsets.symmetric(horizontal: 16.0),
            //       child: Container(
            //         padding: const EdgeInsets.all(16),
            //         decoration: BoxDecoration(
            //           color: Colors.white,
            //           borderRadius: BorderRadius.circular(15),
            //           boxShadow: [
            //             BoxShadow(
            //               color: Colors.grey.withOpacity(0.3),
            //               spreadRadius: 2,
            //               blurRadius: 5,
            //               offset: const Offset(0, 3),
            //             ),
            //           ],
            //         ),
            //         // child: Column(
            //         //   mainAxisSize: MainAxisSize.min,
            //         //   children: [
            //         //     Text(
            //         //       _currentInstruction.isNotEmpty
            //         //           ? _currentInstruction
            //         //           : (_routePoints.isNotEmpty
            //         //           ? formatDistance(calculateRouteDistance(_routePoints))
            //         //           : ' '),
            //         //       style: const TextStyle(
            //         //         fontSize: 18,
            //         //         fontWeight: FontWeight.bold,
            //         //         color: Color(0xFF5E7989),
            //         //       ),
            //         //       textAlign: TextAlign.center,
            //         //     ),
            //         //     const Divider(color: Colors.grey, height: 20, thickness: 1),
            //         //     // SizedBox(
            //         //     //   width: double.infinity,
            //         //     //   child: ElevatedButton(
            //         //     //     onPressed: () async {
            //         //     //       if (_currentLatLng != null && _selectedLatLng != null) {
            //         //     //         _steps = (await _getRoute(_currentLatLng!, _selectedLatLng!))
            //         //     //             .cast<Map<String, dynamic>>();
            //         //     //         _currentStepIndex = 0;
            //         //     //         // _startNavigation();
            //         //     //       }
            //         //     //     },
            //         //     //     style: ElevatedButton.styleFrom(
            //         //     //       backgroundColor: const Color(0xFF00C2FF),
            //         //     //       padding: const EdgeInsets.symmetric(vertical: 15),
            //         //     //       shape: RoundedRectangleBorder(
            //         //     //         borderRadius: BorderRadius.circular(10),
            //         //     //       ),
            //         //     //     ),
            //         //     //     child: const Text(
            //         //     //       'Start Navigation',
            //         //     //       style: TextStyle(
            //         //     //         fontSize: 18,
            //         //     //         color: Colors.white,
            //         //     //         fontWeight: FontWeight.bold,
            //         //     //       ),
            //         //     //     ),
            //         //     //   ),
            //         //     // ),
            //         //   ],
            //         // ),
            //       ),
            //     ),
            //   ),

          ],
        ),
      ),
    );
  }

  calculateRouteDistance(List<LatLng> points) {
    if (points.length < 2) return 0;
    final Distance distance = Distance();
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += distance.as(LengthUnit.Meter, points[i], points[i + 1]);
    }
    return total;
  }
}
