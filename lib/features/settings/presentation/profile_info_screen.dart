import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/glossy_background.dart';
import '../../auth/data/auth_providers.dart';
import '../data/settings_providers.dart';

/// Name, email, and (citizens only) phone/address — the "who you are"
/// half of account management, separate from Security (credentials) and
/// Settings (appearance).
class ProfileInfoScreen extends ConsumerStatefulWidget {
  const ProfileInfoScreen({super.key});

  @override
  ConsumerState<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends ConsumerState<ProfileInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _loadOnce(String fullName, String? contactNumber, String? address) {
    if (_loaded) return;
    _loaded = true;
    _nameController.text = fullName;
    _contactController.text = contactNumber ?? '';
    _addressController.text = address ?? '';
  }

  Future<void> _save({required bool isCitizen}) async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.updateFullName(_nameController.text);
      if (isCitizen) {
        await repo.updateCitizenContactInfo(
          contactNumber: _contactController.text,
          address: _addressController.text,
        );
      }
      ref.invalidate(myProfileProvider);
      ref.invalidate(myProfileInfoProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update profile.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).value;
    final isCitizen = profile != null && !profile.isStaff;
    final info = isCitizen ? ref.watch(myProfileInfoProvider) : null;
    final email = ref.read(supabaseClientProvider).auth.currentUser?.email;

    if (profile != null) {
      _loadOnce(
        profile.fullName,
        info?.value?.contactNumber,
        info?.value?.address,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Profile Information')),
      body: GlossyBackground(
        child: SafeArea(
          child: profile == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: email ?? '',
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            helperText: 'Change your email under Security',
                            suffixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        if (isCitizen) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _contactController,
                            decoration: const InputDecoration(
                              labelText: 'Contact number',
                              hintText: '09XX XXX XXXX',
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (v) =>
                                (v == null || v.trim().length < 7)
                                    ? 'Contact number is required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Address (optional)',
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          switch (info!) {
                            AsyncData(:final value?) => Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            value.verified
                                                ? Icons.verified_user
                                                : Icons.gpp_maybe_outlined,
                                            size: 18,
                                            color: value.verified
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            value.verified
                                                ? 'Identity verified'
                                                : 'Identity not yet verified',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelLarge,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${value.idType} • ${value.idNumber}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            _ => const SizedBox.shrink(),
                          },
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed:
                              _saving ? null : () => _save(isCitizen: isCitizen),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save changes'),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
