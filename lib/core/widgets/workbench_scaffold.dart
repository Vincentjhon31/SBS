import 'package:flutter/material.dart';

import 'app_animations.dart';
import 'glossy_background.dart';

/// Layout for the staff "do a task" screens — reviewing a request,
/// releasing or accepting an item, editing an item.
///
/// These all have the same shape: information to read, and decisions to
/// make about it. On a phone that has to be one column. On a laptop,
/// stacking them meant a 640px ribbon down the middle of a 1400px window
/// with the actions pushed below the fold — so past [_twoPaneBreakpoint]
/// the details take the left pane and the actions sit in a panel on the
/// right, each scrolling independently so the buttons stay put however
/// long the details run.
class WorkbenchScaffold extends StatelessWidget {
  const WorkbenchScaffold({
    super.key,
    required this.title,
    required this.main,
    required this.side,
    this.subtitle,
    this.appBarActions = const [],
    this.sideWidth = 380,
  });

  final String title;
  final String? subtitle;

  /// The information being acted on.
  final Widget main;

  /// Decisions about it — buttons, confirmations, verification.
  final Widget side;

  final List<Widget> appBarActions;
  final double sideWidth;

  static const _twoPaneBreakpoint = 1040.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title),
            if (subtitle != null)
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: appBarActions,
      ),
      body: GlossyBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < _twoPaneBreakpoint) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          main.fadeUp(),
                          const SizedBox(height: 24),
                          side.fadeUp(
                            delay: const Duration(milliseconds: 90),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 20, 12, 40),
                          child: main.fadeUp(),
                        ),
                      ),
                      SizedBox(
                        width: sideWidth,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 20, 24, 40),
                          child: side.fadeUp(
                            delay: const Duration(milliseconds: 90),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Bordered surface used for every block inside a [WorkbenchScaffold],
/// so the panes read as a set of related cards rather than loose text.
class WorkbenchCard extends StatelessWidget {
  const WorkbenchCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.accent,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Color? accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = accent ?? scheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 17, color: tint),
                  const SizedBox(width: 9),
                ],
                Text(
                  title!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// Label/value pair used throughout the workbench panes.
class WorkbenchField extends StatelessWidget {
  const WorkbenchField({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueStyle,
  });

  final String label;
  final String value;
  final IconData? icon;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style:
                      valueStyle ??
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
