import 'package:flutter/material.dart';
import 'widgets/m3e/loading_indicator.dart';
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
      // The status bar has to follow the theme, and the theme is only known
      // below `MaterialApp` — `themeMode: system` resolves here, not in
      // `main()`. An annotated region re-derives the overlay style on every
      // build, so switching themes from the profile screen takes the clock and
      // the battery with it.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: PlaneTheme.overlayStyle(Theme.of(context).brightness),
        child: child ?? const SizedBox.shrink(),
      ),
      home: _checking
          ? const Scaffold(body: Center(child: M3ELoadingIndicator(size: 44)))
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
