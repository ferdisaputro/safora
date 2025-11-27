import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:safora_app/PROTOTIPE/color.dart';

class ChatEmergencyService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> sendEmergencyMessage(BuildContext context, String contact) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 🔹 Ambil data crash terbaru user
      final crashResponse = await supabase
          .from('crash_logs')
          .select('latitude, longitude')
          .eq('user_id', user.id)
          .order('crash_time', ascending: false)
          .limit(1);

      if (crashResponse.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Belum ada data lokasi kecelakaan.")),
        );
        return;
      }

      final latitude = crashResponse[0]['latitude'];
      final longitude = crashResponse[0]['longitude'];
      final mapsUrl = "https://www.google.com/maps?q=$latitude,$longitude";

      final message = Uri.encodeComponent(
        "🚨 *DARURAT!* Terjadi insiden! Mohon bantuan segera ke lokasi berikut:\n📍 $mapsUrl",
      );

      // 🔹 Nomor pengirim (identifikasi saja)
      const sender = "62882009244551";

      // 🔹 Buat URL WhatsApp
      final waUrl = "https://wa.me/$contact?text=$message";

      // 🔹 Buka WhatsApp otomatis
      if (await canLaunchUrl(Uri.parse(waUrl))) {
        await launchUrl(
          Uri.parse(waUrl),
          mode: LaunchMode.externalApplication,
        );

        // 🔹 Notifikasi setelah membuka WhatsApp
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Membuka WhatsApp untuk mengirim pesan darurat..."),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak bisa membuka WhatsApp.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal mengirim pesan: $e")),
      );
    }
  }
}

class EmergencyCallButton extends StatefulWidget {
  const EmergencyCallButton({super.key});

  @override
  State<EmergencyCallButton> createState() => _EmergencyCallButtonState();
}

class _EmergencyCallButtonState extends State<EmergencyCallButton> {
  final SupabaseClient supabase = Supabase.instance.client;
  final ChatEmergencyService emergencyService = ChatEmergencyService();
  List<Map<String, String>> emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    fetchEmergencyContacts();
  }

  Future<void> fetchEmergencyContacts() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await supabase
          .from('emergency_contacts')
          .select('name, phone_number')
          .eq('user_id', userId) as List<dynamic>;

      setState(() {
        emergencyContacts = data.map((e) {
          return {
            'name': (e['name'] ?? '').toString(),
            'phone': (e['phone_number'] ?? '').toString(),
          };
        }).toList();
      });
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil kontak: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _showEmergencyContactsDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Emergency WhatsApp',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showEmergencyContactsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        if (emergencyContacts.isEmpty) {
          return AlertDialog(
            title: const Text('No Contacts'),
            content: const Text('You have no emergency contacts yet.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        }

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Pilih Kontak Darurat',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.navy,
            ),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: emergencyContacts.map((contact) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () async {
                        Navigator.pop(context);
                        await emergencyService.sendEmergencyMessage(
                          context,
                          contact['phone']!,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white70,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.green,
                              child: FaIcon(FontAwesomeIcons.whatsapp,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact['name']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(contact['phone']!),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.navy),
              ),
            ),
          ],
        );
      },
    );
  }
}
