import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/text_field.dart';
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
      final launched =
          await launchUrl(url, mode: LaunchMode.externalApplication);
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
      appBar: M3EAppBar(
        title: 'Sign In',
        leading: M3EAppBarAction(
          icon: Icons.close,
          tooltip: 'Cancel',
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
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Icon(Icons.open_in_browser, size: 48, color: scheme.primary),
        const SizedBox(height: 24),
        Text(
          'Sign in via Browser',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'Google blocks sign-in from embedded browsers. '
          'We\'ll open your Plane instance in Chrome where Google sign-in works normally.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          'After signing in, you\'ll create an API token and paste it here.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        _buildStepItem(theme, 1, 'Sign in to Plane in your browser'),
        _buildStepItem(theme, 2, 'Go to Profile > API Tokens'),
        _buildStepItem(theme, 3, 'Create a new token and copy it'),
        _buildStepItem(theme, 4, 'Return here and paste the token'),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _openBrowser,
          icon: const Icon(Icons.open_in_browser),
          label: const Text('Open Plane in Browser'),
          style: _filledStyle(scheme),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _step = _LoginStep.tokenEntry),
          child: Text(
            'I already have a token',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
        ],
      ],
    );
  }

  /// Filled actions take the container roles rather than primary/onPrimary:
  /// in the dark scheme `primary` is the pale tone meant to sit *on* a dark
  /// surface, so using it as a fill paints a near-white slab.
  ButtonStyle _filledStyle(ColorScheme scheme) => FilledButton.styleFrom(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: M3EShape.border(M3EShape.large),
      );

  /// Same corner token and border weight as [M3ETextField], so a field and a
  /// button stacked on this screen read as one control family.
  ButtonStyle _outlinedStyle(ColorScheme scheme) => OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: scheme.outlineVariant, width: 0.8),
        shape: M3EShape.border(M3EShape.large),
      );

  Widget _buildTokenEntryStep(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Icon(Icons.key, size: 48, color: scheme.primary),
        const SizedBox(height: 24),
        Text(
          'Paste API Token',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'If you haven\'t created a token yet, tap the button below to '
          'open the API tokens page in your browser.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _openApiTokenPage,
          icon: const Icon(Icons.open_in_browser, size: 18),
          label: const Text('Open API Tokens Page'),
          style: _outlinedStyle(scheme),
        ),
        const SizedBox(height: 24),
        M3ETextField(
          label: 'API Token',
          hint: 'Paste your token here',
          controller: _tokenController,
          prefixIcon: Icons.key,
          obscureText: true,
          // The tooltip is also the accessible name, so it spells out what is
          // pasted — "Paste" alone collides with the platform's own menu item.
          suffix: M3EIconButton(
            icon: Icons.paste,
            tooltip: 'Paste API token from clipboard',
            size: M3EIconButtonSize.small,
            onPressed: _pasteFromClipboard,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _submitToken,
          style: _filledStyle(scheme),
          child: const Text('Connect'),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _step = _LoginStep.instructions),
          child: Text(
            'Back to instructions',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
        ],
      ],
    );
  }

  Widget _buildStepItem(ThemeData theme, int number, String text) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              '$number',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

enum _LoginStep { instructions, tokenEntry }
