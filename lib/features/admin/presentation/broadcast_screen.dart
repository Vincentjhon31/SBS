import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_animations.dart';
import '../data/admin_providers.dart';
import 'admin_page.dart';

const _accent = Color(0xFFC2185B);

/// Ready-made openers for the announcements staff actually send, so the
/// common case is two taps instead of composing from scratch.
const _templates = <(String, String, String)>[
  (
    'Office closed',
    'Office closed',
    'The LGU office is closed today. Pickups and returns resume on the '
        'next working day.',
  ),
  (
    'Schedule change',
    'Pickup hours changed',
    'Pickup and return hours have changed. Please check with the office '
        'before heading over.',
  ),
  (
    'Return reminder',
    'Please return borrowed items',
    'If you are still holding an LGU item, please return it as soon as '
        'possible so others can book it.',
  ),
];

/// Staff-only broadcast: one notification to every active citizen,
/// delivered through the same table as approvals and reminders, so it
/// arrives as the in-app modal and a push notification.
class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key});

  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Keeps the live preview in step with what is being typed.
    _titleController.addListener(_onChanged);
    _bodyController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.campaign_outlined, color: _accent),
        title: const Text('Send to every citizen?'),
        content: Text(
          'Every registered citizen will get this as a notification:\n\n'
          '"${_titleController.text.trim()}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .broadcastAnnouncement(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
          );
      _titleController.clear();
      _bodyController.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Announcement sent to all citizens.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not send the announcement.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasContent =
        _titleController.text.trim().isNotEmpty ||
        _bodyController.text.trim().isNotEmpty;

    return AdminPage(
      icon: Icons.campaign_outlined,
      title: 'Announcements',
      subtitle: 'Send one notification to every citizen at once.',
      accent: _accent,
      maxWidth: 760,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'START FROM A TEMPLATE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ).fadeUp(),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, title, body) in _templates)
                    ActionChip(
                      avatar: const Icon(Icons.bolt_outlined, size: 16),
                      label: Text(label),
                      onPressed: _sending
                          ? null
                          : () {
                              _titleController.text = title;
                              _bodyController.text = body;
                            },
                    ),
                ],
              ).fadeUp(delay: const Duration(milliseconds: 60)),
              const SizedBox(height: 26),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title),
                  helperText: 'Shown in bold at the top of the notification',
                ),
                maxLength: 60,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
              ).fadeUp(delay: const Duration(milliseconds: 110)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                maxLength: 300,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a message' : null,
              ).fadeUp(delay: const Duration(milliseconds: 160)),
              const SizedBox(height: 20),
              // A broadcast cannot be recalled, so showing exactly what
              // lands on every citizen's phone before sending matters more
              // here than on an ordinary form.
              _Preview(
                title: _titleController.text.trim(),
                body: _bodyController.text.trim(),
                empty: !hasContent,
              ).fadeUp(delay: const Duration(milliseconds: 210)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(backgroundColor: _accent),
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined, size: 18),
                label: Text(
                  _sending ? 'Sending…' : 'Send to all citizens',
                ),
              ).fadeUp(delay: const Duration(milliseconds: 260)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'This cannot be undone or recalled once sent.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ).fadeUp(delay: const Duration(milliseconds: 300)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mock of the notification modal citizens will actually see.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.title,
    required this.body,
    required this.empty,
  });

  final String title;
  final String body;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PREVIEW',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.campaign_outlined,
                  size: 28,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                empty ? 'Your title appears here' : title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: empty ? scheme.onSurfaceVariant : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                empty ? 'And your message appears here.' : body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
