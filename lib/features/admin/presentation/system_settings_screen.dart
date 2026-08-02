import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_animations.dart';
import '../data/admin_providers.dart';
import 'admin_page.dart';

const _accent = Color(0xFF8D6E63);

/// Superadmin-only: policy text that used to be hardcoded in
/// AppConstants, so wording changes no longer need a code change and a
/// new release.
class SystemSettingsScreen extends ConsumerWidget {
  const SystemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return AdminPage(
      icon: Icons.settings_suggest_outlined,
      title: 'System Settings',
      subtitle: 'Edit the liability terms and data policy shown to users.',
      accent: _accent,
      maxWidth: 720,
      child: switch (settings) {
        AsyncData(:final value) => _SettingsForm(settings: value),
        AsyncError(:final error) => AdminEmptyState(
          icon: Icons.error_outline,
          title: 'Could not load settings',
          hint: '$error',
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings});

  final Map<String, String> settings;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final _versionController = TextEditingController(
    text: widget.settings['liability_terms_version'],
  );
  late final _liabilityController = TextEditingController(
    text: widget.settings['liability_terms'],
  );
  late final _dataPolicyController = TextEditingController(
    text: widget.settings['data_policy_statement'],
  );
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _versionController,
      _liabilityController,
      _dataPolicyController,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _versionController.dispose();
    _liabilityController.dispose();
    _dataPolicyController.dispose();
    super.dispose();
  }

  /// Nothing to save until something actually differs — keeps the button
  /// honest rather than always inviting a no-op write to the audit log.
  bool get _dirty =>
      _versionController.text != (widget.settings['liability_terms_version'] ?? '') ||
      _liabilityController.text != (widget.settings['liability_terms'] ?? '') ||
      _dataPolicyController.text !=
          (widget.settings['data_policy_statement'] ?? '');

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.setAppSetting(
        'liability_terms_version',
        _versionController.text.trim(),
      );
      await repo.setAppSetting(
        'liability_terms',
        _liabilityController.text.trim(),
      );
      await repo.setAppSetting(
        'data_policy_statement',
        _dataPolicyController.text.trim(),
      );
      ref.invalidate(appSettingsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Settings saved.')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save settings.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsSection(
            icon: Icons.gavel_outlined,
            title: 'Liability terms',
            description:
                'Read and acknowledged by the borrower at handoff. Bump the '
                'version whenever the wording changes — past evidence '
                'records keep the version they were shown, so old records '
                'stay accurate.',
            children: [
              TextField(
                controller: _versionController,
                decoration: const InputDecoration(
                  labelText: 'Version',
                  prefixIcon: Icon(Icons.numbers),
                  hintText: 'v1',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _liabilityController,
                decoration: const InputDecoration(
                  labelText: 'Terms text',
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
              ),
            ],
          ).fadeUp(),
          const SizedBox(height: 20),
          _SettingsSection(
            icon: Icons.privacy_tip_outlined,
            title: 'Data policy statement',
            description:
                'Shown on the Privacy Policy screen to every user.',
            children: [
              TextField(
                controller: _dataPolicyController,
                decoration: const InputDecoration(
                  labelText: 'Statement',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
              ),
            ],
          ).fadeUp(delay: const Duration(milliseconds: 70)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving || !_dirty ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: _accent),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(
              _saving
                  ? 'Saving…'
                  : _dirty
                  ? 'Save changes'
                  : 'No changes to save',
            ),
          ).fadeUp(delay: const Duration(milliseconds: 130)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Every edit is recorded in the Activity Log.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ).fadeUp(delay: const Duration(milliseconds: 170)),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdminCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: _accent),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}
