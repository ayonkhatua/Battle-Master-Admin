import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:battle_master_admin/screens/admin_login_screen.dart';
import 'package:battle_master_admin/screens/admin_dashboard_screen.dart'; // AdminDashboardScreen import kiya

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env file
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Battle Master - Admin Panel',
      theme: ThemeData(
        primarySwatch: Colors.red,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[800],
            foregroundColor: Colors.white,
          ),
        ),
      ),
      // 🌟 YAHAN UPDATE KIYA HAI: Direct initialRoute ki jagah AuthGate use kiya 🌟
      home: const AuthGate(), 
      routes: {
        // '/' route yahan se hata diya taaki conflict na ho
        '/admin_dashboard_screen': (context) => const AdminDashboardScreen(), 
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// 🛡️ SECURITY GATE: Check karega ki user pehle se login hai ya nahi
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Supabase se current session (token) check karo
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // ✅ Agar user pehle se login hai, seedha Admin Dashboard par bhejo
      return const AdminDashboardScreen();
    } else {
      // ❌ Agar login nahi hai (ya logout kar diya), toh Login Screen dikhao
      return const AdminLoginScreen();
    }
  }
}