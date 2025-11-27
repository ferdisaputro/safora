import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://uqrwxroobqqcoxybgjol.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVxcnd4cm9vYnFxY294eWJnam9sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkzNDUyMTQsImV4cCI6MjA3NDkyMTIxNH0.4GyEhWOKTzSLDIudSb_qy1ZJX_vZ6BcWZdQVoUhop44';

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
