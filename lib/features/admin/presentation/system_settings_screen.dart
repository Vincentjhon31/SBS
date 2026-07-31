import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/glossy_background.dart';
import '../data/admin_providers.dart';

/// Superadmin-only: edit policy text that used to be hardcoded in
/// AppConstants — no code change/release needed for wording tweaks.
class SystemSettingsScreen extends ConsumerWidget {
  const SystemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('System Settings')),
      body: GlossyBackground(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: switch (settings) {
              AsyncData(:final value) => _SettingsForm(settings: value),
              AsyncError(:final error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load settings.\n$error'),
                ),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ),
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
  void dispose() {
    _versionController.dispose();
    _liabilityController.dispose();
    _dataPolicyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.setAppSetting(
        'liability_terms_version',
        _versionController.text.trim(),
      );
      await repo.setAppSetting('liability_terms', _liabilityController.text.trim());
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bump the version whenever you change the liability terms\' '
            'wording — past evidence captures keep the version they were '
            'shown, so old records stay accurate.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _versionController,
            decoration: const InputDecoration(labelText: 'Liability terms version'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _liabilityController,
            decoration: const InputDecoration(labelText: 'Liability terms text'),
            maxLines: 5,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _dataPolicyController,
            decoration: const InputDecoration(labelText: 'Data policy statement'),
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save settings'),
          ),
        ],
      ),
    );
  }
}
