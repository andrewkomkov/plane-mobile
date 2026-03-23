import 'package:flutter/material.dart';
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
  final _apiKeyController = TextEditingController();
  final _workspaceController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    _workspaceController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim().replaceAll(RegExp(r'/$'), '');
    final apiKey = _apiKeyController.text.trim();
    final workspace = _workspaceController.text.trim();

    if (url.isEmpty || apiKey.isEmpty || workspace.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ok = await AuthService.testConnection(url, apiKey);
      if (!ok) {
        setState(() {
          _error = 'Could not connect. Check URL and API key.';
          _loading = false;
        });
        return;
      }

      await SecureStorage.saveBaseUrl(url);
      await SecureStorage.saveApiKey(apiKey);
      await SecureStorage.saveWorkspaceSlug(workspace);
      ApiClient.reset();

      widget.onConfigured();
    } catch (e) {
      setState(() {
        _error = 'Connection failed: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.flight_takeoff, size: 64, color: Colors.black87),
              const SizedBox(height: 16),
              const Text(
                'Plane',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect to your self-hosted instance',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
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
              const SizedBox(height: 16),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'plane_api_...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _workspaceController,
                decoration: const InputDecoration(
                  labelText: 'Workspace slug',
                  hintText: 'my-workspace',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.workspaces),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _connect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Connect', style: TextStyle(fontSize: 16)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
