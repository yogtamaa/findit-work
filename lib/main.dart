import 'package:flutter/material.dart';

import 'core/security/token_storage.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/worker/screens/worker_dashboard_screen.dart';

void main() => runApp(const WorkerApp());

class WorkerApp extends StatelessWidget {
  const WorkerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FindIt! Worker',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF00236F), useMaterial3: true),
      home: const AuthGate(),
    );
  }
}

/// Menentukan halaman awal berdasarkan sesi yang tersimpan.
///
/// Berkat fitur "Ingat Saya", token yang disimpan permanen membuat aplikasi
/// langsung masuk ke Dashboard saat dibuka kembali — tanpa login ulang.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<bool> _hasSession = _checkSession();

  Future<bool> _checkSession() async {
    final token = await TokenStorage.readToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasSession,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SplashScreen();
        }
        final loggedIn = snapshot.data ?? false;
        return loggedIn ? const WorkerDashboardScreen() : const LoginScreen();
      },
    );
  }
}

/// Layar singkat saat aplikasi mengecek sesi tersimpan.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Image(
              image: AssetImage('assets/images/logo-light.png'),
              height: 76,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 16),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFF9F1C)),
            ),
          ],
        ),
      ),
    );
  }
}