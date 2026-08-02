import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/glossy_background.dart';

/// Shared chrome for Sign in and Register.
///
/// On a phone this is what it always was: the form, centred, on the blob
/// backdrop. On a desktop browser — where a 400px form marooned in the
/// middle of a 1440px window looks unfinished — it becomes a split view
/// with a branded panel on the left and the form on the right.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.panelPoints,
    this.onBack,
  });

  /// Heading above the form, e.g. "Welcome back".
  final String title;
  final String subtitle;
  final Widget form;

  /// Bullets shown on the branded panel — what this side of the app is
  /// for. Kept short; this is reassurance, not documentation.
  final List<(IconData, String)> panelPoints;

  /// Shown as a back arrow above the heading when set.
  final VoidCallback? onBack;

  /// Below this the branded panel is dropped entirely rather than
  /// squeezed — on a phone it would just push the form off-screen.
  static const _splitBreakpoint = 980.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlossyBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final split = constraints.maxWidth >= _splitBreakpoint;
              final formSide = _FormSide(
                title: title,
                subtitle: subtitle,
                form: form,
                onBack: onBack,
                showLogo: !split,
              );
              if (!split) return formSide;
              return Row(
                children: [
                  Expanded(child: _BrandPanel(points: panelPoints)),
                  Expanded(child: formSide),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Inline error strip used by both auth forms. Shown next to the fields
/// rather than as a SnackBar: on a wide desktop window a bar pinned to
/// the bottom of the viewport is far from the form it refers to.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled group of form fields — keeps the long registration form
/// from reading as one undifferentiated stack of inputs.
class AuthFieldGroup extends StatelessWidget {
  const AuthFieldGroup({
    super.key,
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _FormSide extends StatelessWidget {
  const _FormSide({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.onBack,
    required this.showLogo,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final VoidCallback? onBack;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onBack != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                  ),
                ),
              if (showLogo) ...[
                const Center(child: AppLogoBadge(size: 84)).popIn(),
                const SizedBox(height: 22),
              ],
              Text(
                title,
                textAlign: showLogo ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ).fadeUp(delay: const Duration(milliseconds: 60)),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: showLogo ? TextAlign.center : TextAlign.start,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ).fadeUp(delay: const Duration(milliseconds: 110)),
              const SizedBox(height: 28),
              form.fadeUp(delay: const Duration(milliseconds: 160)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The left half on desktop: logo, positioning line, and a few short
/// reassurances. Deliberately flat colour rather than another blob field —
/// two competing decorated surfaces side by side reads as noise.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.points});

  final List<(IconData, String)> points;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 12, 24),
      padding: const EdgeInsets.all(44),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF111A27), const Color(0xFF0B1017)]
              : [const Color(0xFF1B2A44), const Color(0xFF16324F)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Image.asset(AppConstants.logoAsset, height: 34),
              ),
              const SizedBox(width: 12),
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ).fadeUp(),
          const SizedBox(height: 30),
          Text(
            'Reserve and borrow\nLGU property online.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ).fadeUp(delay: const Duration(milliseconds: 80)),
          const SizedBox(height: 14),
          Text(
            AppConstants.appFullName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 14,
              height: 1.6,
            ),
          ).fadeUp(delay: const Duration(milliseconds: 130)),
          const SizedBox(height: 38),
          for (var i = 0; i < points.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      points[i].$1,
                      size: 17,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(
                        points[i].$2,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).fadeUp(delay: Duration(milliseconds: 190 + i * 70)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.landing),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.75),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to the website'),
          ).fadeUp(delay: const Duration(milliseconds: 420)),
        ],
      ),
    );
  }
}
