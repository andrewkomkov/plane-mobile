import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/secure_storage.dart';
import 'config/theme.dart';
import 'screens/setup/setup_screen.dart';
import 'screens/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
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
      theme: PlaneTheme.light(),
      darkTheme: PlaneTheme.dark(),
      themeMode: ThemeMode.system,
      home: _checking
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _configured
              ? HomeScreen(onLogout: () => setState(() => _configured = false))
              : SetupScreen(onConfigured: () => setState(() => _configured = true)),
    );
  }
}
