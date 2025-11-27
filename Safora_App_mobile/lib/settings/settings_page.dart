import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:safora_app/PROTOTIPE/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:safora_app/login/login_page.dart';
import 'package:safora_app/crash log/chat_emergency.dart';

class settingsPage extends StatefulWidget {
  const settingsPage({super.key});

  @override
  State<settingsPage> createState() => _settingsPageState();
}

class _settingsPageState extends State<settingsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> emergencyContacts = [];
  bool isLoading = true;

  // Fungsi ambil data dari Supabase
  Future<void> fetchEmergencyContacts() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('emergency_contacts')
          .select()
          .eq('user_id', userId);

      setState(() {
        emergencyContacts = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching contacts: $e");
      setState(() => isLoading = false);
    }
  }

  // Variabel state untuk slider dan switch
  double headlampHeight = 1;
  double headlampIntensity = 1;
  double turnFlashRate = 1;
  double hazardFlashRate = 1;
  double hazardFlashRate2 = 1;
  bool autoHeadlamp = true;
  bool autoHazard = true;

  @override
  void initState() {
    super.initState();
    fetchEmergencyContacts();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE4F0FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // const Text(
              //   'Settings',
              //   style: TextStyle(
              //     fontSize: 28,
              //     fontWeight: FontWeight.bold,
              //     color: Color(0xFF003366),
              //   ),
              // ),
              const SizedBox(height: 20),

              // Auto Engine Cut Off
              _buildSettingCard(),
              const SizedBox(height: 16),

              // HeadLamp Config
              _buildHeadlampCard(),
              const SizedBox(height: 16),

              // Turn Signal Config
              _buildTurnSignalCard(),
              const SizedBox(height: 16),

              // Emergency Hazard Config
              _buildEmergencyHazardCard(),
              const SizedBox(height: 16),

              _buildEmergencyCallCard(),
              const SizedBox(height: 16),

              // System Config
              _buildSystemCard(),
              const SizedBox(height: 16),

              _buildLogoutCard(context),
            ],
          ),
        ),
      ),
    );
  }

  // Card Builder
  Widget _buildSettingCard() {
    return _cardContainer(
      child: Row(
        children: [
          const Icon(Icons.key_off_rounded),
          const SizedBox(width: 15),
            const Expanded(
              child: Text(
                'Auto Engine Cut Off',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
            ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.lock_rounded, color: Color(0xFF003366), size: 28),
          ),
        ],
      ),
  );
}

  Widget _buildHeadlampCard() {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_rounded),
              SizedBox(width: 15),
              Text(
                'HeadLamp Configuration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
            ],
          ),
          const Divider(height: 25, thickness: 1),

          // Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('HeadLamp Auto Mode', style: TextStyle(fontSize: 16)),
              Switch(
                value: autoHeadlamp,
                onChanged: (val) => setState(() => autoHeadlamp = val),
              ),
            ],
          ),

          // Slider Height
          _buildSliderWithLabel(
            title: 'HeadLamp Height',
            minLabel: 'Low',
            midLabel: 'Medium',
            maxLabel: 'High',
            value: headlampHeight,
            onChanged: (val) => setState(() => headlampHeight = val),
          ),

          // Slider Intensity
          _buildSliderWithLabel(
            title: 'HeadLamp Intensity',
            minLabel: 'Low',
            midLabel: 'Medium',
            maxLabel: 'High',
            value: headlampIntensity,
            onChanged: (val) => setState(() => headlampIntensity = val),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnSignalCard() {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.compare_arrows_rounded),
              SizedBox(width: 15),
              Text(
                'Turn Signal Configuration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
            ],
          ),
          const Divider(height: 25, thickness: 1),

          _buildSliderWithLabel(
            title: 'Turn Flash Rate',
            minLabel: 'Low',
            midLabel: 'Medium',
            maxLabel: 'High',
            value: turnFlashRate,
            onChanged: (val) => setState(() => turnFlashRate = val),
          ),

          _buildSliderWithLabel(
            title: 'Hazard Flash Rate',
            minLabel: 'Low',
            midLabel: 'Medium',
            maxLabel: 'High',
            value: hazardFlashRate,
            onChanged: (val) => setState(() => hazardFlashRate = val),
          ),

        ],
      ),
    );
  }

  Widget _buildEmergencyHazardCard() {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_rounded),
              SizedBox(width: 15),
              Text(
                'Emergency Hazard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
            ],
          ),
          const Divider(height: 25, thickness: 1),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Auto Hazard', style: TextStyle(fontSize: 16)),
              Switch(
                value: autoHazard,
                onChanged: (val) => setState(() => autoHazard = val),
              ),
            ],
          ),

          _buildSliderWithLabel(
            title: 'Hazard Flash Rate',
            minLabel: 'Low',
            midLabel: 'Medium',
            maxLabel: 'High',
            value: hazardFlashRate2,
            onChanged: (val) => setState(() => hazardFlashRate2 = val),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCallCard() {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.phone_in_talk, color: Colors.black87),
              SizedBox(width: 10),
              Text(
                'Contact Emergency Call',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Loading indicator
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (emergencyContacts.isEmpty)
            const Center(
              child: Text(
                "No emergency contacts found.",
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            Column(
              children: emergencyContacts.map((contact) {
                return _buildContactItem(
                  name: contact["name"] ?? "",
                  phone: contact["phone_number"] ?? "",
                );
              }).toList(),
            ),

          const SizedBox(height: 15),

          Center(
            child: ElevatedButton.icon(
              onPressed: () => _showAddContactDialog(),
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text(
                "Add Contact",
                style: TextStyle(color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                  side: const BorderSide(color: Color(0xFFBCCEE0)),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required String name,
    required String phone,
  }) {
    return ListTile(
      leading: const CircleAvatar(
      radius: 18,
      backgroundColor: Colors.redAccent,
      child: Icon(Icons.phone, color: Colors.white),
    ),
      title: Text(name),
      subtitle: Text(phone),
      trailing: IconButton(
        icon: const Icon(
          Icons.delete_forever,
          color: Colors.red,
          size: 20,
        ),
        onPressed: () async {
          try {
            // Konfirmasi sebelum hapus
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: const Text("Delete Contact",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003366),
                  ),
                ),
                content: Text("Are you sure you want to delete the contact $name?",
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    color: Colors.black87,
                ),),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel",
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await supabase
                  .from('emergency_contacts')
                  .delete()
                  .eq('phone_number', phone);

              await fetchEmergencyContacts(); // refresh data setelah hapus

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Kontak $name berhasil dihapus")),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Gagal menghapus kontak: $e")),
            );
          }
        },

      ),

    );
  }

  void _showAddContactDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController relationshipController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text("Add Emergency Contact",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF003366),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Text(
                //   "Make sure the registered number is registered with Telegram. "
                //       "Otherwise, this contact won't be able to receive emergency calls.",
                //   style: TextStyle(color: Colors.red[700], fontSize: 12, ),
                // ),
                const SizedBox(height: 15),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    icon : Icon(Icons.drive_file_rename_outline, color: AppColors.navy),
                    labelText: "Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    icon: Icon(Icons.phone, color: AppColors.navy),
                    labelText: "Phone ",
                    border: OutlineInputBorder(),
                    prefixText: '+62 ',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: relationshipController,
                  decoration: const InputDecoration(
                    icon: Icon(Icons.family_restroom, color: AppColors.navy),
                    labelText: "Relationship",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              onPressed: () async {
                if (nameController.text.isNotEmpty &&
                    phoneController.text.isNotEmpty &&
                    relationshipController.text.isNotEmpty) {
                  try {
                    final userId = supabase.auth.currentUser?.id;
                    if (userId == null) return;

                    // Tambahkan +62 secara otomatis
                    String phoneNumber = phoneController.text.trim();
                    if (phoneNumber.startsWith('0')) {
                      phoneNumber = phoneNumber.substring(1);
                    }
                    phoneNumber = '+62$phoneNumber';

                    await supabase.from('emergency_contacts').insert({
                      'user_id': userId,
                      'name': nameController.text.trim(),
                      'phone_number': phoneNumber,
                      'relationship': relationshipController.text.trim(),
                    });

                    // Refresh data dari Supabase
                    await fetchEmergencyContacts();

                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menambah kontak: $e')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Semua field wajib diisi'),
                    ),
                  );
                }
              },
              child: const Text("Add",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              )
            ),
          ],
        );
      },
    );
  }

  Widget _buildSystemCard() {
    return _cardContainer(
      child: Row(
        children: [
          const Icon(Icons.settings_rounded, color: Colors.red,),
          const SizedBox(width: 15),
          const Expanded(
            child: Text(
              'Systems',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.refresh_rounded, color: Colors.red, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderWithLabel({
    required String title,
    required String minLabel,
    String? midLabel,
    required String maxLabel,
    required double value,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontSize: 16)),

        Slider(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF003366),
          inactiveColor: const Color(0xFFBCCEE0),
          min: 0,
          max: 2,       // 0, 1, 2
          divisions: 2, // hanya 3 posisi
          label: value == 0
              ? minLabel
              : value == 1
              ? (midLabel ?? "")
              : maxLabel,
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(minLabel),
            if (midLabel != null) Text(midLabel!),
            Text(maxLabel),
          ],
        ),
      ],
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: child,
    );
  }

  // 🔹 Fungsi Logout
  Future<void> _logout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal logout: $e')),
      );
    }
  }

  // 🔹 Widget Logout Card
  Widget _buildLogoutCard(BuildContext context) {
    return _cardContainer(
      child: Row(
        children: [
          const Icon(Icons.logout_rounded, color: Colors.black87),
          const SizedBox(width: 15),
          const Expanded(
            child: Text(
              'Logout Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003366),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.exit_to_app_rounded,
              color: Colors.black87,
              size: 28,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: const Text(
                    'Logout Confirmation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003366),
                    ),
                  ),
                  content: const Text(
                    'Are you sure you want to log out of this account?',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: Colors.black87,
                    ),
                  ),
                  actionsAlignment: MainAxisAlignment.end,
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _logout(context);
              }
            },
          ),
        ],
      ),
    );
  }

}
