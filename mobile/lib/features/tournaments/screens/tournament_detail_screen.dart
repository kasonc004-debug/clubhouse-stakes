import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/tournament_model.dart';
import '../providers/tournament_provider.dart';

class TournamentDetailScreen extends ConsumerWidget {
  final String tournamentId;
  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentAsync = ref.watch(tournamentDetailProvider(tournamentId));
    final joinState       = ref.watch(joinTournamentProvider);

    return tournamentAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Scaffold(body: ErrorCard(message: e.toString())),
      data:  (t)    => _DetailView(tournament: t, joinState: joinState),
    );
  }
}

// ── Main layout ───────────────────────────────────────────────────────────────
class _DetailView extends ConsumerStatefulWidget {
  final TournamentModel tournament;
  final AsyncValue<void> joinState;
  const _DetailView({required this.tournament, required this.joinState});

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView> {
  @override
  Widget build(BuildContext context) {
    final t    = widget.tournament;
    final user = ref.watch(authProvider).user;
    final showRegister  = t.isUpcoming && user != null && !t.isTeamFormat && !t.isEnrolled;
    final showEnterScore = t.status == 'active' && t.isEnrolled;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────
          Positioned.fill(
           child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: showRegister || showEnterScore ? 100 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero — full width, no constraint
                _Hero(tournament: t, onBack: () => context.pop()),

                // Everything below is center-constrained for wide screens
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pay-at-course owed banner (only when this user owes money)
                        if (t.amountOwed > 0)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: _OwedBanner(tournament: t),
                          ),

                        // Stat strip
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: _StatStrip(tournament: t),
                        ),

                        const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Details
                              _SectionHeader('DETAILS'),
                              const SizedBox(height: 12),
                              _InfoCard(children: [
                                _InfoRow(Icons.calendar_today_outlined, 'Date & Time',
                                  DateFormat('EEEE, MMMM d · h:mm a').format(t.date)),
                                const _RowDivider(),
                                _InfoRow(Icons.location_on_outlined, 'Course',
                                  t.courseName != null ? '${t.courseName!}\n${t.city}' : t.city),
                                const _RowDivider(),
                                _InfoRow(Icons.sports_golf, 'Format', t.formatLabel),
                                if (t.clubhouseSlug != null) ...[
                                  const _RowDivider(),
                                  _LinkRow(
                                    icon: Icons.flag_outlined,
                                    label: 'Hosted by',
                                    value: t.clubhouseName ?? 'Clubhouse',
                                    onTap: () =>
                                        context.push('/clubhouses/${t.clubhouseSlug}'),
                                  ),
                                ],
                                const _RowDivider(),
                                _InfoRow(Icons.people_outlined, 'Field',
                                  '${t.playerCount} / ${t.maxPlayers} registered · ${t.spotsLeft} spots left'),
                              ]),

                              // Description
                              if (t.description != null) ...[
                                const SizedBox(height: 24),
                                _SectionHeader('ABOUT'),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    t.description!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      height: 1.65,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],

                              // Payout structure
                              const SizedBox(height: 24),
                              _SectionHeader('PAYOUT STRUCTURE'),
                              const SizedBox(height: 12),
                              _PayoutCard(tournament: t),

                              // Team options (fourball / scramble)
                              if (t.isTeamFormat && t.isUpcoming && user != null) ...[
                                const SizedBox(height: 24),
                                _SectionHeader('TEAM OPTIONS'),
                                const SizedBox(height: 12),
                                _TeamButtons(tournament: t, joinState: widget.joinState),
                              ],

                              // Players signed up
                              const SizedBox(height: 24),
                              _SectionHeader('PLAYERS · ${t.playerCount}'),
                              const SizedBox(height: 12),
                              _ParticipantsCard(tournamentId: t.id),

                              // Skins game (only if enabled on this tournament)
                              if (t.hasSkinsGame) ...[
                                const SizedBox(height: 24),
                                _SectionHeader('SKINS GAME'),
                                const SizedBox(height: 12),
                                _SkinsCard(tournament: t),
                              ],

                              // Rules
                              const SizedBox(height: 24),
                              _OutlineButton(
                                icon: Icons.gavel_outlined,
                                label: 'TOURNAMENT RULES',
                                onTap: () => _showRules(context, t),
                              ),

                              // Leaderboard
                              const SizedBox(height: 12),
                              _OutlineButton(
                                icon: Icons.leaderboard_outlined,
                                label: 'VIEW LEADERBOARD',
                                onTap: () => context.push('/leaderboard/${t.id}'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
           ),
          ),

          // ── Sticky action button ────────────────────────────
          if (showRegister || showEnterScore)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20, 16, 20,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: showRegister
                    ? _RegisterButton(tournament: t, joinState: widget.joinState)
                    : _EnterScoreButton(tournamentId: t.id),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Owed banner ──────────────────────────────────────────────────────────────
class _OwedBanner extends StatelessWidget {
  final TournamentModel tournament;
  const _OwedBanner({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final lines = <String>[
      if (t.entryFeeOutstanding) 'Entry fee  \$${t.signUpFee.toStringAsFixed(0)}',
      if (t.skinsFeeOutstanding) 'Skins fee  \$${t.skinsFee.toStringAsFixed(0)}',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFC9A84C).withOpacity(0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.45)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const Icon(Icons.attach_money, color: Color(0xFFC9A84C), size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Pay \$${t.amountOwed.toStringAsFixed(0)} at the course',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8B6F23)),
            ),
            const SizedBox(height: 2),
            Text(lines.join('  ·  '),
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF8B6F23))),
            const SizedBox(height: 4),
            const Text(
              'The host will mark you as paid once they collect at check-in.',
              style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8B6F23),
                  height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Pay-at-course confirmation dialog ────────────────────────────────────────
Future<bool> _confirmPayAtCourse(
  BuildContext context, {
  required String title,
  required double fee,
  required String label,
}) async {
  if (fee <= 0) return true;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text('\$${fee.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Online payments aren\'t live yet. By tapping confirm, you\'re reserving '
            'your spot and agreeing to pay the course at check-in. The host will '
            'mark you as paid once they collect.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm — pay at course'),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ── Rules sheet ───────────────────────────────────────────────────────────────
void _showRules(BuildContext context, TournamentModel t) {
  final rulesText = (t.rules?.trim().isNotEmpty ?? false)
      ? t.rules!
      : _defaultRules(t);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scroll) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.gavel_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            const Text('TOURNAMENT RULES',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              controller: scroll,
              child: Text(
                rulesText,
                style: const TextStyle(
                    fontSize: 14, height: 1.6, color: AppColors.textPrimary),
              ),
            ),
          ),
        ]),
      ),
    ),
  );
}

