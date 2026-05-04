import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../teams/models/team_model.dart';
import '../../teams/providers/team_provider.dart';
import 'score_entry_screen.dart' show holeColor;

/// Read-only view shown to fourball players who are NOT the designated scorer.
/// Polls the team endpoint so they can watch scores being entered live.
class TeamScoreViewScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final TeamModel team;
  final List<int> pars;
  final bool isScramble;

  const TeamScoreViewScreen({
    super.key,
    required this.tournamentId,
    required this.team,
    required this.pars,
    this.isScramble = false,
  });

  @override
  ConsumerState<TeamScoreViewScreen> createState() => _TeamScoreViewScreenState();
}

class _TeamScoreViewScreenState extends ConsumerState<TeamScoreViewScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15),
        (_) => ref.invalidate(myTeamProvider(widget.tournamentId)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(myTeamProvider(widget.tournamentId));
    final team = teamAsync.valueOrNull ?? widget.team;
    final scorer = team.scorer;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        // Header
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF1B3D2C), Color(0xFF2A5940)]),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 14),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LIVE TEAM CARD',
                          style: TextStyle(
                              color: Color(0xFFC9A84C),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      Text(team.displayName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  onPressed: () =>
                      ref.invalidate(myTeamProvider(widget.tournamentId)),
                ),
              ]),
            ),
          ),
        ),

        // Scorer banner
        Container(
          color: AppColors.primary.withOpacity(0.06),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                scorer != null
                    ? '${scorer.name} is keeping the team scorecard.'
                    : 'Your team scorer is keeping the card.',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary),
              ),
            ),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: widget.isScramble
                ? _ScrambleTeamCard(
                    scorer: scorer,
                    members: team.members,
                    pars: widget.pars,
                  )
                : Column(children: [
                    for (final m in team.members)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _PlayerCard(
                          member: m,
                          pars: widget.pars,
                          isScorer: team.scorerId == m.id,
                        ),
                      ),
                  ]),
          ),
        ),
      ]),
    );
  }
}

class _ScrambleTeamCard extends StatelessWidget {
  final TeamMemberModel? scorer;
  final List<TeamMemberModel> members;
  final List<int> pars;
  const _ScrambleTeamCard({
    required this.scorer,
    required this.members,
    required this.pars,
  });

  @override
  Widget build(BuildContext context) {
    final scores = scorer?.holeScores ?? const <int>[];
    final filled = scores.where((s) => s > 0).length;
    final gross = scores.fold<int>(0, (a, b) => a + b);
    final namesLine = members.map((m) => m.name).join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('TEAM SCORECARD',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(namesLine,
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
            'Thru $filled / 18 · Gross ${gross == 0 ? '—' : gross}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(18, (i) {
            final raw = i < scores.length ? scores[i] : 0;
            final entered = raw > 0;
            final color = entered ? holeColor(raw, pars[i]) : AppColors.divider;
            return Container(
              width: 32,
              height: 38,
              decoration: BoxDecoration(
                color: entered
                    ? color.withOpacity(0.14)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: entered
                        ? color.withOpacity(0.4)
                        : AppColors.divider),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 8,
                            color: AppColors.textSecondary)),
                    Text(entered ? '$raw' : '·',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: entered ? color : AppColors.textSecondary)),
                  ]),
            );
          }),
        ),
      ]),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final TeamMemberModel member;
  final List<int> pars;
  final bool isScorer;
  const _PlayerCard({
    required this.member,
    required this.pars,
    required this.isScorer,
  });

  @override
  Widget build(BuildContext context) {
    final scores = member.holeScores;
    final filled = scores.where((s) => s > 0).length;
    final gross = scores.fold<int>(0, (a, b) => a + b);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(member.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                if (isScorer) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9A84C).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('SCORER',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: Color(0xFFC9A84C))),
                  ),
                ],
              ]),
              Text('HCP ${member.handicap.toStringAsFixed(1)} · '
                  'Thru $filled / 18 · '
                  'Gross ${gross == 0 ? '—' : gross}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(18, (i) {
            final raw = i < scores.length ? scores[i] : 0;
            final entered = raw > 0;
            final color = entered ? holeColor(raw, pars[i]) : AppColors.divider;
            return Container(
              width: 30,
              height: 36,
              decoration: BoxDecoration(
                color: entered
                    ? color.withOpacity(0.13)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: entered
                        ? color.withOpacity(0.4)
                        : AppColors.divider),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 8,
                            color: AppColors.textSecondary)),
                    Text(entered ? '$raw' : '·',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: entered
                                ? color
                                : AppColors.textSecondary)),
                  ]),
            );
          }),
        ),
      ]),
    );
  }
}
