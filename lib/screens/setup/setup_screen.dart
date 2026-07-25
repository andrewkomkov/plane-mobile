import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';
import '../../widgets/m3e/loading_indicator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../config/secure_storage.dart';
import '../../config/api_client.dart';
import '../../services/auth_service.dart';

class SetupScreen extends StatefulWidget {
  final VoidCallback onConfigured;
  const SetupScreen({super.key, required this.onConfigured});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _workspaceController = TextEditingController();
  bool _loading = false;
  String? _error;
  _AuthMode _mode = _AuthMode.google;

  // Web client ID (configured in Plane as GOOGLE_CLIENT_ID) — used as serverClientId
  static const _googleServerClientId =
      '1092552998540-1mlkoklku76kk6e6s36au5fk8sgimque.apps.googleusercontent.com';

  @override
  void dispose() {
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _apiKeyController.dispose();
    _workspaceController.dispose();
    super.dispose();
  }

  String _normalizeUrl(String url) => url.trim().replaceAll(RegExp(r'/$'), '');

  // ─── Google Sign In ───
  Future<void> _signInWithGoogle() async {
    final url = _normalizeUrl(_urlController.text);
    if (url.isEmpty) {
      setState(() => _error = 'Enter the instance URL first');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(serverClientId: _googleServerClientId);

      GoogleSignInAccount? account;
      try {
        account = await googleSignIn.authenticate(
          scopeHint: ['email', 'profile'],
        );
      } on GoogleSignInException catch (e) {
        setState(() { _error = 'Google error: ${e.code} - ${e.description}'; _loading = false; });
        return;
      }

      final idToken = account.authentication.idToken;
      if (idToken == null) {
        setState(() { _error = 'Failed to get Google ID token'; _loading = false; });
        return;
      }

      // Send idToken to our mobile auth endpoint
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      final response = await dio.post(
        '$url/auth/mobile/google-auth/',
        data: {'credential': idToken},
      );

      if (response.statusCode == 200 && response.data['api_token'] != null) {
        await _handleAuthSuccess(url, response.data);
      } else {
        setState(() {
          _error = response.data['error'] ?? 'Authentication failed';
          _loading = false;
        });
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.message ?? 'Connection failed';
      if (e.response?.statusCode == 404 || e.response?.statusCode == 501) {
        setState(() { _error = 'Google login not available on this instance. Try email/password or API key.'; _loading = false; });
      } else {
        setState(() { _error = msg.toString(); _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Google sign-in failed: $e'; _loading = false; });
    }
  }

  // ─── Email/Password Sign In ───
  Future<void> _signInWithEmail() async {
    final url = _normalizeUrl(_urlController.text);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (url.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      final response = await dio.post(
        '$url/auth/mobile/password-auth/',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200 && response.data['api_token'] != null) {
        await _handleAuthSuccess(url, response.data);
      } else {
        setState(() {
          _error = response.data['error'] ?? 'Authentication failed';
          _loading = false;
        });
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.message ?? 'Connection failed';
      setState(() { _error = msg.toString(); _loading = false; });
    } catch (e) {
      setState(() { _error = 'Connection failed: $e'; _loading = false; });
    }
  }

  // ─── API Key ───
  Future<void> _connectWithApiKey() async {
    final url = _normalizeUrl(_urlController.text);
    final apiKey = _apiKeyController.text.trim();
    final workspace = _workspaceController.text.trim();

    if (url.isEmpty || apiKey.isEmpty || workspace.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final ok = await AuthService.testConnection(url, apiKey);
      if (!ok) {
        setState(() { _error = 'Could not connect. Check URL and API key.'; _loading = false; });
        return;
      }

      await SecureStorage.saveBaseUrl(url);
      await SecureStorage.saveApiKey(apiKey);
      await SecureStorage.saveWorkspaceSlug(workspace);
      await SecureStorage.saveAuthMethod('api_key');
      ApiClient.reset();
      widget.onConfigured();
    } catch (e) {
      setState(() { _error = 'Connection failed: $e'; _loading = false; });
    }
  }

  // ─── Shared ───
  Future<void> _handleAuthSuccess(String url, Map<String, dynamic> data) async {
    final apiToken = data['api_token'] as String;
    final workspaces = (data['workspaces'] as List?) ?? [];

    await SecureStorage.saveBaseUrl(url);
    await SecureStorage.saveApiKey(apiToken);
    await SecureStorage.saveAuthMethod('api_key');
    ApiClient.reset();

    if (workspaces.isEmpty) {
      setState(() { _error = 'No workspaces found.'; _loading = false; });
      return;
    }

    if (workspaces.length == 1) {
      await SecureStorage.saveWorkspaceSlug(workspaces[0]['slug'] as String);
      ApiClient.reset();
      setState(() => _loading = false);
      widget.onConfigured();
    } else {
      setState(() => _loading = false);
      final selected = await _showWorkspacePicker(
        workspaces.map((w) => w as Map<String, dynamic>).toList(),
      );
      if (selected != null) {
        await SecureStorage.saveWorkspaceSlug(selected);
        ApiClient.reset();
        widget.onConfigured();
      }
    }
  }

  Future<String?> _showWorkspacePicker(List<Map<String, dynamic>> workspaces) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select Workspace',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            ...workspaces.map((ws) {
              final name = ws['name'] as String? ?? '';
              final slug = ws['slug'] as String? ?? '';
              return ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.15),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.w600)),
                ),
                title: Text(name, style: const TextStyle(fontSize: 15)),
                subtitle: Text(slug, style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                onTap: () => Navigator.pop(ctx, slug),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Icon(Icons.flight_takeoff, size: 64, color: theme.colorScheme.onSurface),
              const SizedBox(height: 16),
              const Text('Plane', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Connect to your self-hosted instance', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 32),

              // Instance URL
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Instance URL',
                  hintText: 'https://plane.example.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),

              // Google Sign In (primary)
              if (_mode == _AuthMode.google) ...[
                OutlinedButton.icon(
                  onPressed: _loading ? null : _signInWithGoogle,
                  icon: _loading
                      ? const M3ELoadingIndicator(size: 18)
                      : const Icon(Icons.g_mobiledata, size: 24),
                  label: Text(_loading ? 'Signing in...' : 'Sign in with Google',
                      style: const TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(M3EShape.full)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.colorScheme.outline)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: theme.colorScheme.outline)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => setState(() { _mode = _AuthMode.emailPassword; _error = null; }),
                      child: const Text('Email / Password'),
                    ),
                    Text('  |  ', style: TextStyle(color: theme.colorScheme.outline)),
                    TextButton(
                      onPressed: () => setState(() { _mode = _AuthMode.apiKey; _error = null; }),
                      child: const Text('API Key'),
                    ),
                  ],
                ),
              ],