String _defaultRules(TournamentModel t) {
  String fmtRules;
  if (t.isFourball) {
    fmtRules = '''FORMAT — FOUR-BALL (BEST BALL)
- Two-player teams. Each player plays their own ball.
- The team's score on each hole is the lower of the two balls.
- Net score uses each player's handicap (lower of the two strokes received on each hole).''';
  } else if (t.isScramble) {
    fmtRules = '''FORMAT — SCRAMBLE
- Teams of 2–4 players. Everyone tees off on each hole.
- The team picks the best shot, all players play their next shot from that spot. Repeat until the ball is holed.
- One team score per hole, entered by the designated scorer.
- Handicap allowance:
    · 2-man scramble: 35% of low handicap + 15% of high (when handicap mode is on)
    · 3- or 4-man scramble: gross only — handicaps do not apply.''';
  } else {
    fmtRules = '''FORMAT — INDIVIDUAL STROKE PLAY
- Each player plays their own ball for 18 holes.
- Total gross strokes are the gross score.
- Net score = gross score − player handicap.''';
  }

  return '''$fmtRules

GENERAL RULES
- USGA Rules of Golf apply except where modified below.
- Play the ball as it lies. No improving the lie except in marked ground-under-repair.
- Lost ball / out-of-bounds: stroke and distance.
- Pace of play: keep up with the group ahead.

SCORING
- Enter scores hole-by-hole in the app during or immediately after the round.
- Scores are subject to verification by the tournament host.
- Disputes must be raised within 48 hours of round completion.

TIES
- Ties at the top of the leaderboard share the prize for that position equally unless the host posts a playoff format.

DISQUALIFICATION
- Falsifying scores, cheating, or violating posted rules results in disqualification and forfeiture of fees.''';
}

