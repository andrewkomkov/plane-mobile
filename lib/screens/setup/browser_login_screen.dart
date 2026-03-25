import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the Plane login page in an external browser (Chrome Custom Tab)
/// and guides the user to create and paste an API token.
class BrowserLoginScreen extends StatefulWidget {
  final String baseUrl;

  const BrowserLoginScreen({super.key, required this.baseUrl});

  @override
  State<BrowserLoginScreen> createState() => _BrowserLoginScreenState();
}

class _BrowserLoginScreenState extends State<BrowserLoginScreen>
    with WidgetsBindingObserver {
  final _tokenController = TextEditingController();
  _LoginStep _step = _LoginStep.instructions;
  bool _browserOpened = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tokenController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When user returns from browser, move to token entry step
    if (state == AppLifecycleState.resumed && _browserOpened) {
      setState(() {
        _step = _LoginStep.tokenEntry;
        _browserOpened = false;
      });
    }
  }

  Future<void> _openBrowser() async {
    final url = Uri.parse(widget.baseUrl);
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (launched) {
        setState(() => _browserOpened = true);
      } else {
        setState(() => _error = 'Could not open browser');
      }
    } catch (e) {
      setState(() => _error = 'Could not open browser: $e');
    }
  }

  Future<void> _openApiTokenPage() async {
    final url = Uri.parse('${widget.baseUrl}/profile/api-tokens/');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      setState(() => _browserOpened = true);
    } catch (e) {
      setState(() => _error = 'Could not open browser: $e');
    }
  }

  void _submitToken() {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Please paste your API token');
      return;
    }
    Navigator.pop(context, 'apitoken:$token');
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _tokenController.text = data.text!;
      setState(() => _error = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, null),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _step == _LoginStep.instructions
              ? _buildInstructionsStep(theme)
              : _buildTokenEntryStep(theme),
        ),
      ),
    );
  }

  Widget _buildInstructionsStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Icon(Icons.open_in_browser, size: 48,
            color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        const Text(
          'Sign in via Browser',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Text(
          'Google blocks sign-in from embedded browsers. '
          'We\'ll open your Plane instance in Chrome where Google sign-in works normally.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          'After signing in, you\'ll create an API token and paste it here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        _buildStepItem(1, 'Sign in to Plane in your browser'),
        _buildStepItem(2, 'Go to Profile > API Tokens'),
        _buildStepItem(3, 'Create a new token and copy it'),
        _buildStepItem(4, 'Return here and paste the token'),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _openBrowser,
          icon: const Icon(Icons.open_in_browser),
          label: const Text('Open Plane in Browser', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _step = _LoginStep.tokenEntry),
          child: Text(
            'I already have a token',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  Widget _buildTokenEntryStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Icon(Icons.key, size: 48,
            color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        const Text(
          'Paste API Token',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Text(
          'If you haven\'t created a token yet, tap the button below to '
          'open the API tokens page in your browser.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _openApiTokenPage,
          icon: const Icon(Icons.open_in_browser, size: 18),
          label: const Text('Open API Tokens Page'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _tokenController,
          decoration: InputDecoration(
            labelText: 'API Token',
            hintText: 'Paste your token here',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste),
              tooltip: 'Paste from clipboard',
              onPressed: _pasteFromClipboard,
            ),
          ),
          maxLines: 1,
          obscureText: true,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _submitToken,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Connect', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _step = _LoginStep.instructions),
          child: Text(
            'Back to instructions',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  Widget _buildStepItem(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.black87,
            child: Text(
              '$number',
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

enum _LoginStep { instructions, tokenEntry }
