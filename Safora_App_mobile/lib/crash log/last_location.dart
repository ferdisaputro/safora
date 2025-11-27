import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GetLocationMapButton extends StatelessWidget {
  final double latitude;
  final double longitude;

  const GetLocationMapButton({super.key, required this.latitude, required this.longitude});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MapsPreviewPage(
                latitude: latitude,
                longitude: longitude,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFBCCEE0)),
          ),
        ),
        child: const Text(
          'Get Last Location',
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF003366),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class MapsPreviewPage extends StatelessWidget {
  final double latitude;
  final double longitude;

  const MapsPreviewPage({super.key, required this.latitude, required this.longitude});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Get Last Location")),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(latitude, longitude),
          initialZoom: 15,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.safora',
            // tileProvider: const NonCachingNetworkTileProvider(),
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(latitude, longitude),
                width: 80,
                height: 80,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

