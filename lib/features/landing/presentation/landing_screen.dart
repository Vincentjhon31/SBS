import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/glossy_background.dart';
import '../../settings/data/app_update_providers.dart';
import '../data/landing_copy.dart';

/// Widest the page content ever gets — text stays readable on a 27"
/// monitor instead of stretching edge to edge.
const _maxContent = 1120.0;

/// Below this the page collapses to a single column (hero art moves under
/// the copy, nav links hide behind the CTA).
const _wide = 940.0;

const _navHeight = 68.0;

/// Section accents. Each section owns one hue used for its eyebrow label,
/// icon chips, and a barely-there background wash — colour as accent
/// rather than full saturated bands, so the page reads as one product.
const _aboutAccent = Color(0xFF2B7FFF);
const _featuresAccent = Color(0xFF3DDC97);
const _stepsAccent = Color(0xFF6750A4);
const _downloadAccent = Color(0xFFE07A1F);

/// The Features band's fixed near-black background — deliberately not tied
/// to the app's light/dark theme (unlike every other section, which washes
/// the ambient surface colour). One bold, always-dark band gives the page
/// the black/white contrast that an all-pastel scroll was missing, and it
/// matches the phone mock's own dark chrome for a visual rhyme.
const _featuresDarkBg = Color(0xFF11151D);

/// White (or near-black in dark mode) nudged [amount] toward [accent] —
/// section washes light enough to sit under body text.
Color _wash(BuildContext context, Color accent, double amount) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Color.lerp(
    dark ? const Color(0xFF0A0D14) : Colors.white,
    accent,
    dark ? amount * 0.5 : amount,
  )!;
}

/// The public welcome page — what a signed-out visitor sees at `/` on the
/// web. Native users never reach it (they land on sign-in). Login and
/// registration are linked from here rather than embedded, so there is
/// still one implementation of each auth form.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollController = ScrollController();
  final _aboutKey = GlobalKey();
  final _featuresKey = GlobalKey();
  final _stepsKey = GlobalKey();
  final _downloadKey = GlobalKey();

  /// Drives the nav bar's fill/shadow — transparent over the hero, solid
  /// once the page scrolls under it.
  bool _navSolid = false;

  /// Page-local language choice. Not persisted — a signed-out visitor
  /// picking Tagalog once per visit is enough; there is no account yet to
  /// remember it against.
  bool _isTagalog = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final solid = _scrollController.offset > 12;
      if (solid != _navSolid) setState(() => _navSolid = solid);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = _isTagalog ? LandingCopy.tl : LandingCopy.en;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // The blob backdrop wraps the scroll view rather than sitting
          // inside it: it lays out with StackFit.expand, which needs the
          // bounded height only the Scaffold body provides. Every section
          // below the hero paints an opaque wash over it, so the blobs
          // read as hero-only artwork.
          GlossyBackground(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  _Hero(copy: copy),
                  _AboutSection(key: _aboutKey, copy: copy),
                  _FeaturesSection(key: _featuresKey, copy: copy),
                  _StepsSection(key: _stepsKey, copy: copy),
                  _DownloadSection(key: _downloadKey, copy: copy),
                  _Footer(copy: copy),
                ],
              ),
            ),
          ),
          // Pinned edge to edge: a bare Stack child would shrink-wrap to
          // its content and strand the nav in the top-left corner.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _NavBar(
              solid: _navSolid,
              copy: copy,
              isTagalog: _isTagalog,
              onToggleLang: () => setState(() => _isTagalog = !_isTagalog),
              onAbout: () => _scrollTo(_aboutKey),
              onFeatures: () => _scrollTo(_featuresKey),
              onSteps: () => _scrollTo(_stepsKey),
              onDownload: () => _scrollTo(_downloadKey),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Navigation
