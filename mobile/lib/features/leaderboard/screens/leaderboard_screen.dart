import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../models/leaderboard_model.dart';
import '../providers/leaderboard_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  final String tournamentId;
  const LeaderboardScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider(tournamentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(leaderboardProvider(tournamentId)),
          ),
        ],
      ),
      body: leaderboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error:   (e, _) => ErrorCard(
            message: e.toString(),
            onRetry: () => ref.invalidate(leaderboardProvider(tournamentId))),
        data: (data) {
          if (data.individual.isEmpty && data.fourball.isEmpty) {
            return const EmptyState(
              icon: Icons.leaderboard_outlined,
              title: 'No scores yet',
              subtitle: 'Scores will appear here once players submit their cards.',
            );
          }
          if (data.format == 'individual') {
            return _IndividualLeaderboard(entries: data.individual);
          }
          return _FourballLeaderboard(entries: data.fourball);
        },
      ),
    );
  }
}

// ── Individual ───────────────────────────────────────────────
class _IndividualLeaderboard extends StatelessWidget {
  final List<IndividualEntry> entries;
  const _IndividualLeaderboard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        color: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: const Row(children: [
          SizedBox(width: 36, child: Text('#', style: TextStyle(color: Colors.white70, fontSize: 12))),
          Expanded(child: Text('Player', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          SizedBox(width: 48, child: Center(child: Text('Gross', style: TextStyle(color: Colors.white70, fontSize: 12)))),
          SizedBox(width: 48, child: Center(child: Text('Net', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) => _IndividualRow(entry: entries[i]),
        ),
      ),
    ]);
  }
}

class _IndividualRow extends StatelessWidget {
  final IndividualEntry entry;
  const _IndividualRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final topThree = entry.rank <= 3;
    return ListTile(
      tileColor: topThree ? AppColors.gold.withOpacity(0.05) : null,
      leading: _RankBadge(rank: entry.rank),
      title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('HCP ${entry.handicap.toStringAsFixed(1)}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 48, child: Center(child: Text(entry.grossScore.toString(),
            style: const TextStyle(color: AppColors.textSecondary)))),
        SizedBox(width: 48, child: Center(child: Text(entry.netScore.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16,
                color: AppColors.primary)))),
      ]),
      onTap: entry.holeScores.isNotEmpty
          ? () => _showHoleScores(context, entry.name, entry.holeScores)
          : null,
    );
  }

  void _showHoleScores(BuildContext context, String name, List<int> scores) {
    const pars = [4,4,3,4,5,3,4,4,5,4,3,4,5,4,3,4,5,4];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        builder: (_, ctrl) => Column(children: [
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Hole-by-Hole Scores', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const Divider(),
          Expanded(
            child: GridView.builder(
              controller: ctrl,
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6, childAspectRatio: 1.2,
                crossAxisSpacing: 8, mainAxisSpacing: 8,
              ),
              itemCount: 18,
              itemBuilder: (_, i) {
                final score = scores[i];
                final diff  = score - pars[i];
                final color = switch (diff) {
                  <= -2 => AppColors.eagle,
                  -1    => AppColors.birdie,
                  0     => AppColors.par,
                  1     => AppColors.bogey,
                  _     => AppColors.error,
                };
                return Column(children: [
                  Text('${i+1}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Center(child: Text(score.toString(),
                      style: TextStyle(fontWeight: FontWeight.w700, color: color))),
                  ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Four-Ball ────────────────────────────────────────────────
class _FourballLeaderboard extends StatelessWidget {
  final List<FourballEntry> entries;
  const _FourballLeaderboard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: const Row(children: [
          SizedBox(width: 36, child: Text('#', style: TextStyle(color: Colors.white70, fontSize: 12))),
          Expanded(child: Text('Team', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          SizedBox(width: 64, child: Center(child: Text('Net Score',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) => _FourballRow(entry: entries[i]),
        ),
      ),
    ]);
  }
}

class _FourballRow extends StatelessWidget {
  final FourballEntry entry;
  const _FourballRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: entry.rank <= 3 ? AppColors.gold.withOpacity(0.05) : null,
      leading: _RankBadge(rank: entry.rank),
      title: Text(entry.teamName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        entry.players.map((p) => '${p.name} (${p.handicap.toStringAsFixed(1)})').join(' · '),
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      trailing: SizedBox(
        width: 64,
        child: Center(
          child: Text(entry.netTotal.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary)),
        ),
      ),
      onTap: () => _showTeamDetail(context, entry),
    );
  }

  void _showTeamDetail(BuildContext context, FourballEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.teamName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Net Total: ${entry.netTotal.toStringAsFixed(1)}',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              const Divider(height: 24),
              ...entry.players.map((p) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.person, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('HCP ${p.handicap.toStringAsFixed(1)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                  if (p.holeScores.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: List.generate(18, (i) => Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Center(child: Text(p.holeScores[i].toString(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      )),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final colors = {
      1: (AppColors.gold, Colors.white),
      2: (const Color(0xFFC0C0C0), Colors.white),
      3: (const Color(0xFFCD7F32), Colors.white),
    };
    final (bg, fg) = colors[rank] ?? (AppColors.background, AppColors.textPrimary);
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(child: Text(rank.toString(),
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 13))),
    );
  }
}