// ── Hero ──────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  final TournamentModel tournament;
  final VoidCallback onBack;
  const _Hero({required this.tournament, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final t = tournament;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3D2C), Color(0xFF2A5940), Color(0xFF3D7055)],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20, top: -20,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            right: 40, bottom: 20,
            child: Icon(Icons.sports_golf,
                size: 140, color: Colors.white.withOpacity(0.04)),
          ),

          // ── Content ──────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.30),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Course label
                  if (t.courseName != null)
                    Text(
                      t.courseName!.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFC9A84C),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                  const SizedBox(height: 6),

                  // Tournament name
                  Text(
                    t.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Badges row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroBadge(
                        icon: Icons.calendar_today_outlined,
                        label: DateFormat('MMM d, yyyy').format(t.date),
                      ),
                      _HeroBadge(
                        icon: Icons.location_on_outlined,
                        label: t.city,
                      ),
                      _StatusBadge(status: t.status),
                    ],
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

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white70, size: 12),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      'active'    => (AppColors.success, AppColors.success.withOpacity(0.25)),
      'completed' => (Colors.white54, Colors.white.withOpacity(0.1)),
      _           => (const Color(0xFFC9A84C), const Color(0xFFC9A84C).withOpacity(0.2)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1)),
    );
  }
}

// ── Stat Strip ────────────────────────────────────────────────────────────────
class _StatStrip extends StatelessWidget {
  final TournamentModel tournament;
  const _StatStrip({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        _Stat(
            label: 'ENTRY FEE',
            value: '\$${t.signUpFee.toStringAsFixed(0)}',
            sub: 'per ${t.feePer}'),
        _VertDivider(),
        _Stat(
            label: 'PURSE',
            value: '\$${t.purse.toStringAsFixed(0)}',
            sub: 'total pot',
            accent: true),
        _VertDivider(),
        _Stat(
            label: 'SPOTS LEFT',
            value: '${t.spotsLeft}',
            sub: 'of ${t.maxPlayers}',
            warn: t.isFull),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value, sub;
  final bool accent, warn;
  const _Stat(
      {required this.label,
      required this.value,
      required this.sub,
      this.accent = false,
      this.warn = false});

  @override
  Widget build(BuildContext context) {
    final color = warn
        ? AppColors.error
        : accent
            ? const Color(0xFFC9A84C)
            : AppColors.textPrimary;
    return Expanded(
      child: Column(children: [
        Text(label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.textSecondary,
            )),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        Text(sub,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      height: 36,
      width: 1,
      color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 8));
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
        color: AppColors.textSecondary,
      ));
}

// ── Info card / rows ──────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children));
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF1B3D2C).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF1B3D2C)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: AppColors.textSecondary,
                )),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.4)),
          ]),
        ),
      ]));
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1B3D2C).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF1B3D2C)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    letterSpacing: 1, color: AppColors.textSecondary,
                  )),
              const SizedBox(height: 3),
              Row(children: [
                Flexible(
                  child: Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.primary,
                          height: 1.4)),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.open_in_new,
                    size: 14, color: AppColors.primary),
              ]),
            ]),
          ),
        ]),
      ),
    );
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.only(left: 66),
      child: Divider(height: 1, color: AppColors.divider));
}

