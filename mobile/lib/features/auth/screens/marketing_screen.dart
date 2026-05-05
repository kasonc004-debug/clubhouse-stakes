import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/clubhouse_logo.dart';

/// Public marketing pages — About Us and For Clubs. Reachable from the
/// login / signup footer and from inside the app's drawer.
class MarketingScreen extends StatelessWidget {
  /// 'about' or 'clubs'
  final String variant;
  const MarketingScreen({super.key, required this.variant});

  bool get _isClubs => variant == 'clubs';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(slivers: [
        // Hero
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: AppColors.primaryDeep,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B3D2C),
                    Color(0xFF2A5940),
                    Color(0xFF3D7055),
                  ],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ClubhouseLogo(width: 220, showTagline: !_isClubs),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _isClubs ? _forClubsContent(context) : _aboutContent(context),
            ),
          ),
        ),
      ]),
    );
  }

  // ── About Us ──────────────────────────────────────────────────────────────
  List<Widget> _aboutContent(BuildContext context) => [
        const _SectionTitle('About Clubhouse Stakes'),
        const _Paragraph(
          'Clubhouse Stakes is a skill-based golf tournament platform. Real golfers, '
          'real courses, real prize pools — without the spreadsheets and the Venmo chaos.',
        ),
        const _Paragraph(
          'We built it because every weekend group, club tournament, and outing we ever '
          'played in had the same broken pattern: someone collects cash at the first tee, '
          'someone else tries to keep score on their phone, and at the end of the day '
          'no one is sure who actually won the skins. That ends here.',
        ),
        const SizedBox(height: 18),
        const _SectionTitle('What you get'),
        const _Bullet(
            'Live, hole-by-hole leaderboards on every device — no refresh dance.'),
        const _Bullet(
            'Individual stroke play, four-ball, and scramble formats with proper handicap math.'),
        const _Bullet(
            'Optional skins game tracked separately, with carryovers, ties, and per-hole pots.'),
        const _Bullet(
            'A record book that remembers your best rounds across every tournament you play.'),
        const _Bullet(
            'Pay-at-course confirmation so the host knows exactly what each player owes.'),
        const SizedBox(height: 18),
        const _SectionTitle('Who runs it'),
        const _Paragraph(
          'A small team based out of Kansas City. We play a lot of golf, we hate manual scorecards, '
          'and we wanted a clean way to bet on our rounds with friends without making it weird.',
        ),
        const SizedBox(height: 24),
        _CTAButton(
          label: 'Sign up — it\'s free',
          onPressed: () => context.go('/signup'),
        ),
        const SizedBox(height: 8),
        _SecondaryCTA(
          label: 'Are you running a club? See what we offer →',
          onPressed: () => context.push('/for-clubs'),
        ),
      ];

  // ── For Clubs ─────────────────────────────────────────────────────────────
  List<Widget> _forClubsContent(BuildContext context) => [
        const _SectionTitle('Software your club won\'t outgrow'),
        const _Paragraph(
          'Clubhouse Stakes is the simplest way to run pay-out tournaments, leagues, and '
          'member events at your course. Designed for the people who actually run the show — '
          'pros, GMs, league coordinators, and the front-desk staff fielding scorecard questions.',
        ),
        const SizedBox(height: 22),
        const _SectionTitle('Why courses choose us'),

        const _FeatureCard(
          icon: Icons.bolt_outlined,
          title: 'Set up a tournament in 90 seconds',
          body:
              'Pick the format, search your course in our database, choose tees, set entry fee. Done. '
              'Pars and yardages auto-fill from the official scorecard.',
        ),
        const _FeatureCard(
          icon: Icons.attach_money,
          title: 'Pay-at-course flow built in',
          body:
              'Players reserve their spot online and you collect at check-in. Mark them paid in two '
              'taps. The dashboard shows you cash collected vs. outstanding in real time.',
        ),
        const _FeatureCard(
          icon: Icons.flag_outlined,
          title: 'Your branded clubhouse page',
          body:
              'Logo, banner, colors, course info, member roster, your tournament calendar — '
              'all on one shareable page. Members get notified when you post a new event.',
        ),
        const _FeatureCard(
          icon: Icons.leaderboard_outlined,
          title: 'Live scoring that just works',
          body:
              'Players enter scores hole by hole on their phones. Net, gross, skins, and team '
              'best-ball all compute themselves. The leaderboard updates instantly for every '
              'spectator in the clubhouse.',
        ),
        const _FeatureCard(
          icon: Icons.groups_2_outlined,
          title: 'Member invites — no roster spreadsheet',
          body:
              'Invite by email even before someone has an account. They sign up, and they\'re '
              'automatically added to your clubhouse. No CSV import dance.',
        ),
        const _FeatureCard(
          icon: Icons.shield_outlined,
          title: 'You own the experience',
          body:
              'Public clubs get a discoverable page so traveling golfers find you. Private clubs '
              'stay invite-only. Either way, your data is yours.',
        ),

        const SizedBox(height: 22),
        const _SectionTitle('Pricing'),
        const _Paragraph(
          'During the beta, Clubhouse Stakes is free for clubs and players. Reach out and '
          'we\'ll set up your clubhouse page personally.',
        ),
        const SizedBox(height: 24),
        _CTAButton(
          label: 'Get your club on Clubhouse Stakes',
          onPressed: () => context.go('/signup'),
        ),
        const SizedBox(height: 8),
        _SecondaryCTA(
          label: 'Have questions? support@clubhousestakes.com',
          onPressed: null,
        ),
      ];
}

// ── Building blocks ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary)),
      );
}

class _Paragraph extends StatelessWidget {
  final String text;
  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14, height: 1.6, color: AppColors.textPrimary)),
      );
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 10),
            child: Icon(Icons.check_circle,
                size: 14, color: AppColors.primary),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, height: 1.55, color: AppColors.textPrimary)),
          ),
        ]),
      );
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textSecondary)),
                ]),
          ),
        ]),
      );
}

class _CTAButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _CTAButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
        ),
      );
}

class _SecondaryCTA extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _SecondaryCTA({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(
          onPressed: onPressed,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
        ),
      );
}