              // Email/Password
              if (_mode == _AuthMode.emailPassword) ...[
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _signInWithEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(M3EShape.full)),
                  ),
                  child: _loading
                      ? const M3ELoadingIndicator(size: 20, color: Colors.white)
                      : const Text('Sign In', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => setState(() { _mode = _AuthMode.google; _error = null; }),
                      child: const Text('Google'),
                    ),
                    Text('  |  ', style: TextStyle(color: theme.colorScheme.outline)),
                    TextButton(
                      onPressed: () => setState(() { _mode = _AuthMode.apiKey; _error = null; }),
                      child: const Text('API Key'),
                    ),
                  ],
                ),
              ],

              // API Key
              if (_mode == _AuthMode.apiKey) ...[
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API Key', hintText: 'plane_api_...', border: OutlineInputBorder(), prefixIcon: Icon(Icons.key)),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _workspaceController,
                  decoration: const InputDecoration(
                    labelText: 'Workspace slug', hintText: 'my-workspace', border: OutlineInputBorder(), prefixIcon: Icon(Icons.workspaces)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _connectWithApiKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(M3EShape.full)),
                  ),
                  child: _loading
                      ? const M3ELoadingIndicator(size: 20, color: Colors.white)
                      : const Text('Connect', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => setState(() { _mode = _AuthMode.google; _error = null; }),
                      child: const Text('Google'),
                    ),
                    Text('  |  ', style: TextStyle(color: theme.colorScheme.outline)),
                    TextButton(
                      onPressed: () => setState(() { _mode = _AuthMode.emailPassword; _error = null; }),
                      child: const Text('Email / Password'),
                    ),
                  ],
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _AuthMode { google, emailPassword, apiKey }