// ── Payout card ───────────────────────────────────────────────────────────────
class _PayoutCard extends StatelessWidget {
  final TournamentModel tournament;
  const _PayoutCard({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final purse = tournament.purse;
    final rows = [
      ('1st Place', '🥇', 0.50, const Color(0xFFC9A84C)),
      ('2nd Place', '🥈', 0.30, const Color(0xFF9E9E9E)),
      ('3rd Place', '🥉', 0.20, const Color(0xFFCD7F32)),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final (place, emoji, pct, color) = entry.value;
          final amount = purse * pct;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(children: [
                  Text(emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(place,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          Text('${(pct * 100).toStringAsFixed(0)}% of purse',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ]),
                  ),
                  Text(
                    purse > 0
                        ? '\$${amount.toStringAsFixed(0)}'
                        : '—',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color),
                  ),
                ]),
              ),
              if (i < rows.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: 56),
                  child: Divider(height: 1, color: AppColors.divider),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Team buttons ──────────────────────────────────────────────────────────────
class _TeamButtons extends StatelessWidget {
  final TournamentModel tournament;
  final AsyncValue<void> joinState;
  const _TeamButtons({required this.tournament, required this.joinState});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary: register with partner
          _FilledButton(
            icon: Icons.group_add_outlined,
            label: 'REGISTER AS A TEAM',
            onTap: joinState.isLoading
                ? null
                : () => context.push('/tournament/${tournament.id}/create-team'),
          ),
          const SizedBox(height: 10),
          // Secondary: join a team your partner already created
          _OutlineButton(
            icon: Icons.group_outlined,
            label: 'JOIN AN EXISTING TEAM',
            onTap: joinState.isLoading
                ? null
                : () => context.push('/tournament/${tournament.id}/join-team'),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              tournament.isScramble
                  ? 'Scramble teams take 2–4 players. Create one and your teammates can join from the tournament page.'
                  : 'Already have a partner? Register together. Or join a team your partner created.',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.4),
            ),
          ),
        ],
      );
}

// ── Register button ───────────────────────────────────────────────────────────
class _RegisterButton extends ConsumerWidget {
  final TournamentModel tournament;
  final AsyncValue<void> joinState;
  const _RegisterButton(
      {required this.tournament, required this.joinState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tournament;
    return GestureDetector(
      onTap: t.isFull || joinState.isLoading
          ? null
          : () => _join(context, ref),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: t.isFull
              ? AppColors.divider
              : const Color(0xFF1B3D2C),
          borderRadius: BorderRadius.circular(16),
          boxShadow: t.isFull
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF1B3D2C).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: joinState.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.how_to_reg_outlined,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    t.isFull
                        ? 'TOURNAMENT FULL'
                        : 'REGISTER NOW  ·  \$${t.signUpFee.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ]),
        ),
      ),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    // Pay-at-course confirmation. Until Stripe is wired up, joining reserves
    // a spot and records the player as owing the entry fee at check-in.
    final confirmed = await _confirmPayAtCourse(
      context,
      title: 'Confirm registration',
      fee: tournament.signUpFee,
      label: 'Tournament entry',
    );
    if (!confirmed || !context.mounted) return;

    final ok =
        await ref.read(joinTournamentProvider.notifier).join(tournament.id);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text('You\'re in — pay \$${tournament.signUpFee.toStringAsFixed(0)} at the course.'),
          ),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      ref.invalidate(tournamentDetailProvider(tournament.id));
      ref.invalidate(participantsProvider(tournament.id));
      ref.invalidate(myTournamentsProvider);
      ref.invalidate(tournamentsProvider);
    } else {
      final err = ref.read(joinTournamentProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err?.toString() ?? 'Failed to register'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }
}

// ── Enter Score button ────────────────────────────────────────────────────────
class _EnterScoreButton extends StatelessWidget {
  final String tournamentId;
  const _EnterScoreButton({required this.tournamentId});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/tournament/$tournamentId/score'),
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B3D2C), Color(0xFF3D7055)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B3D2C).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sports_golf, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Text(
            'ENTER SCORE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ]),
      ),
    ),
  );
}

// ── Button helpers ────────────────────────────────────────────────────────────
class _FilledButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _FilledButton(
      {required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: onTap == null
              ? AppColors.divider
              : const Color(0xFF1B3D2C),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              )),
        ]),
      ));
}

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _OutlineButton(
      {required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF1B3D2C), width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: const Color(0xFF1B3D2C), size: 20),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                color: Color(0xFF1B3D2C),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              )),
        ]),
      ));
}

