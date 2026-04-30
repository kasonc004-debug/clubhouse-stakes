import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../providers/admin_provider.dart';

const List<int> _pars = [4, 4, 3, 4, 5, 3, 4, 4, 5, 4, 3, 4, 5, 4, 3, 4, 5, 4];

class AdminScoresScreen extends ConsumerWidget {
  final String tournamentId;
  final String tournamentName;
  const AdminScoresScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync =
        ref.watch(adminParticipantsProvider(tournamentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(tournamentName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(adminParticipantsProvider(tournamentId)),
          ),
        ],
      ),
      body: participantsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => ErrorCard(
            message: e.toString(),
            onRetry: () =>
                ref.invalidate(adminParticipantsProvider(tournamentId))),
        data: (participants) {
          if (participants.isEmpty) {
            return const EmptyState(
              icon: Icons.person_outline,
              title: 'No participants',
              subtitle: 'Players will appear here once they register.',
            );
          }
          return Column(
            children: [
              _ScoreHeader(),
              Expanded(
                child: ListView.separated(
                  itemCount: participants.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _ParticipantRow(
                    participant: participants[i],
                    tournamentId: tournamentId,
                    onSaved: () =>
                        ref.invalidate(adminParticipantsProvider(tournamentId)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(children: [
        Expanded(
            child: Text('Player',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
        SizedBox(
            width: 52,
            child: Center(
                child: Text('Gross',
                    style: TextStyle(color: Colors.white70, fontSize: 12)))),
        SizedBox(
            width: 52,
            child: Center(
                child: Text('Net',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)))),
        SizedBox(width: 40),
      ]),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final Map<String, dynamic> participant;
  final String tournamentId;
  final VoidCallback onSaved;

  const _ParticipantRow({
    required this.participant,
    required this.tournamentId,
    required this.onSaved,
  });

  bool get _hasScore => participant['gross_score'] != null;

  List<int> get _currentScores {
    final raw = participant['hole_scores'];
    if (raw == null) return List.filled(18, 0);
    if (raw is List) return raw.map((e) => (e as num).toInt()).toList();
    return List.filled(18, 0);
  }

  @override
  Widget build(BuildContext context) {
    final name  = participant['name'] as String? ?? 'Unknown';
    final gross = participant['gross_score'];
    final net   = participant['net_score'];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _hasScore
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.grey.shade200,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _hasScore ? AppColors.primary : Colors.grey,
          ),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        _hasScore ? 'Score submitted' : 'No score yet',
        style: TextStyle(
          fontSize: 12,
          color: _hasScore ? AppColors.primary : Colors.grey,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasScore) ...[
            SizedBox(
              width: 52,
              child: Center(
                child: Text(gross.toString(),
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            ),
            SizedBox(
              width: 52,
              child: Center(
                child: Text(
                  net?.toString() ?? '-',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(width: 104),
          ],
          SizedBox(
            width: 40,
            child: IconButton(
              icon: Icon(
                _hasScore ? Icons.edit_outlined : Icons.add_circle_outline,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: () => _openEditor(context),
            ),
          ),
        ],
      ),
      onTap: _hasScore ? () => _openEditor(context) : null,
    );
  }

  void _openEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ScoreEditorSheet(
        participant: participant,
        tournamentId: tournamentId,
        initialScores: _currentScores,
        onSaved: () {
          Navigator.of(ctx).pop();
          onSaved();
        },
      ),
    );
  }
}

// ── Score Editor Bottom Sheet ─────────────────────────────────────────────────

class _ScoreEditorSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> participant;
  final String tournamentId;
  final List<int> initialScores;
  final VoidCallback onSaved;

  const _ScoreEditorSheet({
    required this.participant,
    required this.tournamentId,
    required this.initialScores,
    required this.onSaved,
  });

  @override
  ConsumerState<_ScoreEditorSheet> createState() => _ScoreEditorSheetState();
}

class _ScoreEditorSheetState extends ConsumerState<_ScoreEditorSheet> {
  late List<int?> _scores;
  int _currentHole = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialScores;
    _scores = List.generate(18, (i) {
      final v = initial.length > i ? initial[i] : 0;
      return v > 0 ? v : null;
    });
    // Jump to first empty hole if editing existing score
    final firstEmpty = _scores.indexWhere((s) => s == null);
    if (firstEmpty >= 0) _currentHole = firstEmpty;
  }

  int get _gross => _scores.whereType<int>().fold(0, (a, b) => a + b);
  bool get _allFilled => _scores.every((s) => s != null);
  int get _filledCount => _scores.whereType<int>().length;

  void _setScore(int score) {
    setState(() {
      _scores[_currentHole] = score;
      if (_currentHole < 17) _currentHole++;
    });
  }

  Future<void> _save() async {
    if (!_allFilled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('All 18 holes required'),
          backgroundColor: AppColors.warning));
      return;
    }
    final entryId = widget.participant['entry_id']?.toString() ?? '';
    final ok = await ref
        .read(adminScoreProvider(entryId).notifier)
        .updateScore(
          widget.tournamentId,
          entryId,
          _scores.map((s) => s!).toList(),
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Score saved'),
          backgroundColor: AppColors.primary));
      widget.onSaved();
    } else {
      final err = ref.read(adminScoreProvider(entryId)).error?.toString() ??
          'Failed to save';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red));
    }
  }

