import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/m3e/shapes.dart';
import '../../models/user.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/bottom_sheet_picker.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/loading_indicator.dart';
import '../../widgets/m3e/text_field.dart';
import '../../widgets/plane_row.dart';
import '../../widgets/section_header.dart';

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
      // [SectionHeader] and [PlaneRow] carry their own inset, so the page
      // margin is applied per block rather than to the whole list.
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
                      // Was `headlineLarge`, the largest type on the screen,
                      // spent on a decorative letter while the one real
                      // heading below it was smaller. Emphasis belongs to
                      // content.
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: theme.colorScheme.primary),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),

          _inset(Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Email (read-only)
              if (_user != null) ...[
                Text('Email', style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                // Read-only, but it sits in the same form as the editable field
                // below, so it borrows that field's outline, corner and fill
                // rather than inventing a third box treatment.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(M3EShape.large),
                    border: Border.all(
                        color: theme.colorScheme.outlineVariant, width: 0.8),
                    color: theme.colorScheme.surfaceContainerLow,
                  ),
                  child: Text(_user!.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
                const SizedBox(height: 16),
              ],

              // The caption above is gone: M3ETextField publishes its own
              // visible label and semantics, so a second copy would read twice.
              M3ETextField(
                label: 'Display name',
                controller: _nameController,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _saveDisplayName,
                child: _saving
                    // Box matches the indicator: at 16 it clipped an 18dp shape.
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: M3ELoadingIndicator(size: 18))
                    : const Text('Save'),
              ),
            ],
          )),

          const SectionHeader(label: 'Appearance'),
          // One row opening the shared picker, rather than three inline options
          // whose only expression of the active one was an 18dp untinted check
          // — a *third* check treatment in an app that had two already. The
          // picker marks selection with a stepped surface, a tighter corner and
          // a tinted check, which is what every other single choice in the app
          // now looks like.
          PlaneRow(
            icon: _themeIcon(currentThemeMode),
            title: 'Theme',
            subtitle: _themeLabel(currentThemeMode),
            semanticLabel: 'Theme, ${_themeLabel(currentThemeMode)}',
            onTap: () => _pickThemeMode(currentThemeMode),
          ),
        ],
      ),
    );
  }

  /// The page margin, for the blocks that are not full-bleed rows or headers.
  Widget _inset(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

  Future<void> _pickThemeMode(ThemeMode current) async {
    final picked = await BottomSheetPicker.show<ThemeMode>(
      context: context,
      title: 'Theme',
      selectedValue: current,
      items: const [
        BottomSheetPickerItem<ThemeMode>(
          value: ThemeMode.dark,
          label: 'Dark',
          icon: Icons.dark_mode,
        ),
        BottomSheetPickerItem<ThemeMode>(
          value: ThemeMode.light,
          label: 'Light',
          icon: Icons.light_mode,
        ),
        BottomSheetPickerItem<ThemeMode>(
          value: ThemeMode.system,
          label: 'System',
          subtitle: 'Follow the device setting',
          icon: Icons.phone_android,
        ),
      ],
    );
    if (picked == null || !mounted) return;
    ref.read(themeModeProvider.notifier).setThemeMode(picked);
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'Dark',
        ThemeMode.light => 'Light',
        ThemeMode.system => 'System',
      };

  static IconData _themeIcon(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => Icons.dark_mode,
        ThemeMode.light => Icons.light_mode,
        ThemeMode.system => Icons.phone_android,
      };
}
