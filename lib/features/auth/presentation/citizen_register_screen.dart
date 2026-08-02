import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router.dart';
import '../data/auth_providers.dart';
import 'auth_scaffold.dart';

const _idTypes = [
  'PhilSys National ID',
  "Driver's License",
  'Passport',
  "Voter's ID",
  'UMID',
  'Barangay ID',
  'Other government ID',
];

// Shown at registration per the Philippine Data Privacy Act note in the
// development guide; retention specifics are finalized in Phase 9.
const _consentText =
    'I understand that my photo and ID information will be used solely to '
    'verify borrowing transactions with the LGU and will be retained only '
    'for as long as required by the borrowing records policy.';

class CitizenRegisterScreen extends ConsumerStatefulWidget {
  const CitizenRegisterScreen({super.key});

  @override
  ConsumerState<CitizenRegisterScreen> createState() =>
      _CitizenRegisterScreenState();
}

class _CitizenRegisterScreenState extends ConsumerState<CitizenRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contactController = TextEditingController();
  final _idNumberController = TextEditingController();
  String _idType = _idTypes.first;
  XFile? _idPhoto;
  Uint8List? _idPhotoPreview;
  bool _consented = false;
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _contactController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  static final _usernamePattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]{2,19}$');

  String? _validateUsername(String? v) {
    final value = v?.trim() ?? '';
    if (!_usernamePattern.hasMatch(value)) {
      return '3-20 characters, start with a letter (letters, numbers, _)';
    }
    return null;
  }

  Future<void> _pickIdPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo of your ID'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    // Read once here so the card can show a real thumbnail rather than
    // just a "photo added" label.
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _idPhoto = picked;
      _idPhotoPreview = bytes;
    });
  }

  Future<void> _register() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_idPhoto == null) {
      setState(() => _error = 'A photo of your ID is required.');
      return;
    }
    if (!_consented) {
      setState(() => _error = 'Please accept the data privacy notice.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final username = _usernameController.text.trim();
      final available = await ref
          .read(authRepositoryProvider)
          .isUsernameAvailable(username);
      if (!available) {
        if (mounted) {
          setState(() => _error = 'That username is already taken.');
        }
        return;
      }
      await ref
          .read(authRepositoryProvider)
          .registerCitizen(
            username: username,
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
            contactNumber: _contactController.text.trim(),
            idType: _idType,
            idNumber: _idNumberController.text.trim(),
            idPhotoBytes: _idPhotoPreview ?? await _idPhoto!.readAsBytes(),
            idPhotoContentType: _idPhoto!.mimeType ?? 'image/jpeg',
          );
      // Signed in on success; router redirect takes over.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Registration failed. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'No email needed — you will sign in with a username.',
      onBack: () => context.go(AppRoutes.login),
      panelPoints: const [
        (
          Icons.person_outline,
          'Pick a username and password — we do not ask for an email '
              'address.',
        ),
        (
          Icons.badge_outlined,
          'Your ID is checked once, in person, at your first pickup.',
        ),
        (
          Icons.lock_outline,
          'Your details are used only to verify borrowings with the LGU.',
        ),
      ],
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFieldGroup(
              label: 'Your details',
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Enter your full name'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email),
                    helperText: "You'll use this to log in",
                  ),
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  validator: _validateUsername,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    helperText: 'At least 8 characters',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  obscureText: _obscure,
                  validator: (v) => (v == null || v.length < 8)
                      ? 'Password must be at least 8 characters'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Contact number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '09XX XXX XXXX',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 7)
                      ? 'Enter a contact number'
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 28),
            AuthFieldGroup(
              label: 'Identity verification',
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _idType,
                  decoration: const InputDecoration(
                    labelText: 'ID type',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                  ),
                  items: [
                    for (final type in _idTypes)
                      DropdownMenuItem(value: type, child: Text(type)),
                  ],
                  onChanged: (v) => setState(() => _idType = v ?? _idType),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _idNumberController,
                  decoration: const InputDecoration(
                    labelText: 'ID number',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your ID number'
                      : null,
                ),
                const SizedBox(height: 16),
                _IdPhotoField(
                  preview: _idPhotoPreview,
                  onPick: _submitting ? null : _pickIdPhoto,
                  onClear: _submitting
                      ? null
                      : () => setState(() {
                          _idPhoto = null;
                          _idPhotoPreview = null;
                        }),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _ConsentTile(
              value: _consented,
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _consented = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 18),
              AuthErrorBanner(message: _error!),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _submitting ? null : _register,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create account'),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already registered?',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => context.go(AppRoutes.login),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed drop-zone style picker that shows the chosen ID once picked, so
/// the borrower can see the photo is legible before submitting.
class _IdPhotoField extends StatelessWidget {
  const _IdPhotoField({
    required this.preview,
    required this.onPick,
    required this.onClear,
  });

  final Uint8List? preview;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (preview != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.memory(
                preview!,
                width: 64,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 15,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ID photo added',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Make sure the details are readable.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onPick,
              tooltip: 'Replace photo',
              icon: const Icon(Icons.refresh, size: 19),
            ),
            IconButton(
              onPressed: onClear,
              tooltip: 'Remove photo',
              icon: Icon(Icons.close, size: 19, color: scheme.error),
            ),
          ],
        ),
      );
    }
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        ),
        child: Column(
          children: [
            Icon(Icons.add_a_photo_outlined, color: scheme.primary),
            const SizedBox(height: 10),
            Text(
              'Add a photo of your ID',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              'Camera or gallery · JPG or PNG',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value
              ? scheme.primaryContainer.withValues(alpha: 0.35)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          border: Border.all(
            color: value ? scheme.primary.withValues(alpha: 0.5) : scheme.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged == null
                  ? null
                  : (v) => onChanged!(v ?? false),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _consentText,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