// ─────────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.solid,
    required this.copy,
    required this.isTagalog,
    required this.onToggleLang,
    required this.onAbout,
    required this.onFeatures,
    required this.onSteps,
    required this.onDownload,
  });

  final bool solid;
  final LandingCopy copy;
  final bool isTagalog;
  final VoidCallback onToggleLang;
  final VoidCallback onAbout;
  final VoidCallback onFeatures;
  final VoidCallback onSteps;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final showLinks = MediaQuery.sizeOf(context).width >= _wide;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _navHeight,
      decoration: BoxDecoration(
        // Fully opaque once scrolled: a translucent bar without a backdrop
        // blur just lets the copy underneath show through as noise.
        color: solid
            ? (dark ? const Color(0xFF0A0D14) : Colors.white)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: solid
                ? scheme.outlineVariant.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContent),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Image.asset(AppConstants.logoAsset, width: 32, height: 32),
                const SizedBox(width: 10),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                if (showLinks) ...[
                  _NavLink(label: copy.navAbout, onTap: onAbout),
                  _NavLink(label: copy.navFeatures, onTap: onFeatures),
                  _NavLink(label: copy.navSteps, onTap: onSteps),
                  _NavLink(label: copy.navDownload, onTap: onDownload),
                  const SizedBox(width: 16),
                ],
                _LangToggle(isTagalog: isTagalog, onTap: onToggleLang),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: Text(copy.navSignIn),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.register),
                  // The app-wide filledButtonTheme sets
                  // minimumSize: Size.fromHeight(48) — infinite min width,
                  // which is right for form buttons but stretches these
                  // inline CTAs across the whole column.
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  child: Text(copy.navRegister),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// EN / FIL pill switcher — the one bit of nav chrome that is never itself
/// translated, since it names the two choices rather than describing them.
class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.isTagalog, required this.onTap});

  final bool isTagalog;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: isTagalog ? 'Switch to English' : 'Palitan sa Filipino',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LangPill(label: 'EN', selected: !isTagalog),
              _LangPill(label: 'FIL', selected: isTagalog),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  const _LangPill({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      child: Text(label),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Layout helpers
// ─────────────────────────────────────────────────────────────────────

/// One full-bleed band: optional background wash, content clamped to
/// [_maxContent] and centred. [floaters] paint behind the content,
/// absolutely positioned within the band — decorative only, so they sit
/// under an [IgnorePointer] and never intercept a tap meant for the CTAs
/// above them.
class _Band extends StatelessWidget {
  const _Band({required this.child, this.background, this.floaters = const []});

  final Widget child;
  final Color? background;
  final List<Widget> floaters;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(vertical: 96, horizontal: 24),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (floaters.isNotEmpty)
            // Positioned.fill (not a bare non-positioned child): floaters
            // must resolve against the *band's* actual size, which only
            // the other (non-positioned) child below establishes — a
            // second non-positioned Stack here would collapse to zero
            // size, since every one of its own children is Positioned.
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(clipBehavior: Clip.none, children: floaters),
              ),
            ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContent),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small circular icon chip that drifts gently up and down — the "not
/// too plain" ambient decoration for the hero and the dark features band.
/// Purely decorative: no gesture handling of its own (callers wrap it, and
/// its siblings, in [IgnorePointer]).
class _FloatIcon extends StatelessWidget {
  const _FloatIcon({
    required this.icon,
    required this.color,
    this.size = 52,
    this.iconSize = 22,
    this.duration = const Duration(milliseconds: 2600),
    this.delay = Duration.zero,
    this.onDark = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final Duration duration;
  final Duration delay;

  /// True on the dark Features band, where a translucent-white chip reads
  /// better than the accent-tinted glass used everywhere else.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: onDark ? Colors.white.withValues(alpha: 0.08) : color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: onDark ? Colors.white.withValues(alpha: 0.16) : color.withValues(alpha: 0.32),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.24),
                blurRadius: 28,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Icon(icon, size: iconSize, color: color),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(
          begin: 0,
          end: -14,
          duration: duration,
          delay: delay,
          curve: Curves.easeInOut,
        );
  }
}

/// Small uppercase accent label above a section heading — gives each
/// section an identity without another block of colour.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text, required this.accent, this.center = false});

  final String text;
  final Color accent;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: accent,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.center = true, this.color});

  final String title;
  final bool center;

  /// Overrides the default theme colour — used on the dark Features band,
  /// which does not follow the app's light/dark theme.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.15,
        color: color,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.copy});

  final LandingCopy copy;

  @override
  Widget build(BuildContext context) {
    // No background fill — this is the one section that lets the page's
    // blob backdrop show through.
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, _navHeight + 72, 24, 96),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Positioned.fill for the same reason as _Band's floaters: this
          // group must resolve against the hero's real size (set by the
          // Center content below), not collapse to zero as a bare
          // non-positioned Stack of purely-Positioned children would.
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 8,
                    left: 4,
                    child: _FloatIcon(
                      icon: Icons.event_available_outlined,
                      color: _aboutAccent,
                      delay: const Duration(milliseconds: 0),
                    ),
                  ),
                  Positioned(
                    top: 96,
                    right: -6,
                    child: _FloatIcon(
                      icon: Icons.photo_camera_outlined,
                      color: _featuresAccent,
                      size: 44,
                      iconSize: 19,
                      duration: const Duration(milliseconds: 3100),
                      delay: const Duration(milliseconds: 300),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: -8,
                    child: _FloatIcon(
                      icon: Icons.notifications_active_outlined,
                      color: _downloadAccent,
                      size: 46,
                      iconSize: 20,
                      duration: const Duration(milliseconds: 2900),
                      delay: const Duration(milliseconds: 150),
                    ),
                  ),
                  Positioned(
                    bottom: 120,
                    right: 40,
                    child: _FloatIcon(
                      icon: Icons.verified_user_outlined,
                      color: _stepsAccent,
                      size: 40,
                      iconSize: 18,
                      duration: const Duration(milliseconds: 3400),
                      delay: const Duration(milliseconds: 450),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContent),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= _wide;
                  final copyCol = _HeroCopy(center: !wide, copy: copy);
                  final art = _AppPreview(copy: copy).fadeUp(
                    delay: const Duration(milliseconds: 260),
                    distance: 0.1,
                  );
                  if (!wide) {
                    return Column(
                      children: [copyCol, const SizedBox(height: 56), art],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 6, child: copyCol),
                      const SizedBox(width: 48),
                      Expanded(flex: 5, child: Center(child: art)),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.center, required this.copy});

  final bool center;
  final LandingCopy copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final align = center ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_city, size: 15, color: scheme.primary),
              const SizedBox(width: 7),
              Text(
                copy.heroBadge,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ).fadeUp(),
        const SizedBox(height: 24),
        Text(
          copy.heroHeadline,
          textAlign: align,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
            height: 1.08,
          ),
        ).fadeUp(delay: const Duration(milliseconds: 60)),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            copy.heroSubtext,
            textAlign: align,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ).fadeUp(delay: const Duration(milliseconds: 120)),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: center ? WrapAlignment.center : WrapAlignment.start,
          children: [
            FilledButton(
              onPressed: () => context.go(AppRoutes.register),
              style: FilledButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 20,
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(copy.heroCtaPrimary),
            ),
            OutlinedButton(
              onPressed: () => context.go(AppRoutes.login),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 20,
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(copy.heroCtaSecondary),
            ),
          ],
        ).fadeUp(delay: const Duration(milliseconds: 180)),
        const SizedBox(height: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              center ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle,
              size: 16,
              color: scheme.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                copy.heroFootnote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A stylised mock of the citizen home screen, built from plain widgets
/// rather than a screenshot so it never goes stale against the real UI
/// and stays crisp at any zoom.
class _AppPreview extends StatelessWidget {
  const _AppPreview({required this.copy});

  final LandingCopy copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF11151D) : Colors.white;
    const itemColors = [
      AppConstants.pastelSky,
      AppConstants.pastelMint,
      AppConstants.pastelPeach,
    ];
    const itemIcons = [
      Icons.stadium_outlined,
      Icons.airport_shuttle_outlined,
      Icons.event_seat_outlined,
    ];

    return Container(
      width: 290,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF05070C) : const Color(0xFF1B2230),
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.6 : 0.22),
            blurRadius: 48,
            spreadRadius: -8,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.mockGreeting,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        copy.mockWelcome,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: scheme.primary,
                  child: Text(
                    'MS',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    copy.mockSearch,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              copy.mockAvailable,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < copy.mockItems.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _PreviewItem(
                label: copy.mockItems[i].$1,
                category: copy.mockItems[i].$2,
                color: itemColors[i % itemColors.length],
                icon: itemIcons[i % itemIcons.length],
              ),
            ],
            const SizedBox(height: 18),
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1B2230) : const Color(0xFF161D2A),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.home, size: 18, color: Colors.white),
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.swap_horiz,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  Icon(
                    Icons.account_circle_outlined,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewItem extends StatelessWidget {
  const _PreviewItem({
    required this.label,
    required this.category,
    required this.color,
    required this.icon,
  });

  final String label;
  final String category;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: const Color(0xFF16324F)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 9,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// About
// ─────────────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection({super.key, required this.copy});

  final LandingCopy copy;

  static const _icons = [
    Icons.inventory_2_outlined,
    Icons.gavel_outlined,
    Icons.groups_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Band(
      background: _wash(context, _aboutAccent, 0.045),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wide;
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Eyebrow(text: copy.aboutEyebrow, accent: _aboutAccent),
              const SizedBox(height: 14),
              _SectionHeading(title: copy.aboutHeading, center: false),
              const SizedBox(height: 18),
              Text(
                copy.aboutBody,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.65,
                ),
              ),
            ],
          );

          final points = Column(
            children: [
              for (var i = 0; i < copy.aboutPoints.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _aboutAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _icons[i % _icons.length],
                          size: 21,
                          color: _aboutAccent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              copy.aboutPoints[i].$1,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              copy.aboutPoints[i].$2,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [intro, const SizedBox(height: 40), points],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: intro),
              const SizedBox(width: 72),
              Expanded(child: points),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Features — the one deliberately dark band, for contrast against the
// pastel washes around it.
// ─────────────────────────────────────────────────────────────────────

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection({super.key, required this.copy});

  final LandingCopy copy;

  static const _icons = [
    Icons.event_available_outlined,
    Icons.bolt_outlined,
    Icons.fact_check_outlined,
    Icons.photo_camera_outlined,
    Icons.notifications_active_outlined,
    Icons.badge_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return _Band(
      background: _featuresDarkBg,
      floaters: [
        Positioned(
          top: -10,
          left: 8,
          child: _FloatIcon(
            icon: Icons.bolt_outlined,
            color: _featuresAccent,
            onDark: true,
            size: 44,
            iconSize: 19,
          ),
        ),
        Positioned(
          top: 40,
          right: -6,
          child: _FloatIcon(
            icon: Icons.badge_outlined,
            color: _downloadAccent,
            onDark: true,
            duration: const Duration(milliseconds: 3200),
            delay: const Duration(milliseconds: 250),
          ),
        ),
        Positioned(
          bottom: -6,
          right: 60,
          child: _FloatIcon(
            icon: Icons.fact_check_outlined,
            color: _aboutAccent,
            onDark: true,
            size: 40,
            iconSize: 18,
            duration: const Duration(milliseconds: 2800),
            delay: const Duration(milliseconds: 120),
          ),
        ),
      ],
      child: Column(
        children: [
          _Eyebrow(text: copy.featuresEyebrow, accent: _featuresAccent, center: true),
          const SizedBox(height: 14),
          _SectionHeading(title: copy.featuresHeading, color: Colors.white),
          const SizedBox(height: 48),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= _wide
                  ? 3
                  : constraints.maxWidth >= 600
                  ? 2
                  : 1;
              const gap = 20.0;
              // Laid out row by row inside IntrinsicHeight rather than as
              // one Wrap: Wrap sizes each card independently, which leaves
              // ragged card bottoms whenever one has a shorter blurb.
              final rows = <Widget>[];
              for (var start = 0; start < copy.features.length; start += columns) {
                final slice = copy.features.skip(start).take(columns).toList();
                rows.add(
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < columns; i++) ...[
                          if (i > 0) const SizedBox(width: gap),
                          Expanded(
                            child: i < slice.length
                                ? _FeatureCard(
                                    icon: _icons[(start + i) % _icons.length],
                                    title: slice[i].$1,
                                    body: slice[i].$2,
                                  ).fadeUpAt(start + i)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
                if (start + columns < copy.features.length) {
                  rows.add(const SizedBox(height: gap));
                }
              }
              return Column(children: rows);
            },
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _featuresAccent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 22, color: _featuresAccent),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.68),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// How it works
// ─────────────────────────────────────────────────────────────────────

class _StepsSection extends StatelessWidget {
  const _StepsSection({super.key, required this.copy});

  final LandingCopy copy;

  @override
  Widget build(BuildContext context) {
    return _Band(
      background: _wash(context, _stepsAccent, 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: _Eyebrow(
              text: copy.stepsEyebrow,
              accent: _stepsAccent,
              center: true,
            ),
          ),
          const SizedBox(height: 14),
          // Centred explicitly: this Column aligns to start (the timeline
          // below needs it), so the heading would otherwise shrink-wrap
          // and centre its lines against each other, not the page.
          Center(child: _SectionHeading(title: copy.stepsHeading)),
          const SizedBox(height: 52),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _wide;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < copy.steps.length; i++) ...[
                      Expanded(
                        child: _StepColumn(
                          index: i,
                          title: copy.steps[i].$1,
                          body: copy.steps[i].$2,
                          isLast: i == copy.steps.length - 1,
                        ),
                      ),
                      if (i < copy.steps.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < copy.steps.length; i++)
                    _StepRow(
                      index: i,
                      title: copy.steps[i].$1,
                      body: copy.steps[i].$2,
                      isLast: i == copy.steps.length - 1,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Wide layout: numbered marker with the connecting rule running to the
/// right, copy underneath.
class _StepColumn extends StatelessWidget {
  const _StepColumn({
    required this.index,
    required this.title,
    required this.body,
    required this.isLast,
  });

  final int index;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StepMarker(index: index),
            if (!isLast)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(left: 8),
                  color: _stepsAccent.withValues(alpha: 0.18),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Narrow layout: vertical timeline, marker left, copy right.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.title,
    required this.body,
    required this.isLast,
  });

  final int index;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _StepMarker(index: index),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: _stepsAccent.withValues(alpha: 0.18),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepMarker extends StatelessWidget {
  const _StepMarker({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _stepsAccent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _stepsAccent.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        '${index + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Download
// ─────────────────────────────────────────────────────────────────────

class _DownloadSection extends ConsumerWidget {
  const _DownloadSection({super.key, required this.copy});

  final LandingCopy copy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final release = ref.watch(publishedReleaseProvider);

    return _Band(
      background: _wash(context, _downloadAccent, 0.05),
      floaters: [
        Positioned(
          top: -14,
          right: 24,
          child: _FloatIcon(
            icon: Icons.download_rounded,
            color: _downloadAccent,
            size: 44,
            iconSize: 19,
            duration: const Duration(milliseconds: 3000),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final copyCol = Column(
              crossAxisAlignment: wide
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                _Eyebrow(text: copy.downloadEyebrow, accent: _downloadAccent),
                const SizedBox(height: 12),
                Text(
                  copy.downloadHeading,
                  textAlign: wide ? TextAlign.start : TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  copy.downloadBody,
                  textAlign: wide ? TextAlign.start : TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ],
            );

            final action = Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                switch (release) {
                  AsyncData(:final value) => FilledButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(value.downloadUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _downloadAccent,
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 22,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(copy.downloadButtonLabel),
                  ),
                  AsyncError() => Text(
                    copy.downloadErrorText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  _ => const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                },
                const SizedBox(height: 12),
                Text(
                  switch (release) {
                    AsyncData(:final value) =>
                      '${copy.downloadVersionPrefix}${value.version} · Android 6.0+',
                    _ => copy.downloadFallbackVersion,
                  },
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            );

            if (!wide) {
              return Column(
                children: [copyCol, const SizedBox(height: 32), action],
              );
            }
            return Row(
              children: [
                Expanded(child: copyCol),
                const SizedBox(width: 40),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.copy});

  final LandingCopy copy;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onDark = Colors.white.withValues(alpha: 0.72);

    return Container(
      width: double.infinity,
      color: dark ? const Color(0xFF080B11) : const Color(0xFF161D2A),
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContent),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final brand = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            AppConstants.logoAsset,
                            width: 30,
                            height: 30,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            AppConstants.appName,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(
                          copy.footerTagline,
                          style: TextStyle(
                            color: onDark,
                            height: 1.6,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  );

                  final links = Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FooterColumn(
                        heading: copy.footerGetStarted,
                        items: [
                          (copy.heroCtaPrimary, () => context.go(AppRoutes.register)),
                          (copy.navSignIn, () => context.go(AppRoutes.login)),
                        ],
                      ),
                      const SizedBox(width: 56),
                      _FooterColumn(
                        heading: copy.footerOffice,
                        items: [
                          for (final line in copy.footerOfficeLines) (line, null),
                        ],
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 720) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [brand, const SizedBox(height: 40), links],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: brand),
                      const SizedBox(width: 48),
                      links,
                    ],
                  );
                },
              ),
              const SizedBox(height: 44),
              Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
              const SizedBox(height: 22),
              Text(
                copy.footerCopyright(DateTime.now().year),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.heading, required this.items});

  final String heading;
  final List<(String, VoidCallback?)> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        for (final (label, onTap) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: onTap == null
                ? Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 13,
                    ),
                  )
                : InkWell(
                    onTap: onTap,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 13,
                      ),
                    ),
                  ),
          ),
      ],
    );
  }
}