  Color _scoreColor(int score, int par) {
    final d = score - par;
    if (d <= -2) return AppColors.eagle;
    if (d == -1) return AppColors.birdie;
    if (d == 0)  return AppColors.par;
    if (d == 1)  return AppColors.bogey;
    return AppColors.error;
  }

  String _scoreName(int diff) => switch (diff) {
        <= -2 => 'Eagle',
        -1    => 'Birdie',
        0     => 'Par',
        1     => 'Bogey',
        2     => 'Dbl',
        _     => '+$diff',
      };

  @override
  Widget build(BuildContext context) {
    final name    = widget.participant['name'] as String? ?? 'Player';
    final saving  = ref
        .watch(adminScoreProvider(
            widget.participant['entry_id']?.toString() ?? ''))
        .isLoading;
    final par     = _pars[_currentHole];
    final current = _scores[_currentHole];

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 8),
          Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('$_filledCount of 18 holes entered · Gross $_gross',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
              if (_allFilled)
                TextButton(
                  onPressed: saving ? null : _save,
                  child: saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))
                      : const Text('SAVE',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 15)),
                ),
            ]),
          ),
          const SizedBox(height: 8),

          // Hole mini-strip
          SizedBox(
            height: 58,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: 18,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _currentHole = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 36, height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  decoration: BoxDecoration(
                    color: _currentHole == i
                        ? AppColors.primary
                        : _scores[i] != null
                            ? _scoreColor(_scores[i]!, _pars[i])
                                .withValues(alpha: 0.12)
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _currentHole == i
                          ? AppColors.primary
                          : AppColors.divider,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 9,
                              color: _currentHole == i
                                  ? Colors.white70
                                  : AppColors.textSecondary)),
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
          const Divider(height: 1),

          // Current hole
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Hole ${_currentHole + 1}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  Text('Par $par',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                  if (current != null)
                    _ScoreLabel(score: current, par: par),
                ]),
          ),
          const SizedBox(height: 12),

          // Score buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(10, (i) {
                final s    = i + 1;
                final diff = s - par;
                final col  = _scoreColor(s, par);
                final sel  = current == s;
                return GestureDetector(
                  onTap: () => _setScore(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: sel ? col : col.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? col : col.withValues(alpha: 0.3),
                          width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.toString(),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: sel ? Colors.white : col)),
                        Text(_scoreName(diff),
                            style: TextStyle(
                                fontSize: 8,
                                color: sel
                                    ? Colors.white70
                                    : col.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          // Prev / Next
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(children: [
              if (_currentHole > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentHole--),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        minimumSize: const Size(0, 44)),
                    child: Text('← Hole $_currentHole'),
                  ),
                ),
              if (_currentHole > 0 && _currentHole < 17)
                const SizedBox(width: 12),
              if (_currentHole < 17)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _currentHole++),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44)),
                    child: Text('Hole ${_currentHole + 2} →'),
                  ),
                ),
              if (_currentHole == 17 && _allFilled) ...[
                if (_currentHole > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        minimumSize: const Size(0, 44)),
                    child: saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Scorecard'),
                  ),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _ScoreLabel extends StatelessWidget {
  final int score;
  final int par;
  const _ScoreLabel({required this.score, required this.par});

  @override
  Widget build(BuildContext context) {
    final diff = score - par;
    final label = switch (diff) {
      <= -2 => 'Eagle',
      -1    => 'Birdie',
      0     => 'Par',
      1     => 'Bogey',
      2     => 'Double Bogey',
      _     => '+$diff',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary)),
    );
  }
}
