import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';
import '../../widgets/m3e/loading_indicator.dart';
import '../../widgets/m3e/text_field.dart';
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
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final scheme = theme.colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Select Workspace', style: theme.textTheme.titleLarge),
              ),
              const Divider(height: 1, thickness: 0.5),
              ...workspaces.map((ws) {
                final name = ws['name'] as String? ?? '';
                final slug = ws['slug'] as String? ?? '';
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: scheme.primary.withValues(alpha: 0.15),
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: scheme.primary)),
                  ),
                  title: Text(name, style: theme.textTheme.titleMedium),
                  subtitle: Text(slug,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  onTap: () => Navigator.pop(ctx, slug),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // One corner token and one border weight for every control on this screen.
    // The URL field and the Google button used to disagree on both, which is
    // what made the form read as two unrelated pieces of UI.
    final controlShape = M3EShape.border(M3EShape.large);
    final controlSide = BorderSide(color: scheme.outlineVariant, width: 0.8);

    // Filled actions take the container roles, not primary/onPrimary. In the
    // dark scheme `primary` is the pale tone meant to be drawn *on* a dark
    // surface — using it as a fill painted a near-white slab across the screen.
    final ButtonStyle filledStyle = FilledButton.styleFrom(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: controlShape,
    );

    final ButtonStyle outlinedStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      side: controlSide,
      shape: controlShape,
    );

    Widget modeSwitch(List<(String, _AuthMode)> options) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0)
                Text('  |  ',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              TextButton(
                onPressed: () => setState(() {
                  _mode = options[i].$2;
                  _error = null;
                }),
                child: Text(options[i].$1),
              ),
            ],
          ],
        );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Icon(Icons.flight_takeoff, size: 64, color: scheme.onSurface),
              const SizedBox(height: 16),
              Text('Plane',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text('Connect to your self-hosted instance',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 32),

              // Instance URL
              M3ETextField(
                label: 'Instance URL',
                hint: 'https://plane.example.com',
                controller: _urlController,
                prefixIcon: Icons.link,
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
                  label:
                      Text(_loading ? 'Signing in...' : 'Sign in with Google'),
                  style: outlinedStyle,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Divider(height: 1, thickness: 0.5)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    const Expanded(child: Divider(height: 1, thickness: 0.5)),
                  ],
                ),
                const SizedBox(height: 12),
                modeSwitch(const [
                  ('Email / Password', _AuthMode.emailPassword),
                  ('API Key', _AuthMode.apiKey),
                ]),
              ],

              // Email/Password
              if (_mode == _AuthMode.emailPassword) ...[
                M3ETextField(
                  label: 'Email',
                  controller: _emailController,
                  prefixIcon: Icons.person_outline,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                M3ETextField(
                  label: 'Password',
                  controller: _passwordController,
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _signInWithEmail,
                  style: filledStyle,
                  child: _loading
                      ? M3ELoadingIndicator(
                          size: 20, color: scheme.onPrimaryContainer)
                      : const Text('Sign In'),
                ),
                const SizedBox(height: 12),
                modeSwitch(const [
                  ('Google', _AuthMode.google),
                  ('API Key', _AuthMode.apiKey),
                ]),
              ],

              // API Key
              if (_mode == _AuthMode.apiKey) ...[
                M3ETextField(
                  label: 'API Key',
                  hint: 'plane_api_...',
                  controller: _apiKeyController,
                  prefixIcon: Icons.key,
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                M3ETextField(
                  label: 'Workspace slug',
                  hint: 'my-workspace',
                  controller: _workspaceController,
                  prefixIcon: Icons.workspaces,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _connectWithApiKey,
                  style: filledStyle,
                  child: _loading
                      ? M3ELoadingIndicator(
                          size: 20, color: scheme.onPrimaryContainer)
                      : const Text('Connect'),
                ),
                const SizedBox(height: 12),
                modeSwitch(const [
                  ('Google', _AuthMode.google),
                  ('Email / Password', _AuthMode.emailPassword),
                ]),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _AuthMode { google, emailPassword, apiKey }
