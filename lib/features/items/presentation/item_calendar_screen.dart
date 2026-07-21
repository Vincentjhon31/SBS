import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../borrowing/data/borrow_models.dart';
import '../../borrowing/data/borrow_providers.dart';
import '../data/items_models.dart';

/// Month calendar marking days with approved/released reservations for one
/// item, plus the list of upcoming windows. Identity-free by design.
class ItemCalendarScreen extends ConsumerStatefulWidget {
  const ItemCalendarScreen({super.key, required this.item});

  final Item item;

  @override
  ConsumerState<ItemCalendarScreen> createState() => _ItemCalendarScreenState();
}

class _ItemCalendarScreenState extends ConsumerState<ItemCalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final windows = ref.watch(reservedWindowsProvider(widget.item.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar — ${widget.item.displayName}'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.items)),
      ),
      body: switch (windows) {
        AsyncData(:final value) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MonthHeader(
                  month: _month,
                  onPrev: () => setState(() =>
                      _month = DateTime(_month.year, _month.month - 1)),
                  onNext: () => setState(() =>
                      _month = DateTime(_month.year, _month.month + 1)),
                ),
                const SizedBox(height: 8),
                _MonthGrid(month: _month, windows: value),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Reserved',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                const Divider(height: 32),
                Text('Upcoming reservations',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (value.isEmpty)
                  const Text('No approved reservations ahead.')
                else
                  for (final w in value)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event),
                      title: Text('${_fmt(w.from)}  →  ${_fmt(w.to)}'),
                    ),
                const SizedBox(height: 8),
                Text(
                  'Reservations shown without borrower details. Pending '
                  'requests are not shown — only approved bookings block '
                  'a window.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        AsyncError() => const Center(child: Text('Could not load calendar.')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  static String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static const _names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Text(
          '${_names[month.month - 1]} ${month.year}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.windows});

  final DateTime month;
  final List<ReservedWindow> windows;

  bool _isReserved(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return windows.any((w) => w.from.isBefore(dayEnd) && w.to.isAfter(dayStart));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first offset for the 1st of the month.
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    final today = DateTime.now();

    return Column(
      children: [
        Row(
          children: [
            for (final d in const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'])
              Expanded(
                child: Center(
                  child: Text(d, style: const TextStyle(fontSize: 11)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++)
              Padding(
                padding: const EdgeInsets.all(3),
                child: _DayCell(
                  day: day,
                  reserved:
                      _isReserved(DateTime(month.year, month.month, day)),
                  isToday: today.year == month.year &&
                      today.month == month.month &&
                      today.day == day,
                  scheme: scheme,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.reserved,
    required this.isToday,
    required this.scheme,
  });

  final int day;
  final bool reserved;
  final bool isToday;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: reserved ? scheme.primaryContainer : null,
        shape: BoxShape.circle,
        border: isToday ? Border.all(color: scheme.primary, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '$day',
        style: TextStyle(
          fontSize: 13,
          fontWeight: reserved ? FontWeight.bold : FontWeight.normal,
          color: reserved ? scheme.onPrimaryContainer : null,
        ),
      ),
    );
  }
}
