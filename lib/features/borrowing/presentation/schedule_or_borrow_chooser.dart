import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';

enum _Choice { schedule, borrow }

/// Centered "What do you need?" chooser — reached from the raised center
/// nav button. Picking one navigates into the matching flow-filtered item
/// browsing screen (same underlying request flow either way).
Future<void> showScheduleOrBorrowChooser(BuildContext context) async {
  final choice = await showDialog<_Choice>(
    context: context,
    builder: (context) => const _ScheduleOrBorrowDialog(),
  );
  if (choice == null || !context.mounted) return;
  context.push(
    choice == _Choice.schedule
        ? AppRoutes.scheduleItems
        : AppRoutes.borrowItems,
  );
}

class _ScheduleOrBorrowDialog extends StatelessWidget {
  const _ScheduleOrBorrowDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('What do you need?', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pick one to get started',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.event_outlined,
                  label: 'Schedule',
                  subtitle: 'Venues & vehicles',
                  color: scheme.primaryContainer,
                  onColor: scheme.onPrimaryContainer,
                  onTap: () => Navigator.pop(context, _Choice.schedule),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.handshake_outlined,
                  label: 'Borrow',
                  subtitle: 'Equipment & tools',
                  color: scheme.secondaryContainer,
                  onColor: scheme.onSecondaryContainer,
                  onTap: () => Navigator.pop(context, _Choice.borrow),
                ),
              ),
            ],
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 36, color: onColor),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: onColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
