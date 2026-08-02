import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/glossy_background.dart';
import '../../settings/data/app_update_providers.dart';

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
const _featuresAccent = Color(0xFF1F9D65);
const _stepsAccent = Color(0xFF6750A4);
const _downloadAccent = Color(0xFFE07A1F);

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
                  const _Hero(),
                  _AboutSection(key: _aboutKey),
                  _FeaturesSection(key: _featuresKey),
                  _StepsSection(key: _stepsKey),
                  _DownloadSection(key: _downloadKey),
                  const _Footer(),
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
    required this.onAbout,
    required this.onFeatures,
    required this.onSteps,
    required this.onDownload,
  });

  final bool solid;
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
                  _NavLink(label: 'About', onTap: onAbout),
                  _NavLink(label: 'Features', onTap: onFeatures),
                  _NavLink(label: 'How it works', onTap: onSteps),
                  _NavLink(label: 'Download', onTap: onDownload),
                  const SizedBox(width: 16),
                ],
                TextButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Sign in'),
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
                  child: const Text('Register'),
                ),
              ],
            ),
          ),
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
/// [_maxContent] and centred.
class _Band extends StatelessWidget {
  const _Band({required this.child, this.background});

  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(vertical: 96, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContent),
          child: child,
        ),
      ),
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
  const _SectionHeading({required this.title, this.center = true});

  final String title;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.15,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    // No background fill — this is the one section that lets the page's
    // blob backdrop show through.
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, _navHeight + 72, 24, 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContent),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _wide;
              final copy = _HeroCopy(center: !wide);
              final art = const _AppPreview().fadeUp(
                delay: const Duration(milliseconds: 260),
                distance: 0.1,
              );
              if (!wide) {
                return Column(
                  children: [copy, const SizedBox(height: 56), art],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 6, child: copy),
                  const SizedBox(width: 48),
                  Expanded(flex: 5, child: Center(child: art)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.center});

  final bool center;

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
                'Municipality of Bongabong',
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
          'Borrow LGU equipment\nwithout the paperwork.',
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
            'Reserve a venue, book a municipal vehicle, or borrow equipment '
            'for your barangay event — request it from your phone and track '
            'it through to return.',
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
              child: const Text('Create an account'),
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
              child: const Text('Sign in'),
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
                'Free for residents · No email required to sign up',
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
  const _AppPreview();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF11151D) : Colors.white;

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
                        'Hello, Maria',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Welcome to SBS',
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
                    'Search items…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Available now',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const _PreviewItem(
              label: 'Municipal Gymnasium',
              category: 'VENUE',
              color: AppConstants.pastelSky,
              icon: Icons.stadium_outlined,
            ),
            const SizedBox(height: 8),
            const _PreviewItem(
              label: 'Passenger Van',
              category: 'VEHICLE',
              color: AppConstants.pastelMint,
              icon: Icons.airport_shuttle_outlined,
            ),
            const SizedBox(height: 8),
            const _PreviewItem(
              label: 'Monobloc Chairs',
              category: 'EQUIPMENT',
              color: AppConstants.pastelPeach,
              icon: Icons.event_seat_outlined,
            ),
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
  const _AboutSection({super.key});

  static const _points = <(IconData, String, String)>[
    (
      Icons.inventory_2_outlined,
      'One shared catalogue',
      'Venues, vehicles, and equipment from every office in one registry.',
    ),
    (
      Icons.gavel_outlined,
      'Accountable by default',
      'Every request is reviewed, and every handoff and return is on record.',
    ),
    (
      Icons.groups_outlined,
      'Built for residents',
      'No walk-in queue to reserve something — the whole request happens online.',
    ),
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
              const _Eyebrow(text: 'About the system', accent: _aboutAccent),
              const SizedBox(height: 14),
              const _SectionHeading(
                title: 'Replacing the logbook\nat the LGU counter.',
                center: false,
              ),
              const SizedBox(height: 18),
              Text(
                'The Schedule Borrowing System keeps track of everything the '
                'municipality lends out. Residents request what they need, '
                'staff review it, and the condition of each item is '
                'photographed at handoff and at return — so nothing depends '
                'on remembering who had what.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.65,
                ),
              ),
            ],
          );

          final points = Column(
            children: [
              for (final (icon, title, body) in _points)
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
                        child: Icon(icon, size: 21, color: _aboutAccent),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              body,
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
// Features
// ─────────────────────────────────────────────────────────────────────

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection({super.key});

  static const _features = <(IconData, String, String)>[
    (
      Icons.event_available_outlined,
      'Schedule or borrow',
      'Reserve a venue or vehicle for a date, or take equipment with you — '
          'the flow adapts to which one you picked.',
    ),
    (
      Icons.bolt_outlined,
      'Same-day requests',
      'No minimum lead time. Ask for something you need this afternoon, or '
          'plan an event up to a year out.',
    ),
    (
      Icons.fact_check_outlined,
      'Reviewed before pickup',
      'Requests route to the office that owns the item, so the right staffer '
          'approves it.',
    ),
    (
      Icons.photo_camera_outlined,
      'Photo evidence',
      'Condition is captured at handoff and again at return, protecting both '
          'the borrower and the LGU.',
    ),
    (
      Icons.notifications_active_outlined,
      'Told the moment it changes',
      'Approvals, upcoming due dates, and overdue items reach you as push '
          'notifications.',
    ),
    (
      Icons.badge_outlined,
      'Verified once',
      'Staff check your ID at your first pickup. Every request after that is '
          'already accounted for.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _Band(
      background: _wash(context, _featuresAccent, 0.05),
      child: Column(
        children: [
          const _Eyebrow(
            text: 'Features',
            accent: _featuresAccent,
            center: true,
          ),
          const SizedBox(height: 14),
          const _SectionHeading(title: 'Everything the counter did,\nbut faster.'),
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
              for (var start = 0; start < _features.length; start += columns) {
                final slice = _features.skip(start).take(columns).toList();
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
                                    icon: slice[i].$1,
                                    title: slice[i].$2,
                                    body: slice[i].$3,
                                  ).fadeUpAt(start + i)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
                if (start + columns < _features.length) {
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
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _featuresAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 22, color: _featuresAccent),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
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
  const _StepsSection({super.key});

  static const _steps = <(String, String)>[
    (
      'Create your account',
      'Full name, a username, your contact number, and a photo of any valid '
          'government ID. No email needed.',
    ),
    (
      'Find what you need',
      'Browse the catalogue, or pick Schedule for venues and vehicles and '
          'Borrow for equipment.',
    ),
    (
      'Send the request',
      'Choose your dates, the quantity, and when you will pick it up. Submit '
          'and you are in the queue.',
    ),
    (
      'Get approved',
      'The office that owns the item reviews it. You are notified the moment '
          'the decision lands.',
    ),
    (
      'Pick up and return',
      'Staff photograph the item with you at handoff, and again when you '
          'bring it back. That closes the loan.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _Band(
      background: _wash(context, _stepsAccent, 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: _Eyebrow(
              text: 'How it works',
              accent: _stepsAccent,
              center: true,
            ),
          ),
          const SizedBox(height: 14),
          // Centred explicitly: this Column aligns to start (the timeline
          // below needs it), so the heading would otherwise shrink-wrap
          // and centre its lines against each other, not the page.
          const Center(
            child: _SectionHeading(
              title: 'From request to return\nin five steps.',
            ),
          ),
          const SizedBox(height: 52),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _wide;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _steps.length; i++) ...[
                      Expanded(
                        child: _StepColumn(
                          index: i,
                          title: _steps[i].$1,
                          body: _steps[i].$2,
                          isLast: i == _steps.length - 1,
                        ),
                      ),
                      if (i < _steps.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    _StepRow(
                      index: i,
                      title: _steps[i].$1,
                      body: _steps[i].$2,
                      isLast: i == _steps.length - 1,
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
  const _DownloadSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final release = ref.watch(publishedReleaseProvider);

    return _Band(
      background: _wash(context, _downloadAccent, 0.05),
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
            final copy = Column(
              crossAxisAlignment: wide
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                const _Eyebrow(text: 'Get the app', accent: _downloadAccent),
                const SizedBox(height: 12),
                Text(
                  'Install SBS on your Android phone.',
                  textAlign: wide ? TextAlign.start : TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The app adds push notifications and camera capture at '
                  'handoff. Everything else works here in the browser too.',
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
                    label: const Text('Download the APK'),
                  ),
                  AsyncError() => Text(
                    'The download link is unavailable right now.',
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
                      'Version ${value.version} · Android 6.0+',
                    _ => 'Android 6.0 and up',
                  },
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            );

            if (!wide) {
              return Column(
                children: [copy, const SizedBox(height: 32), action],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
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
  const _Footer();

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
                          '${AppConstants.appFullName} — the Municipality of '
                          "Bongabong's platform for reserving and borrowing "
                          'LGU property.',
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
                        heading: 'Get started',
                        items: [
                          ('Create an account', () => context.go(AppRoutes.register)),
                          ('Sign in', () => context.go(AppRoutes.login)),
                        ],
                      ),
                      const SizedBox(width: 56),
                      _FooterColumn(
                        heading: 'Office',
                        items: const [
                          ('Municipal Hall, Bongabong', null),
                          ('Oriental Mindoro', null),
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
                '© ${DateTime.now().year} Municipality of Bongabong · '
                'All rights reserved',
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
