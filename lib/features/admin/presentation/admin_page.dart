import 'package:flutter/material.dart';

import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/glossy_background.dart';

/// Shared chrome for every screen under the sidebar's MANAGE group.
///
/// Before this, each of the six was its own arrangement of AppBar,
/// padding, and loading/empty handling, so moving between them felt like
/// moving between six small apps. This gives them one header (icon,
/// title, one-line purpose, optional actions), one content width, and one
/// set of loading/empty/error states.
class AdminPage extends StatelessWidget {
  const AdminPage({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
    this.actions = const [],
    this.maxWidth = 900,
    this.toolbar,
  });

  final IconData icon;
  final String title;

  /// One line explaining what the screen is for — these are
  /// infrequently-visited admin tools, so a reminder earns its space.
  final String subtitle;

  /// Hue for the header icon chip, matching the card that links here on
  /// the dashboard so the two read as the same destination.
  final Color accent;

  final Widget child;

  /// Buttons pinned to the right of the header.
  final List<Widget> actions;

  /// Optional row directly under the header — search, filters.
  final Widget? toolbar;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // Titleless: the header below already names the screen, and showing
      // it twice wastes the only vertical space these tools have. The bar
      // stays for the back button.
      //
      // The bar keeps the theme's surface colour deliberately — the
      // backdrop is painted inside the body, below the app bar, so a
      // transparent bar has nothing behind it and renders black.
      appBar: AppBar(toolbarHeight: 48),
      body: GlossyBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _AdminHeader(
                      icon: icon,
                      title: title,
                      subtitle: subtitle,
                      accent: accent,
                      actions: actions,
                    ).fadeUp(),
                  ),
                  if (toolbar != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: toolbar!.fadeUp(
                        delay: const Duration(milliseconds: 70),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final identity = Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 23, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        if (actions.isEmpty) return identity;
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: identity),
            const SizedBox(width: 16),
            ...actions,
          ],
        );
      },
    );
  }
}

/// Consistent "nothing here" panel for the admin screens.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    this.action,
  });

  final IconData icon;
  final String title;
  final String hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: scheme.onSurfaceVariant),
            ).popIn(),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ).fadeUp(delay: const Duration(milliseconds: 80)),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ).fadeUp(delay: const Duration(milliseconds: 130)),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!.fadeUp(delay: const Duration(milliseconds: 180)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card surface shared by the admin list rows and form panels.
class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(padding: padding, child: child);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
  }
}
