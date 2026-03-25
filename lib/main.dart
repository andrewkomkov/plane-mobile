import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/secure_storage.dart';
import 'config/theme.dart';
import 'providers/theme_provider.dart';
import 'screens/setup/setup_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/push_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: PlaneApp()));
}

class PlaneApp extends ConsumerStatefulWidget {
  const PlaneApp({super.key});

  @override
  ConsumerState<PlaneApp> createState() => _PlaneAppState();
}

class _PlaneAppState extends ConsumerState<PlaneApp> {
  bool _configured = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkConfig();
  }

  Future<void> _checkConfig() async {
    final configured = await SecureStorage.isConfigured();
    if (configured) {
      // Initialize push notifications after auth is confirmed
      PushNotificationService.initialize();
    }
    setState(() {
      _configured = configured;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Plane',
      debugShowCheckedModeBanner: false,
      theme: PlaneTheme.light(),
      darkTheme: PlaneTheme.dark(),
      themeMode: themeMode,
      home: _checking
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _configured
              ? HomeScreen(onLogout: () => setState(() => _configured = false))
              : SetupScreen(
                  onConfigured: () {
                    PushNotificationService.initialize();
                    setState(() => _configured = true);
                  }),
    );
  }
}
