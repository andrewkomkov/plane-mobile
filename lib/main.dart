import 'package:flutter/material.dart';
import 'config/secure_storage.dart';
import 'screens/setup/setup_screen.dart';
import 'screens/home/home_screen.dart';

void main() {
  runApp(const PlaneApp());
}

class PlaneApp extends StatefulWidget {
  const PlaneApp({super.key});

  @override
  State<PlaneApp> createState() => _PlaneAppState();
}

class _PlaneAppState extends State<PlaneApp> {
  bool _configured = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkConfig();
  }

  Future<void> _checkConfig() async {
    final configured = await SecureStorage.isConfigured();
    setState(() {
      _configured = configured;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plane',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[800]!),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: _checking
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _configured
              ? HomeScreen(onLogout: () => setState(() => _configured = false))
              : SetupScreen(onConfigured: () => setState(() => _configured = true)),
    );
  }
}
