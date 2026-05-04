import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../teams/models/team_model.dart';
import '../providers/score_provider.dart';
import 'score_entry_screen.dart' show holeColor, holeName;

/// Designated scorer's hole-by-hole entry screen for fourball.
/// Enters scores for every teammate one hole at a time.
class TeamScoreEntryScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final TeamModel team;
  final List<int> pars;
  final List<int>? yardages;

  const TeamScoreEntryScreen({
    super.key,
    required this.tournamentId,
    required this.team,
    required this.pars,
    this.yardages,
  });

  @override
  ConsumerState<TeamScoreEntryScreen> createState() => _TeamScoreEntryScreenState();
}

class _TeamScoreEntryScreenState extends ConsumerState<TeamScoreEntryScreen> {
  // playerId → list of 18 nullable scores
  final Map<String, List<int?>> _scores = {};
  int _currentHole = 0;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from team payload (backend includes each member's hole_scores).
    for (final m in widget.team.members) {
      final init = List<int?>.filled(18, null);
      for (var i = 0; i < m.holeScores.length && i < 18; i++) {
        if (m.holeScores[i] > 0) init[i] = m.holeScores[i];
      }
      _scores[m.id] = init;
    }
    _currentHole = _firstUnfilled().clamp(0, 17);
    _loaded = true;
  }

  int _firstUnfilled() {
    for (var i = 0; i < 18; i++) {
      if (widget.team.members.any((m) => _scores[m.id]![i] == null)) return i;
    }
    return 18;
  }

  bool _holeAllFilled(int h) =>
      widget.team.members.every((m) => _scores[m.id]![h] != null);

  bool get _allComplete => List.generate(18, _holeAllFilled).every((b) => b);

  int _grossFor(String id) =>
      _scores[id]!.whereType<int>().fold(0, (a, b) => a + b);

  Future<void> _setScore(String userId, int score) async {
    if (_saving) return;
    final wasAtFrontier = _currentHole == _firstUnfilled();
    final prev = _scores[userId]![_currentHole];
    setState(() {
      _scores[userId]![_currentHole] = score;
      _saving = true;
    });

    final ok = await ref.read(holeUpdateProvider.notifier).update(
          tournamentId: widget.tournamentId,
          holeNumber: _currentHole + 1,
          score: score,
          targetUserId: userId,
        );

    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      setState(() => _scores[userId]![_currentHole] = prev);
      final err = ref.read(holeUpdateProvider).error?.toString() ??
          'Could not save — is this tournament active?';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Hole ${_currentHole + 1}: $err'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    if (wasAtFrontier && _holeAllFilled(_currentHole)) {
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      final next = _firstUnfilled();
      if (next < 18) setState(() => _currentHole = next);
    }
  }

  void _finish() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Team scorecard complete!'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1B3D2C),
          foregroundColor: Colors.white,
          title: const Text('Team Scoring',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final par = widget.pars[_currentHole];
    final firstUnfilled = _firstUnfilled();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        // Header
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF1B3D2C), Color(0xFF2A5940)]),
            borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(20)),
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
                        const Text('TEAM SCORING',
                            style: TextStyle(
                                color: Color(0xFFC9A84C),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2)),
                        Text(
                          widget.team.displayName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800),
                        ),
                      ]),
                ),
                if (_saving)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFC9A84C))),
              ]),
            ),
          ),
        ),

        // Hole strip
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: 18,
            itemBuilder: (_, i) {
              final isCurrent = i == _currentHole;
              final isLocked = i > firstUnfilled;
              final allIn = _holeAllFilled(i);
              return GestureDetector(
                onTap: isLocked ? null : () => setState(() => _currentHole = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? const Color(0xFF1B3D2C)
                        : allIn
                            ? AppColors.success.withOpacity(0.14)
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isCurrent
                            ? const Color(0xFF1B3D2C)
                            : allIn
                                ? AppColors.success.withOpacity(0.4)
                                : AppColors.divider),
                  ),
                  child: Center(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: isCurrent
                                      ? Colors.white60
                                      : AppColors.textSecondary)),
                          Text(allIn ? '✓' : (isLocked ? '·' : '–'),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isCurrent
                                      ? Colors.white
                                      : allIn
                                          ? AppColors.success
                                          : AppColors.textSecondary)),
                        ]),
                  ),
                ),
              );
            },
          ),
        ),

        const Divider(height: 1, color: AppColors.divider),

        // Finish banner
        if (_allComplete)
          GestureDetector(
            onTap: _finish,
            child: Container(
              color: const Color(0xFF1B3D2C),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'TEAM SCORECARD COMPLETE — TAP TO FINISH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Hole header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Row(children: [
            Text('HOLE ${_currentHole + 1}',
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Par $par',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
            if (widget.yardages != null &&
                _currentHole < widget.yardages!.length &&
                widget.yardages![_currentHole] > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text('${widget.yardages![_currentHole]} yds',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary)),
              ),
            ],
          ]),
        ),

        // Per-player score entry blocks
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: widget.team.members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) {
              final m = widget.team.members[i];
              final score = _scores[m.id]![_currentHole];
              return _PlayerHoleEntry(
                name: m.name,
                handicap: m.handicap,
                par: par,
                score: score,
                gross: _grossFor(m.id),
                onPick: _saving ? null : (s) => _setScore(m.id, s),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _PlayerHoleEntry extends StatelessWidget {
  final String name;
  final double handicap;
  final int par;
  final int? score;
  final int gross;
  final void Function(int)? onPick;

  const _PlayerHoleEntry({
    required this.name,
    required this.handicap,
    required this.par,
    required this.score,
    required this.gross,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              Text('HCP ${handicap.toStringAsFixed(1)} · Gross ${gross == 0 ? '—' : gross}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ),
          if (score != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: holeColor(score!, par).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: holeColor(score!, par).withOpacity(0.4)),
              ),
              child: Text(holeName(score! - par),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: holeColor(score!, par))),
            ),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(10, (i) {
            final s = i + 1;
            final color = holeColor(s, par);
            final picked = score == s;
            return GestureDetector(
              onTap: onPick == null ? null : () => onPick!(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 110),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: picked ? color : color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: picked ? color : color.withOpacity(0.30),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text('$s',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: picked ? Colors.white : color)),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}
