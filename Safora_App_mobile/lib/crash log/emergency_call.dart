// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:safora_app/PROTOTIPE/color.dart';
//
// class EmergencyCallButton extends StatefulWidget {
//   const EmergencyCallButton({super.key});
//
//   @override
//   State<EmergencyCallButton> createState() => _EmergencyCallButtonState();
// }
//
// class _EmergencyCallButtonState extends State<EmergencyCallButton> {
//   final SupabaseClient supabase = Supabase.instance.client;
//   List<Map<String, String>> emergencyContacts = [];
//
//   @override
//   void initState() {
//     super.initState();
//     fetchEmergencyContacts();
//   }
//
//   Future<void> fetchEmergencyContacts() async {
//     final userId = supabase.auth.currentUser?.id;
//     if (userId == null) return;
//
//     try {
//       final data = await supabase
//           .from('emergency_contacts')
//           .select('name, phone_number')
//           .eq('user_id', userId) as List<dynamic>;
//
//       setState(() {
//         emergencyContacts = data.map((e) {
//           return {
//             'name': (e['name'] ?? '').toString(),
//             'phone': (e['phone_number'] ?? '').toString(),
//           };
//         }).toList();
//       });
//     } catch (error) {
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Gagal mengambil kontak: $error')),
//         );
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: double.infinity,
//       child: ElevatedButton(
//         onPressed: () {
//           _showEmergencyContactsDialog(context);
//         },
//         style: ElevatedButton.styleFrom(
//           backgroundColor: const Color(0xFFEF5350),
//           padding: const EdgeInsets.symmetric(vertical: 15),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//         child: const Text(
//           'Emergency Call',
//           style: TextStyle(
//             fontSize: 18,
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _showEmergencyContactsDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         if (emergencyContacts.isEmpty) {
//           return AlertDialog(
//             title: const Text("No Contacts"),
//             content: const Text("You have no emergency contacts yet."),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text("Close"),
//               ),
//             ],
//           );
//         }
//
//         return AlertDialog(
//           backgroundColor: Colors.white,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           title: const Text(
//             "Select Contact",
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               color: Color(0xFF003366),
//             ),
//           ),
//           content: ConstrainedBox(
//             constraints: BoxConstraints(
//               maxHeight: MediaQuery
//                   .of(context)
//                   .size
//                   .height * 0.7,
//               maxWidth: MediaQuery
//                   .of(context)
//                   .size
//                   .width * 0.9,
//             ),
//             child: SingleChildScrollView(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: emergencyContacts.map((contact) {
//                   return Container(
//                     margin: const EdgeInsets.only(bottom: 8),
//                     child: InkWell(
//                       onTap: () async {
//                         Navigator.pop(context);
//                         await callPhone(contact["phone"]!);
//                       },
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                             vertical: 8, horizontal: 10),
//                         decoration: BoxDecoration(
//                           color: Colors.white70,
//                           borderRadius: BorderRadius.circular(6),
//                         ),
//                         child: Row(
//                           children: [
//                             const CircleAvatar(
//                               radius: 18,
//                               backgroundColor: Colors.redAccent,
//                               child: Icon(Icons.phone, color: Colors.white),
//                             ),
//                             const SizedBox(width: 10),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     contact["name"]!,
//                                     style: const TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 2),
//                                   Text(contact["phone"]!),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   );
//                 }).toList(),
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text(
//                 "Cancel",
//                 style: TextStyle(color: AppColors.navy),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   // ✅ Panggilan telepon langsung
//   // ✅ Panggilan telepon langsung (Flutter only, tanpa Intent)
//   Future<void> callPhone(String phoneNumber) async {
//     if (phoneNumber.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Nomor telepon tidak valid.")),
//       );
//       return;
//     }
//
//     // ✅ Minta izin telepon
//     var status = await Permission.phone.request();
//
//     if (status.isGranted) {
//       try {
//         final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
//
//         // ✅ Gunakan url_launcher untuk langsung buka aplikasi telepon
//         final bool launched = await launchUrl(
//           uri,
//           mode: LaunchMode.externalNonBrowserApplication, // langsung buka app telepon
//         );
//
//         if (!launched) {
//           throw Exception("Tidak dapat memulai panggilan.");
//         }
//       } catch (e) {
//         if (context.mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text("Gagal melakukan panggilan: $e")),
//           );
//         }
//       }
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Izin panggilan ditolak.")),
//       );
//     }
//   }
//
// }