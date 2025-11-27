import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'last_location.dart';
import 'package:safora_app/crash log/chat_emergency.dart';

class crashLogPage extends StatefulWidget {
  const crashLogPage({super.key});

  @override
  State<crashLogPage> createState() => _crashLogPageState();
}

class _crashLogPageState extends State<crashLogPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> crashLogs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCrashLogs();
  }

  Future<void> fetchCrashLogs() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await supabase
          .from('crash_logs')
          .select()
          .eq('user_id', userId) as List<dynamic>;

      List<Map<String, dynamic>> logs = [];

      for (var e in data) {
        double gforce = e['gforce'] ?? 0;
        String severity = getSeverity(gforce);

        // Format tanggal | waktu
        String crashTime = '';
        if (e['crash_time'] != null) {
          final dt = DateTime.parse(e['crash_time']);
          crashTime = DateFormat('yyyy-MM-dd | HH:mm:ss').format(dt);
        }

        // Reverse geocoding untuk nama lokasi
        String location = await getLocationName(e['latitude'], e['longitude']);

        logs.add({
          'gforce': gforce,
          'latitude': e['latitude'],
          'longitude': e['longitude'],
          'location': location,
          'crash_time': crashTime,
          'severity': severity,
          'speed': e['speed'],
        });
      }

      setState(() {
        crashLogs = logs;
        isLoading = false;
      });
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil crash logs: $error')),
        );
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  String getSeverity(double gforce) {
    if (gforce < 5) return 'minor';
    if (gforce < 20) return 'mild';
    if (gforce < 60) return 'severe';
    return 'extreme';
  }

  Future<String> getLocationName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return "${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}".replaceAll(RegExp(r'^, |, $'), '');
      }
    } catch (e) {
      print("Error reverse geocoding: $e");
    }
    return "Unknown Location";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE4F0FF),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : crashLogs.isEmpty
            ? const Center(child: Text("Tidak ada crash log"))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: crashLogs.map((log) => _buildCrashCard(log)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildCrashCard(Map<String, dynamic> log) {
    Color severityColor;
    IconData severityIcon;

    switch (log['severity'].toString().toLowerCase()) {
      case 'minor':
        severityColor = Colors.green[100]!;
        severityIcon = Icons.report;
        break;
      case 'mild':
        severityColor = Colors.orange[100]!;
        severityIcon = Icons.warning;
        break;
      case 'severe':
        severityColor = Colors.red[100]!;
        severityIcon = Icons.dangerous;
        break;
      case 'extreme':
        severityColor = Colors.redAccent[100]!;
        severityIcon = Icons.warning_amber_outlined;
        break;
      default:
        severityColor = Colors.grey[200]!;
        severityIcon = Icons.info;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${log['crash_time']}",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Text(
            "${log['location']}",
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: severityColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 3,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(severityIcon, color: Colors.black54, size: 40),
                const SizedBox(width: 8),
                Text(
                  "${log['severity']}",
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(Icons.bar_chart, "G-Force", "${log['gforce']} g"),
          const Divider(),
          _buildDetailRow(Icons.speed, "Speed", "${log['speed']} km/h"),
          const Divider(),
          const SizedBox(height: 16),
          GetLocationMapButton(
            latitude: log['latitude'],
            longitude: log['longitude'],
          ),
          const SizedBox(height: 12),
          const EmergencyCallButton(),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 15, color: Colors.black87)),
        ]),
        Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }
}