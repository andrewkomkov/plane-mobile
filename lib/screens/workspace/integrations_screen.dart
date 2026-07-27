import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/integration_settings_service.dart';
import '../../utils/say.dart';
import '../../utils/time_ago.dart';
import '../../widgets/bottom_sheet_picker.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/text_field.dart';
import '../../widgets/plane_row.dart';
import '../../widgets/section_header.dart';

/// Personal access tokens and workspace webhooks.
///
/// This was the one gap with a sharp edge: the app mints a token for its own
/// sign-in and had no way to show you that it had, let alone revoke it. If a
/// phone is lost, this is the screen that ends its access.
class IntegrationsScreen extends StatefulWidget {
  final String workspaceSlug;

  const IntegrationsScreen({super.key, required this.workspaceSlug});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  List<ApiToken> _tokens = [];
  List<Webhook> _webhooks = [];
  bool _loading = true;
  String? _error;

  /// Set when the caller may not list webhooks — those are admin-only, and a
  /// member seeing an empty list would read it as "there are none".
  bool _webhooksForbidden = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<ApiToken> tokens;
    try {
      tokens = await IntegrationSettingsService.getTokens();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the server';
      });
      return;
    }

    var forbidden = false;
    var webhooks = <Webhook>[];
    try {
      webhooks =
          await IntegrationSettingsService.getWebhooks(widget.workspaceSlug);
    } catch (_) {
      forbidden = true;
    }

    if (!mounted) return;
    setState(() {
      _tokens = tokens;
      _webhooks = webhooks;
      _webhooksForbidden = forbidden;
      _loading = false;
      _error = null;
    });
  }

  // --- Tokens --------------------------------------------------------------

  Future<void> _createToken() async {
    final label = await _promptText(
      title: 'New token',
      label: 'What is it for',
      confirmLabel: 'Create',
    );
    if (label == null || label.isEmpty) return;

    try {
      final token = await IntegrationSettingsService.createToken(label: label);
      if (!mounted) return;
      await _showSecret(
        title: 'Token created',
        // The one moment it is readable. Plane hashes it immediately and the
        // read serialiser never sends it again.
        secret: token.token ?? '',
        note: 'Copy it now. This is the only time it is shown.',
      );
      await _load();
    } catch (_) {
      if (mounted) say(context, 'Could not create the token');
    }
  }

  Future<void> _revokeToken(ApiToken token) async {
    final ok = await confirmDestructive(
      context,
      title: 'Revoke ${token.label}?',
      message: 'Anything signed in with this token stops working immediately, '
          'including this app if it is the one it uses.',
      confirmLabel: 'Revoke',
    );
    if (!ok) return;
    try {
      await IntegrationSettingsService.revokeToken(token.id);
      await _load();
    } catch (_) {
      if (mounted) say(context, 'Could not revoke it');
    }
  }

  // --- Webhooks ------------------------------------------------------------

  Future<void> _createWebhook() async {
    final url = await _promptText(
      title: 'New webhook',
      label: 'URL to POST to',
      confirmLabel: 'Create',
    );
    if (url == null || url.isEmpty) return;

    try {
      final hook = await IntegrationSettingsService.createWebhook(
        widget.workspaceSlug,
        url: url,
      );
      if (!mounted) return;
      await _showSecret(
        title: 'Webhook created',
        secret: hook.secretKey ?? '',
        note: 'Sign your verification against this secret.',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      // Plane resolves the hostname and refuses anything private, loopback,
      // reserved or link-local — a webhook pointing at the instance's own
      // network is rejected rather than silently dropped later. The message
      // is worth passing through, because the reason is not guessable.
      say(context, _serverMessage(e) ?? 'Could not create the webhook');
    }
  }

  Future<void> _toggleWebhook(Webhook hook) async {
    try {
      await IntegrationSettingsService.updateWebhook(
        widget.workspaceSlug,
        hook.id,
        {'is_active': !hook.isActive},
      );
      await _load();
    } catch (_) {
      if (mounted) say(context, 'Could not change it');
    }
  }

  Future<void> _regenerate(Webhook hook) async {
    final ok = await confirmDestructive(
      context,
      title: 'Roll the secret?',
      message: 'Anything verifying signatures against the old secret stops '
          'accepting deliveries until it is updated.',
      confirmLabel: 'Roll it',
    );
    if (!ok) return;
    try {
      final updated = await IntegrationSettingsService.regenerateSecret(
          widget.workspaceSlug, hook.id);
      if (!mounted) return;
      await _showSecret(
        title: 'New secret',
        secret: updated.secretKey ?? '',
        note: 'Update whatever verifies these deliveries.',
      );
      await _load();
    } catch (_) {
      if (mounted) say(context, 'Could not roll the secret');
    }
  }

  Future<void> _deleteWebhook(Webhook hook) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete webhook?',
      message: 'Deliveries to ${hook.url} stop.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    try {
      await IntegrationSettingsService.deleteWebhook(
          widget.workspaceSlug, hook.id);
      await _load();
    } catch (_) {
      if (mounted) say(context, 'Could not delete it');
    }
  }

  // --- Shared --------------------------------------------------------------

  static String? _serverMessage(Object error) {
    final response = (error as dynamic).response?.data;
    if (response is Map) {
      final url = response['url'];
      if (url is List && url.isNotEmpty) return url.first.toString();
      if (response['error'] != null) return response['error'].toString();
    }
    return null;
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    required String confirmLabel,
  }) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: M3ETextField(
          label: label,
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    final text = saved == true ? controller.text.trim() : null;
    controller.dispose();
    return text;
  }

  /// Shows a secret once, with the copy button next to it.
  Future<void> _showSecret({
    required String title,
    required String secret,
    required String note,
  }) async {
    if (secret.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              secret,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
            const SizedBox(height: 12),
            Text(note, style: Theme.of(ctx).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: secret));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const M3EAppBar(title: 'Tokens & webhooks'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ScrollableCenter(
                  child: ErrorStateWidget(message: _error, onRetry: _load),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      const SectionHeader(label: 'Personal access tokens'),
                      for (final t in _tokens) _tokenRow(t),
                      PlaneRow(
                        icon: Icons.add,
                        title: 'New token',
                        semanticLabel: 'Create a personal access token',
                        onTap: _createToken,
                      ),
                      const SectionHeader(label: 'Webhooks'),
                      if (_webhooksForbidden)
                        const PlaneRow(
                          icon: Icons.lock_outline,
                          title: 'Workspace admins only',
                          subtitle:
                              'Plane restricts webhooks to admins, so this '
                              'list cannot be read with your role.',
                          semanticLabel:
                              'Webhooks are restricted to workspace admins',
                        )
                      else ...[
                        for (final w in _webhooks) _webhookRow(w),
                        PlaneRow(
                          icon: Icons.add,
                          title: 'New webhook',
                          semanticLabel: 'Register a webhook',
                          onTap: _createWebhook,
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _tokenRow(ApiToken token) {
    final used = token.lastUsed;
    return PlaneRow(
      icon: Icons.key_outlined,
      title: token.label,
      subtitle:
          used == null ? 'Never used' : 'Last used ${timeAgoShort(used)} ago',
      semanticLabel: 'Token ${token.label}',
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Revoke ${token.label}',
        onPressed: () => _revokeToken(token),
      ),
    );
  }

  Widget _webhookRow(Webhook hook) {
    final events = hook.events;
    return PlaneRow(
      icon: hook.isActive ? Icons.webhook : Icons.webhook_outlined,
      title: hook.url,
      titleMaxLines: 2,
      subtitle: hook.isActive
          ? (events.isEmpty ? 'No events' : events.join(', '))
          : 'Paused',
      semanticLabel: 'Webhook ${hook.url}',
      trailing: IconButton(
        icon: const Icon(Icons.more_horiz),
        tooltip: 'Actions for this webhook',
        onPressed: () async {
          final picked = await BottomSheetPicker.show<String>(
            context: context,
            title: hook.url,
            items: [
              BottomSheetPickerItem(
                value: 'toggle',
                label: hook.isActive ? 'Pause' : 'Resume',
                icon: hook.isActive
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
              const BottomSheetPickerItem(
                value: 'regenerate',
                label: 'Roll the secret',
                icon: Icons.autorenew,
              ),
              const BottomSheetPickerItem(
                value: 'delete',
                label: 'Delete',
                icon: Icons.delete_outline,
                destructive: true,
              ),
            ],
          );
          switch (picked) {
            case 'toggle':
              await _toggleWebhook(hook);
            case 'regenerate':
              await _regenerate(hook);
            case 'delete':
              await _deleteWebhook(hook);
          }
        },
      ),
    );
  }
}