// ── Skins card ────────────────────────────────────────────────────────────────
class _SkinsCard extends ConsumerWidget {
  final TournamentModel tournament;
  const _SkinsCard({required this.tournament});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t          = tournament;
    final skinsState = ref.watch(enterSkinsProvider);
    final alreadyIn  = t.mySkinsEntry;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC9A84C).withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFC9A84C).withOpacity(0.10),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              const Text('🃏', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Optional skins side game',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (alreadyIn)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('ENTERED',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: AppColors.success, letterSpacing: 1,
                      )),
                ),
            ]),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              _SkinsStat(label: 'ENTRY FEE', value: '\$${t.skinsFee.toStringAsFixed(0)}'),
              _SkinsVDivider(),
              _SkinsStat(label: 'ENTRANTS', value: '${t.skinsCount}'),
              _SkinsVDivider(),
              _SkinsStat(
                label: 'SKINS POT',
                value: '\$${t.skinsPot.toStringAsFixed(0)}',
                gold: true,
              ),
            ]),
          ),

          // Description
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'Compete hole-by-hole for a share of the skins pot. Low net score wins each hole.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
            ),
          ),

          // Enter button (only if upcoming & not already in)
          if (t.isUpcoming && !alreadyIn)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GestureDetector(
                onTap: skinsState.isLoading ? null : () => _enter(context, ref),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A84C),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC9A84C).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: skinsState.isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Text(
                            'ENTER SKINS  ·  \$${t.skinsFee.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _enter(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirmPayAtCourse(
      context,
      title: 'Enter skins game',
      fee: tournament.skinsFee,
      label: 'Skins entry fee',
    );
    if (!confirmed || !context.mounted) return;

    final ok = await ref.read(enterSkinsProvider.notifier).enter(tournament.id);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Text('🃏', style: TextStyle(fontSize: 16)),
          SizedBox(width: 10),
          Text("You're in the skins game!"),
        ]),
        backgroundColor: const Color(0xFFC9A84C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      ref.invalidate(tournamentDetailProvider(tournament.id));
    } else {
      final err = ref.read(enterSkinsProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err?.toString() ?? 'Failed to enter skins'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }
}

class _SkinsStat extends StatelessWidget {
  final String label, value;
  final bool gold;
  const _SkinsStat({required this.label, required this.value, this.gold = false});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(label,
              style: const TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                letterSpacing: 1.5, color: AppColors.textSecondary,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900,
                color: gold ? const Color(0xFFC9A84C) : AppColors.textPrimary,
              )),
        ]),
      );
}

class _SkinsVDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      height: 32, width: 1, color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 8));
}

// ── Participants ──────────────────────────────────────────────────────────────
class _ParticipantsCard extends ConsumerWidget {
  final String tournamentId;
  const _ParticipantsCard({required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(participantsProvider(tournamentId));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
            ),
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Couldn\'t load players',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
        data: (players) {
          if (players.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No players signed up yet — be the first.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            );
          }
          return SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: players.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => _PlayerChip(player: players[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final TournamentParticipant player;
  const _PlayerChip({required this.player});

  String get _initials {
    final parts = player.name.trim().split(RegExp(r'\s+'));
    final letters = parts
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return letters.isEmpty ? '?' : letters;
  }

  @override
  Widget build(BuildContext context) {
    final url = player.profilePictureUrl;
    return GestureDetector(
      onTap: () => context.push('/player/${player.id}'),
      child: SizedBox(
        width: 64,
        child: Column(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.10),
              border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: (url != null && url.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _InitialsAvatar(initials: _initials),
                    placeholder: (_, __) => Container(color: AppColors.divider.withOpacity(0.3)),
                  )
                : _InitialsAvatar(initials: _initials),
          ),
          const SizedBox(height: 6),
          Text(
            player.name.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (player.handicap != null)
            Text(
              'HC ${player.handicap!.toStringAsFixed(player.handicap! % 1 == 0 ? 0 : 1)}',
              style: const TextStyle(
                  fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
        ]),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          initials,
          style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 16),
        ),
      );
}
