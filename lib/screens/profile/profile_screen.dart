import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';
import '../../widgets/m3e/loading_indicator.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/text_field.dart';
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
    _nameController = TextEditingController(text: _user?.displayName ?? '');
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated')));
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
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              backgroundImage:
                  _user?.avatar != null && _user!.avatar!.isNotEmpty
                      ? NetworkImage(_user!.avatar!)
                      : null,
              child: _user?.avatar == null || _user!.avatar!.isEmpty
                  ? Text(
                      (_user?.displayName.isNotEmpty == true
                              ? _user!.displayName
                              : '?')[0]
                          .toUpperCase(),
                      style: theme.textTheme.headlineLarge
                          ?.copyWith(color: theme.colorScheme.primary),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),

          // Email (read-only)
          if (_user != null) ...[
            Text('Email', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            // Read-only, but it sits in the same form as the editable field
            // below, so it borrows that field's outline, corner and fill rather
            // than inventing a third box treatment.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(M3EShape.large),
                border: Border.all(
                    color: theme.colorScheme.outlineVariant, width: 0.8),
                color: theme.colorScheme.surfaceContainerLow,
              ),
              child: Text(_user!.email,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 16),
          ],

          // The caption above is gone: M3ETextField publishes its own visible
          // label and semantics, so a second copy would just read twice.
          M3ETextField(
            label: 'Display name',
            controller: _nameController,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _saveDisplayName,
              child: _saving
                  // Box matches the indicator: at 16 it clipped an 18dp shape.
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: M3ELoadingIndicator(size: 18))
                  : const Text('Save'),
            ),
          ),

          // Theme section
          const SizedBox(height: 32),
          Text('Appearance', style: theme.textTheme.titleMedium),
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
          title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          trailing: selected ? const Icon(Icons.check, size: 18) : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
