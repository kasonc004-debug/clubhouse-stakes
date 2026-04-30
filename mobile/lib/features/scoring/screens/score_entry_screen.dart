import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_button.dart';
import '../providers/score_provider.dart';

// Standard par for each hole (typical 18-hole course)
const List<int> _pars = [4, 4, 3, 4, 5, 3, 4, 4, 5, 4, 3, 4, 5, 4, 3, 4, 5, 4];

class ScoreEntryScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const ScoreEntryScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends ConsumerState<ScoreEntryScreen> {
  final List<int?> _scores = List.filled(18, null);
  int _currentHole = 0;

  int get _gross => _scores.where((s) => s != null).fold(0, (a, b) => a + b!);
  bool get _allFilled => _scores.every((s) => s != null);

  void _setScore(int score) {
    setState(() { _scores[_currentHole] = score; });
    if (_currentHole < 17) {
      setState(() => _currentHole++);
    }
  }

  Future<void> _submit() async {
    if (!_allFilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 18 holes'), backgroundColor: AppColors.warning));
      return;
    }
    final ok = await ref.read(scoreNotifierProvider.notifier).submit(
      tournamentId: widget.tournamentId,
      holeScores:   _scores.map((s) => s!).toList(),
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scorecard submitted!'), backgroundColor: AppColors.success));
      ref.invalidate(myScoreProvider(widget.tournamentId));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(scoreNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Scorecard'),
        actions: [
          if (_allFilled)
            TextButton(
              onPressed: _submit,
              child: const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Score summary bar
          Container(
            color: AppColors.primaryLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              _SummaryPill('Gross', _gross.toString()),
              const SizedBox(width: 16),
              _SummaryPill('Holes', '${_scores.where((s) => s != null).length}/18'),
              const SizedBox(width: 16),
              _SummaryPill('Remaining', '${_scores.where((s) => s == null).length}'),
            ]),
          ),

          // Hole mini-grid
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: 18,
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => setState(() => _currentHole = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38, height: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _currentHole == i
                        ? AppColors.primary
                        : _scores[i] != null
                            ? _scoreColor(_scores[i]!, _pars[i]).withOpacity(0.15)
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _currentHole == i ? AppColors.primary : AppColors.divider,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${i + 1}', style: TextStyle(
                          fontSize: 10,
                          color: _currentHole == i ? Colors.white : AppColors.textSecondary,
                        )),
                        Text(
                          _scores[i]?.toString() ?? '-',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _currentHole == i
                                ? Colors.white
                                : _scores[i] != null
                                    ? _scoreColor(_scores[i]!, _pars[i])
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Current hole entry
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Hole ${_currentHole + 1}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    Text('Par ${_pars[_currentHole]}',
                      style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                  ]),
                  const SizedBox(height: 8),
                  if (_scores[_currentHole] != null)
                    _ScoreBadge(score: _scores[_currentHole]!, par: _pars[_currentHole]),
                  const SizedBox(height: 24),

                  // Score buttons: 1–10
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: List.generate(10, (i) {
                      final score = i + 1;
                      final diff  = score - _pars[_currentHole];
                      final color = _scoreColor(score, _pars[_currentHole]);
                      return GestureDetector(
                        onTap: () => _setScore(score),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: _scores[_currentHole] == score
                                ? color
                                : color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _scores[_currentHole] == score ? color : color.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(score.toString(),
                                style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800,
                                  color: _scores[_currentHole] == score ? Colors.white : color,
                                )),
                              Text(_scoreName(diff),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _scores[_currentHole] == score ? Colors.white70 : color.withOpacity(0.7),
                                )),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),

                  // Navigation
                  Row(children: [
                    if (_currentHole > 0)
                      Expanded(child: CSButton(
                        label: '← Hole $_currentHole',
                        outlined: true,
                        onPressed: () => setState(() => _currentHole--),
                      )),
                    if (_currentHole > 0) const SizedBox(width: 10),
                    if (_currentHole < 17)
                      Expanded(child: CSButton(
                        label: 'Hole ${_currentHole + 2} →',
                        onPressed: () => setState(() => _currentHole++),
                      )),
                    if (_currentHole == 17 && _allFilled)
                      Expanded(child: CSButton(
                        label: 'Submit Scorecard',
                        loading: submitState.isLoading,
                        onPressed: _submit,
                        color: AppColors.gold,
                      )),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score, int par) {
    final diff = score - par;
    if (diff <= -2) return AppColors.eagle;
    if (diff == -1) return AppColors.birdie;
    if (diff == 0)  return AppColors.par;
    if (diff == 1)  return AppColors.bogey;
    return AppColors.error;
  }

  String _scoreName(int diff) {
    return switch (diff) {
      <= -2 => 'Eagle',
      -1    => 'Birdie',
      0     => 'Par',
      1     => 'Bogey',
      2     => 'Dbl Bogey',
      _     => '+$diff',
    };
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryPill(this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text('$label: ', style: const TextStyle(color: Colors.white70, fontSize: 12)),
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
  ]);
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  final int par;
  const _ScoreBadge({required this.score, required this.par});

  @override
  Widget build(BuildContext context) {
    final diff  = score - par;
    final label = switch (diff) {
      <= -2 => '🦅 Eagle',
      -1    => '🐦 Birdie',
      0     => '⛳ Par',
      1     => '📍 Bogey',
      2     => 'Double Bogey',
      _     => '+$diff',
    };
    return Text(label, style: const TextStyle(fontSize: 16, color: AppColors.textSecondary));
  }
}
