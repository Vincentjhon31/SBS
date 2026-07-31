import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router.dart';
import '../../../core/widgets/glossy_background.dart';
import '../data/auth_providers.dart';

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
  bool _consented = false;
  bool _submitting = false;

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
    if (picked != null) setState(() => _idPhoto = picked);
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    if (_idPhoto == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('A photo of your ID is required.')),
      );
      return;
    }
    if (!_consented) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please accept the data privacy notice.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final username = _usernameController.text.trim();
      final available = await ref
          .read(authRepositoryProvider)
          .isUsernameAvailable(username);
      if (!available) {
        messenger.showSnackBar(
          const SnackBar(content: Text('That username is already taken.')),
        );
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
            idPhotoBytes: await _idPhoto!.readAsBytes(),
            idPhotoContentType: _idPhoto!.mimeType ?? 'image/jpeg',
          );
      // Signed in on success; router redirect takes over.
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Registration failed. Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Citizen Registration'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.login)),
      ),
      body: GlossyBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().length < 3)
                        ? 'Enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      helperText: "You'll use this to log in — no email needed",
                    ),
                    autocorrect: false,
                    validator: _validateUsername,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      helperText: 'At least 8 characters',
                    ),
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Password must be at least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact number',
                      hintText: '09XX XXX XXXX',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().length < 7)
                        ? 'Enter a contact number'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: _idType,
                    decoration: const InputDecoration(labelText: 'ID type'),
                    items: [
                      for (final type in _idTypes)
                        DropdownMenuItem(value: type, child: Text(type)),
                    ],
                    onChanged: (v) => setState(() => _idType = v ?? _idType),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _idNumberController,
                    decoration: const InputDecoration(labelText: 'ID number'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your ID number'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickIdPhoto,
                    icon: Icon(
                      _idPhoto == null ? Icons.add_a_photo : Icons.check_circle,
                    ),
                    label: Text(
                      _idPhoto == null
                          ? 'Add a photo of your ID'
                          : 'ID photo added',
                    ),
                  ),
                  const SizedBox(height: 24),
                  CheckboxListTile(
                    value: _consented,
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _consented = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _consentText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submitting ? null : _register,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Register'),
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
