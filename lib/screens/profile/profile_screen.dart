import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';
import '../../widgets/m3e/loading_indicator.dart';
import '../../widgets/m3e/app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/loading_state.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final User? user;
  const ProfileScreen({super.key, this.user});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  User? _user;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _nameController =
        TextEditingController(text: _user?.displayName ?? '');
    if (_user == null) _loadUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    try {
      _user = await AuthService.getCurrentUser();
      _nameController.text = _user?.displayName ?? '';
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _saveDisplayName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await AuthService.updateProfile({'display_name': name});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentThemeMode = ref.watch(themeModeProvider);

    if (_loading) {
      return Scaffold(
        appBar: const M3EAppBar(title: 'Profile'),
        body: const LoadingStateWidget(),
      );
    }

    return Scaffold(
      appBar: const M3EAppBar(title: 'Profile'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.2),
              backgroundImage: _user?.avatar != null &&
                      _user!.avatar!.isNotEmpty
                  ? NetworkImage(_user!.avatar!)
                  : null,
              child: _user?.avatar == null || _user!.avatar!.isEmpty
                  ? Text(
                      (_user?.displayName.isNotEmpty == true
                              ? _user!.displayName
                              : '?')[0]
                          .toUpperCase(),
                      style: TextStyle(
                          fontSize: 28,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),

          // Email (read-only)
          if (_user != null) ...[
            Text('Email',
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(M3EShape.large),
                border: Border.all(
                    color: theme.colorScheme.outline, width: 0.5),
                color: theme.colorScheme.surface,
              ),
              child: Text(_user!.email,
                  style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 16),
          ],

          // Display name
          Text('Display name',
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          // The field's name lives in the caption above it, not in the
          // decoration, so the input node itself would be anonymous.
          Semantics(
            label: 'Display name',
            container: true,
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _saveDisplayName,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          M3ELoadingIndicator(size: 18))
                  : const Text('Save'),
            ),
          ),

          // Theme section
          const SizedBox(height: 32),
          Text('Appearance',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 12),
          _ThemeOption(
            icon: Icons.dark_mode,
            label: 'Dark mode',
            selected: currentThemeMode == ThemeMode.dark,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setThemeMode(ThemeMode.dark),
          ),
          _ThemeOption(
            icon: Icons.light_mode,
            label: 'Light mode',
            selected: currentThemeMode == ThemeMode.light,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setThemeMode(ThemeMode.light),
          ),
          _ThemeOption(
            icon: Icons.phone_android,
            label: 'System',
            selected: currentThemeMode == ThemeMode.system,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setThemeMode(ThemeMode.system),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ListTile's own `selected` flag repaints the row in the selection colour,
    // so the active state is annotated instead of switched on. MergeSemantics
    // folds the flag onto the same node as the title, which is what automation
    // and screen readers read.
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, size: 20),
          title: Text(label, style: const TextStyle(fontSize: 14)),
          trailing:
              selected ? const Icon(Icons.check, size: 18) : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
