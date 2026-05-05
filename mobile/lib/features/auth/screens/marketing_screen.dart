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
        const _SectionTitle('Bigger pots. Real golf. Zero spreadsheets.'),
        const _Paragraph(
          'Clubhouse Stakes turns your weekend round into a skill-based tournament '
          'with a real prize pool — and runs every piece of math, money, and scoring '
          'for you. The leaderboard is live. The skins are calculated to handicap '
          'automatically. Payouts are clean. The pot is bigger than what your '
          'group has been playing for.',
        ),
        const SizedBox(height: 22),

        const _SectionTitle('Why pots get bigger here'),
        const _Bullet(
            'Pay-at-course tracking lets hosts confirm everyone\'s in before the first tee. '
            'No "I forgot cash" excuses thinning the pot.'),
        const _Bullet(
            'Skins side-game runs alongside the main event with its own pot, hole-by-hole '
            'carryovers, and per-hole values — players double their action without doubling the friction.'),
        const _Bullet(
            'Public clubhouse pages let courses pull in regional players for open events instead '
            'of being capped to a 12-person friend group.'),
        const _Bullet(
            'Designated team scorers + automatic best-ball / scramble math means events can go bigger — '
            '4-ball, 4-man scramble, multi-team — without the host losing the day to a clipboard.'),

        const SizedBox(height: 22),
        const _SectionTitle('Hosting actually built for hosts'),
        const _Paragraph(
          'Most tools ask the host to be a part-time accountant. Clubhouse Stakes runs the back office:',
        ),
        const _Bullet(
            'Course search auto-fills pars, yardages, and the full official scorecard from a 30,000-course database.'),
        const _Bullet(
            'Payment dashboard shows running collected vs. outstanding cash, broken out by entry fee + skins. Tap to mark paid.'),
        const _Bullet(
            'Live scoring on every player\'s phone — leaderboards update for spectators in real time. No paper, no late entry.'),
        const _Bullet(
            'Branded clubhouse page (logo, banner, colors) that members and visitors actually want to share.'),
        const _Bullet(
            'Email-based member invites that auto-attach the moment the recipient signs up — no CSV imports.'),

        const SizedBox(height: 22),
        const _SectionTitle('Skins, the way they should work'),
        const _Paragraph(
          'Every other app makes you compute net scores manually before the skins app even tells you '
          'who won the hole. We bake handicap allowance directly into the skins engine:',
        ),
        const _Bullet(
            'Strokes are awarded by USGA stroke index automatically — players don\'t have to know which holes get them strokes.'),
        const _Bullet(
            'Net scores per player per hole feed straight into skins detection. Tied = carryover. Outright = pot won.'),
        const _Bullet(
            'Pot value compounds in real time. Carries roll. Ties at the end of the round split correctly.'),
        const _Bullet(
            'Whether you\'re a 2-handicap or a 24, the side game is fair from hole 1.'),

        const SizedBox(height: 22),
        const _SectionTitle('Who runs it'),
        const _Paragraph(
          'A small team based in Kansas City who play a lot of golf, hate manual scorecards, '
          'and watched too many groups argue at the bar over who won the back-9 skins.',
        ),
        const SizedBox(height: 26),
        _CTAButton(
          label: 'Sign up — free in beta',
          onPressed: () => context.go('/signup'),
        ),
        const SizedBox(height: 8),
        _SecondaryCTA(
          label: 'Running a course or league? See For Clubs →',
          onPressed: () => context.push('/for-clubs'),
        ),
      ];

  // ── For Clubs ─────────────────────────────────────────────────────────────
  List<Widget> _forClubsContent(BuildContext context) => [
        const _SectionTitle('Stop running tournaments on a clipboard.'),
        const _Paragraph(
          'Your members want to play for real money. Your front desk shouldn\'t have to '
          'become a tournament director to make it happen. Clubhouse Stakes is the operations '
          'layer your club is missing — built specifically for pay-out events, leagues, and '
          'member outings.',
        ),
        const SizedBox(height: 22),

        const _SectionTitle('Why we exist'),
        const _Paragraph(
          'Pros, GMs, and league coordinators are stuck with three bad options:',
        ),
        const _Bullet(
            'Spreadsheets + Venmo + a paper scoreboard — free, but a logistical nightmare every Saturday.'),
        const _Bullet(
            'Generic tournament software that costs hundreds a month, takes 20 minutes to set up an event, '
            'and was last redesigned in 2014.'),
        const _Bullet(
            'A booking-tee-times tool that bolts on a mediocre scorecard feature as an afterthought.'),

        const _Paragraph(
          'None of these were built for the actual workflow: collecting cash at the first tee, '
          'tracking who paid, scoring 36 players on phones, computing handicapped skins, '
          'and getting payouts right by the time the last group is in the clubhouse.',
        ),

        const SizedBox(height: 22),
        const _SectionTitle('What you get that other tools don\'t'),

        const _FeatureCard(
          icon: Icons.bolt_outlined,
          title: 'Tournament setup in under 2 minutes',
          body:
              'Type the course name, we pull the official scorecard — pars, yardages, all 18 holes, '
              'all tee boxes. Pick a format, set fees, hit publish. Compare to GolfGenius (15+ minutes) '
              'or BlueGolf (a workshop with their support team).',
        ),
        const _FeatureCard(
          icon: Icons.attach_money,
          title: 'Pay-at-course tracking, no Stripe required',
          body:
              'Most tools force online card payments — your members hate it, you eat the fees. '
              'We let players reserve a spot online and you collect cash at check-in. Mark paid in '
              'two taps. Dashboard shows you collected vs. outstanding in real time. No 2.9% + 30¢.',
        ),
        const _FeatureCard(
          icon: Icons.casino_outlined,
          title: 'Skins that actually compute correctly',
          body:
              'USGA stroke index, handicap allowance per hole, carryovers, ties — all automatic. '
              'No more pulling out a calculator at the bar. Players see the running pot and who\'s '
              'in lead on every hole, live, on their phone.',
        ),
        const _FeatureCard(
          icon: Icons.leaderboard_outlined,
          title: 'Live scoring on every phone',
          body:
              'Hole-by-hole entry. Designated team scorer for fourball / scramble. Leaderboard '
              'updates for spectators in real time. The bar TV (yes, you can cast it) shows the '
              'live board so the room is into it before the last putt drops.',
        ),
        const _FeatureCard(
          icon: Icons.flag_outlined,
          title: 'A clubhouse page worth sharing',
          body:
              'Your logo, your banner, your brand colors. Member roster, tournament calendar, '
              'member-only or public — your call. Drop a link in your weekly member email and they '
              'see exactly what\'s coming up. iMessage previews look like a real link card, not a 404.',
        ),
        const _FeatureCard(
          icon: Icons.person_add_alt_1_outlined,
          title: 'Member onboarding without the CSV',
          body:
              'Invite by email — even if they don\'t have an account yet. The moment they sign up, '
              'they\'re in your clubhouse. Notifications flow automatically when you post a tournament. '
              'No "send out the spreadsheet again" emails.',
        ),
        const _FeatureCard(
          icon: Icons.business_center_outlined,
          title: 'Staff seats included',
          body:
              'Promote your front desk + assistant pros to staff so they can run events without '
              'sharing your password. Most platforms charge per seat. Ours doesn\'t.',
        ),
        const _FeatureCard(
          icon: Icons.shield_outlined,
          title: 'Your data, your members',
          body:
              'We don\'t sell member info. We don\'t lock you into a contract. Your roster, your '
              'tournament history, your payout records — exportable on request, anytime.',
        ),

        const SizedBox(height: 22),
        const _SectionTitle('Versus the competition'),
        const _ComparisonTable(),

        const SizedBox(height: 22),
        const _SectionTitle('Pricing'),
        const _Paragraph(
          'Free for the duration of the beta. After that, transparent flat-rate pricing — '
          'no per-event fees, no payment surcharges, no per-seat staff costs. Nothing you have '
          'to read fine print to understand.',
        ),
        const SizedBox(height: 24),
        _CTAButton(
          label: 'Get your course on Clubhouse Stakes',
          onPressed: () => context.go('/signup'),
        ),
        const SizedBox(height: 8),
        _SecondaryCTA(
          label: 'Want a personal walkthrough? support@clubhousestakes.com',
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

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable();

  @override
  Widget build(BuildContext context) {
    const rows = <List<String>>[
      // [feature, ours, others]
      ['Set up a tournament', 'Under 2 min', '10–20 min'],
      ['Course scorecards',   'Auto from API',  'Manual entry'],
      ['Skins handicapping',  'Built-in, automatic', 'External app or by hand'],
      ['Pay-at-course flow',  'Yes',         'Online cards only'],
      ['Branded clubhouse',   'Yes',         'Tee-time tool addon'],
      ['Live leaderboard',    'Real-time',  'Refresh button'],
      ['Staff seats',         'Unlimited',  'Per-seat fees'],
      ['Member-invite by email', 'Yes',     'CSV import'],
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // Header row
        Container(
          color: AppColors.primary.withOpacity(0.08),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(children: const [
            Expanded(
              flex: 4,
              child: Text('FEATURE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: AppColors.textSecondary)),
            ),
            Expanded(
              flex: 3,
              child: Text('CLUBHOUSE STAKES',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: AppColors.primary)),
            ),
            Expanded(
              flex: 3,
              child: Text('OTHER PLATFORMS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: AppColors.textSecondary)),
            ),
          ]),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(children: [
              Expanded(
                flex: 4,
                child: Text(rows[i][0],
                    style: const TextStyle(fontSize: 13, height: 1.3)),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(rows[i][1],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(rows[i][2],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
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
