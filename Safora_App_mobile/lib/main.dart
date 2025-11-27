import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safora_app/DATABASE/supabase_config.dart';
import 'package:safora_app/dashboard/dashboard_page.dart';
import 'package:safora_app/maps/maps_page.dart';
import 'package:safora_app/crash log/crashlog_page.dart';
import 'package:safora_app/settings/settings_page.dart';
import 'package:safora_app/navbar.dart';
import 'package:safora_app/login/login_page.dart';
import 'package:safora_app/login/signin_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:safora_app/crash log/notif_emergency.dart'
    '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

/// Mengecek apakah user sudah login
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null && session.user != null) {
      return const HomePage(); // sudah login
    } else {
      return const LoginPage(); // belum login
    }
  }
}

/// Halaman utama setelah login
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    // const AccidentAlertPage(),
    const dashboardPage(),
    const mapsPage(),
    const crashLogPage(),
    const settingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: CustomNavbar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
