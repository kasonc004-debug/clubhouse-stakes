import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/score_provider.dart';

const List<int> _pars = [4, 4, 3, 4, 5, 3, 4, 4, 5, 4, 3, 4, 5, 4, 3, 4, 5, 4];

Color _holeColor(int score, int par) {
  final d = score - par;
  if (d <= -2) return const Color(0xFF7B1FA2);
  if (d == -1) return const Color(0xFF1565C0);
  if (d == 0) return const Color(0xFF1B3D2C);
  if (d == 1) return AppColors.warning;
  return AppColors.error;
}

String _holeName(int diff) => switch (diff) {
      <= -2 => 'Eagle',
      -1 => 'Birdie',
      0 => 'Par',
      1 => 'Bogey',
      2 => 'Dbl Bogey',
      _ => '+$diff',
    };

class ScoreEntryScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const ScoreEntryScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends ConsumerState<ScoreEntryScreen> {
  List<int?> _scores = List.filled(18, null);
  int _currentHole = 0;
  bool _loaded = false;
  bool _saving = false;

  int get _gross => _scores.whereType<int>().fold(0, (a, b) => a + b);
  int get _holesIn => _scores.whereType<int>().length;
  bool get _allFilled => _scores.every((s) => s != null);

  int get _firstUnfilled {
    for (var i = 0; i < 18; i++) {
      if (_scores[i] == null) return i;
    }
    return 18;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  Future<void> _loadExisting() async {
    try {
      final entry =
          await ref.read(myScoreProvider(widget.tournamentId).future);
      if (!mounted) return;
      if (entry != null && entry.holeScores.isNotEmpty) {
        final loaded = List<int?>.filled(18, null);
        for (var i = 0; i < entry.holeScores.length && i < 18; i++) {
          if (entry.holeScores[i] > 0) loaded[i] = entry.holeScores[i];
        }
        setState(() {
          _scores = loaded;
          _currentHole = _firstUnfilled.clamp(0, 17);
          _loaded = true;
        });
        return;
      }
    } catch (_) {
      // start fresh
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _confirmScore(int score) async {
    if (_saving) return;
    final wasAtFrontier = _currentHole == _firstUnfilled;
    final savedHole     = _currentHole;
    final prevScore     = _scores[_currentHole];

    setState(() {
      _scores[_currentHole] = score;
      _saving = true;
    });

    final ok = await ref.read(holeUpdateProvider.notifier).update(
          tournamentId: widget.tournamentId,
          holeNumber: savedHole + 1,
          score: score,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      // Revert the local score and show the error
      setState(() => _scores[savedHole] = prevScore);
      final err = ref.read(holeUpdateProvider).error?.toString() ??
          'Could not save — is this tournament active?';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Hole ${savedHole + 1}: $err'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    // Auto-advance only when filling the current frontier hole
    if (wasAtFrontier && _firstUnfilled < 18) {
      await Future.delayed(const Duration(milliseconds: 280));
      if (mounted) setState(() => _currentHole = _firstUnfilled.clamp(0, 17));
    }
  }

  void _finishScoring() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle, color: Colors.white, size: 18),
        SizedBox(width: 10),
        Text('Scorecard complete!'),
      ]),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    ref.invalidate(myScoreProvider(widget.tournamentId));
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
          title: const Text('Live Scoring',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final holeScore = _scores[_currentHole];
    final par = _pars[_currentHole];
    // Can advance to next hole only if current hole has a score
    final canNext = _currentHole < 17 && holeScore != null;
    // Submit available as soon as all 18 holes are filled
    final showFinish = _allFilled;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          _ScoreHeader(
            currentHole: _currentHole,
            gross: _gross,
            holesIn: _holesIn,
            saving: _saving,
            onBack: () => context.pop(),
          ),

          // ── Hole navigation grid ─────────────────────────────
          _HoleGrid(
            scores: _scores,
            currentHole: _currentHole,
            firstUnfilled: _firstUnfilled,
            onTap: (i) => setState(() => _currentHole = i),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // ── Finish banner (all holes done) ───────────────────
          if (showFinish)
            GestureDetector(
              onTap: _finishScoring,
              child: Container(
                color: const Color(0xFF1B3D2C),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'ALL 18 HOLES COMPLETE — TAP TO FINISH',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Active hole entry ────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                children: [
                  // Hole title + par + badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HOLE ${_currentHole + 1}',
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary),
                            ),
                            Text('Par $par',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600)),
                          ]),
                      if (holeScore != null)
                        _ScoreBadge(score: holeScore, par: par),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Score buttons 1–10
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: List.generate(10, (i) {
                      final s = i + 1;
                      final color = _holeColor(s, par);
                      final picked = holeScore == s;
                      return GestureDetector(
                        onTap: _saving ? null : () => _confirmScore(s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: picked
                                ? color
                                : color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: picked
                                  ? color
                                  : color.withOpacity(0.30),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$s',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: picked
                                          ? Colors.white
                                          : color)),
                              Text(
                                _holeName(s - par),
                                style: TextStyle(
                                    fontSize: 9,
                                    color: picked
                                        ? Colors.white70
                                        : color.withOpacity(0.7)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 28),

                  // Navigation
                  Row(children: [
                    if (_currentHole > 0) ...[
                      Expanded(
                        child: _NavButton(
                          label: '← Hole $_currentHole',
                          outlined: true,
                          onTap: () =>
                              setState(() => _currentHole--),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (_currentHole < 17)
                      Expanded(
                        child: _NavButton(
                          label: 'Hole ${_currentHole + 2} →',
                          onTap: canNext
                              ? () => setState(() => _currentHole++)
                              : null,
                          hint: holeScore == null
                              ? 'Enter hole ${_currentHole + 1} first'
                              : null,
                        ),
                      ),
                    if (_currentHole == 17 && !showFinish)
                      Expanded(
                        child: _NavButton(
                          label: 'Enter hole 18 to finish',
                          onTap: null,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (_currentHole == 17 && showFinish)
                      Expanded(
                        child: _NavButton(
                          label: '✓ Finish Scorecard',
                          onTap: _finishScoring,
                          color: const Color(0xFFC9A84C),
                        ),
                      ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _ScoreHeader extends StatelessWidget {
  final int currentHole, gross, holesIn;
  final bool saving;
  final VoidCallback onBack;
  const _ScoreHeader({
    required this.currentHole,
    required this.gross,
    required this.holesIn,
    required this.saving,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFF1B3D2C), Color(0xFF2A5940)]),
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 20, 16),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
              onPressed: onBack,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LIVE SCORING',
                        style: TextStyle(
                            color: Color(0xFFC9A84C),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2)),
                    Text('Hole ${currentHole + 1} of 18',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ]),
            ),
            if (saving)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFC9A84C))),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$holesIn / 18',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              Text(gross > 0 ? '$gross gross' : '—',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Hole grid ─────────────────────────────────────────────────────────────────
class _HoleGrid extends StatelessWidget {
  final List<int?> scores;
  final int currentHole, firstUnfilled;
  final ValueChanged<int> onTap;
  const _HoleGrid({
    required this.scores,
    required this.currentHole,
    required this.firstUnfilled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: 18,
        itemBuilder: (context, i) {
          final isCurrent = i == currentHole;
          final rawScore = scores[i];
          final isFilled = rawScore != null;
          final isLocked = i > firstUnfilled;
          final par = _pars[i];

          Color bg, borderColor;
          if (isCurrent) {
            bg = const Color(0xFF1B3D2C);
            borderColor = const Color(0xFF1B3D2C);
          } else if (isFilled) {
            bg = AppColors.success.withOpacity(0.12);
            borderColor = AppColors.success.withOpacity(0.4);
          } else if (isLocked) {
            bg = AppColors.background;
            borderColor = AppColors.divider.withOpacity(0.4);
          } else {
            bg = AppColors.background;
            borderColor = AppColors.divider;
          }

          Color scoreTextColor;
          if (isCurrent) {
            scoreTextColor = Colors.white;
          } else if (isFilled) {
            scoreTextColor = _holeColor(rawScore, par);
          } else if (isLocked) {
            scoreTextColor = AppColors.divider;
          } else {
            scoreTextColor = AppColors.textSecondary;
          }

          return GestureDetector(
            onTap: isLocked ? null : () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child:
                    Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 9,
                          color: isCurrent
                              ? Colors.white60
                              : isLocked
                                  ? AppColors.divider
                                  : AppColors.textSecondary)),
                  Text(
                      isFilled
                          ? '$rawScore'
                          : (isLocked ? '·' : '-'),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: scoreTextColor)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Score badge ───────────────────────────────────────────────────────────────
class _ScoreBadge extends StatelessWidget {
  final int score, par;
  const _ScoreBadge({required this.score, required this.par});

  @override
  Widget build(BuildContext context) {
    final diff = score - par;
    final label = switch (diff) {
      <= -2 => '🦅 Eagle',
      -1 => '🐦 Birdie',
      0 => '⛳ Par',
      1 => '📍 Bogey',
      2 => 'Double Bogey',
      _ => '+$diff',
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Nav button ────────────────────────────────────────────────────────────────
class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool outlined, loading;
  final Color? color;
  final String? hint;
  const _NavButton({
    required this.label,
    this.onTap,
    this.outlined = false,
    this.loading = false,
    this.color,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? const Color(0xFF1B3D2C);
    final enabled = onTap != null && !loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 52,
            decoration: BoxDecoration(
              color: outlined
                  ? Colors.transparent
                  : enabled
                      ? bg
                      : bg.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
              border: outlined
                  ? Border.all(
                      color: const Color(0xFF1B3D2C), width: 1.5)
                  : null,
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text(label,
                      style: TextStyle(
                          color: outlined
                              ? const Color(0xFF1B3D2C)
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
            ),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 5),
          Text(hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}
