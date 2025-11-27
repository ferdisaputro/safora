import 'dart:convert';
import 'package:air_quality/air_quality.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:safora_app/maps/location_services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';


import 'package:safora_app/PROTOTIPE/color.dart';
import 'package:safora_app/PROTOTIPE/icon.dart';
import 'package:safora_app/PROTOTIPE/text_style.dart';
import 'package:safora_app/dashboard/bluetooth_device.dart';
import 'package:safora_app/dashboard/connect_devices.dart';

import 'package:safora_app/maps/compas_maps.dart';
import 'package:weather/weather.dart';



class dashboardPage extends StatefulWidget {
  const dashboardPage({super.key});


  @override
  State<dashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<dashboardPage> {
  final MapController _mapController = MapController();

  bool autoAdjustment = true;
  double headlampHeight = 50.0;
  double headlampIntensity = 50.0;

  String _currentAddress = "Loading...";
  String _weather = '';
  String _temperature = '';
  String _weatherIcon = '';

  AirQuality? _airQuality;
  double _aqiValue = 0;
  Color _aqiColor = Colors.grey;
  String _aqiStatus = 'Loading...';

  LatLng? _currentLatLng;

  @override
  void initState() {
    super.initState();
    _airQuality = AirQuality('19007ede24a9b3811fa90262650129fa870ba916');
    _getUserLocation();
  }

  // Ambil lokasi user
  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng latLng = LatLng(position.latitude, position.longitude);

      setState(() => _currentLatLng = latLng);
      _mapController.move(latLng, 13);

      await _getAddressFromLatLng(latLng);
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  // Ambil alamat + cuaca + AQI
  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() => _currentAddress = "${place.subLocality}, ${place.locality}");
      }
      await _getWeather(position);
      await _getAirQuality(position);
    } catch (e) {
      setState(() => _currentAddress = "Location Not Found");
      print(e);
    }
  }

  // Ambil cuaca
  Future<void> _getWeather(LatLng position) async {
    const apiKey = '738e489f709bf772500bd673e4c154d7';
    WeatherFactory wf = WeatherFactory(apiKey, language: Language.ENGLISH);

    try {
      Weather w = await wf.currentWeatherByLocation(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _temperature = w.temperature?.celsius?.toStringAsFixed(0) ?? '--';
        _weather = w.weatherDescription ?? 'Tidak diketahui';
        _weatherIcon = w.weatherIcon ?? '';
      });
    } catch (e) {
      print("Gagal mengambil data cuaca: $e");
    }
  }

  // Ambil AQI
  Future<void> _getAirQuality(LatLng position) async {
    if (_airQuality == null) return;

    try {
      AirQualityData data = await _airQuality!.feedFromGeoLocation(
        position.latitude,
        position.longitude,
      );

      // Ambil nilai AQI asli
      double aqi = (data.airQualityIndex ?? 0).toDouble();

      // Tentukan level & warna berdasarkan range AQI
      Color color;
      String status;

      if (aqi <= 50) {
        color = Colors.green;
        status = "Good";
      } else if (aqi <= 100) {
        color = Colors.yellow;
        status = "Moderate";
      } else if (aqi <= 150) {
        color = Colors.orange;
        status = "Unhealthy for Sensitive Groups";
      } else if (aqi <= 200) {
        color = Colors.red;
        status = "Unhealthy";
      } else if (aqi <= 300) {
        color = Colors.purple;
        status = "Very Unhealthy";
      } else {
        color = Colors.brown;
        status = "Hazardous";
      }

      setState(() {
        _aqiValue = aqi;
        _aqiColor = color;
        _aqiStatus = status;
      });
    } catch (e) {
      print("Error fetching AQI: $e");
      setState(() {
        _aqiValue = 0;
        _aqiColor = Colors.grey;
        _aqiStatus = "Unavailable";
      });
    }
  }

  // Dekorasi card
  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadow.withOpacity(0.1),
        spreadRadius: 2,
        blurRadius: 5,
        offset: const Offset(0, 3),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bagian Header
              const Text(
                'Welcome to SAFORA ! ',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const Text(
                'Your Smart Assistant for Safer Road Operations',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 20),

              // Bagian Weather & Devices
              Row(
                children: [
                  Expanded(flex : 1, child: _buildWeatherCard()),
                  const SizedBox(width: 10),
                  Expanded(flex : 1, child: _buildDeviceCard(deviceNumber: 0, isConnected: false)),
                ],
              ),
              const SizedBox(height: 20),

              // Bagian Peta
              _buildMapCard(),
              const SizedBox(height: 20),

              // Bagian Auto Adjustment
              _buildAutoAdjustmentCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// Weather Card
  Widget _buildWeatherCard() {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Alamat
          Text(
            _currentAddress,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.secondary),
          ),
          const SizedBox(height: 10),

          // Weather + icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_weatherIcon.isNotEmpty)
                Image.network(
                  'https://openweathermap.org/img/wn/${_weatherIcon}@2x.png',
                  width: 55,
                  height: 55,
                )
              else
                const Icon(Icons.wb_sunny_rounded, size: 45, color: Color(0xFFFFCC00)),
              const SizedBox(width: 5),
              Text(
                _temperature.isNotEmpty ? '$_temperature°' : '--°',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),

          // Weather description
          Text(
            _weather.isNotEmpty ? _weather : 'Loading...',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.secondary),
          ),
          const SizedBox(height: 12),

          // AQI Bar full-width dengan warna sesuai kategori
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: _aqiColor, // warna sesuai level AQI
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300, width: 0),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              // Tampilkan nilai AQI asli + kategori
              Text(
                '(${_aqiValue.toInt()}) $_aqiStatus',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _aqiColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Device Card
  Widget _buildDeviceCard({required bool isConnected, required int deviceNumber}) {
    return GestureDetector(
      onTap: () async {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BluetoothScreen()),
        );
      },
      child: Container(
        height: 220, // 🔹 Samakan tinggi
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // 🔹 Tengah vertikal
          crossAxisAlignment: CrossAxisAlignment.center, // 🔹 Tengah horizontal
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                '    $deviceNumber    ',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isConnected ? 'Connected' : 'Disconnected',
              style: TextStyle(
                fontSize: 14,
                color: isConnected ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 60, // 🔹 Sedikit lebih kecil biar proporsional
              height: 60,
              decoration: BoxDecoration(
                color: isConnected ? Colors.green[100] : Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Icon(
                  Icons.bluetooth_audio_rounded,
                  size: 35,
                  color: isConnected ? Colors.green[800] : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Map Card
  Widget _buildMapCard() {
    return Container(
      height: 200,
      decoration: _cardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLatLng ?? LatLng(-7.4463, 112.7171),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.safora',
                ),

                // Marker lokasi user
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
                                color: Colors.black.withOpacity(0.25),
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
              ],
            ),

            // Kompas
            Positioned(
              top: 10,
              right: 10,
              child: FlutterMapCompass(
                mapController: _mapController,
                size: 35,
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

            // Tombol lokasi saya
            // Positioned(
            //   bottom: 10,
            //   right: 10,
            //   child: GestureDetector(
            //     onTap: () async {
            //       await _getUserLocation();
            //       if (_currentLatLng != null) {
            //         _mapController.move(_currentLatLng!, 16);
            //       }
            //     },
            //     // child: Container(
            //     //   width: 45,
            //     //   height: 45,
            //     //   decoration: BoxDecoration(
            //     //     color: Colors.white,
            //     //     shape: BoxShape.circle,
            //     //     boxShadow: [
            //     //       BoxShadow(
            //     //         color: Colors.black.withOpacity(0.2),
            //     //         blurRadius: 4,
            //     //         offset: const Offset(0, 2),
            //     //       ),
            //     //     ],
            //     //   ),
            //     //   child: const Icon(Icons.my_location, color: Colors.blueAccent),
            //     // ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  // Auto Adjustment Card
  Widget _buildAutoAdjustmentCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Auto Adjustment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              Switch(
                value: autoAdjustment,
                onChanged: (value) {
                  setState(() {
                    autoAdjustment = value;
                  });
                },
                activeColor: AppColors.navy,
                trackColor:
                MaterialStateProperty.all(AppColors.background),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Headlamp Height
          const Text(
            'Headlamp Height',
            style: TextStyle(fontSize: 16, color: AppColors.secondary),
          ),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.navy,
                    inactiveTrackColor: AppColors.background,
                    thumbColor: AppColors.white,
                    thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 10),
                    trackHeight: 8.0,
                    overlayColor:
                    AppColors.navy.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: headlampHeight,
                    min: 0,
                    max: 100,
                    onChanged: (value) {
                      setState(() {
                        headlampHeight = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${headlampHeight.toInt()}%',
                style:
                const TextStyle(fontSize: 16, color: AppColors.secondary),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Headlamp Intensity
          const Text(
            'Headlamp Intensity',
            style: TextStyle(fontSize: 16, color: AppColors.secondary),
          ),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.navy,
                    inactiveTrackColor: AppColors.background,
                    thumbColor: AppColors.white,
                    thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 10),
                    trackHeight: 8.0,
                    overlayColor:
                    AppColors.navy.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: headlampIntensity,
                    min: 0,
                    max: 100,
                    onChanged: (value) {
                      setState(() {
                        headlampIntensity = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${headlampIntensity.toInt()}%',
                style:
                const TextStyle(fontSize: 16, color: AppColors.secondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
