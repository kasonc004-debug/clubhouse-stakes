import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_button.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../models/team_model.dart';
import '../providers/team_provider.dart';

class JoinTeamScreen extends ConsumerWidget {
  final String tournamentId;
  const JoinTeamScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamsProvider((tournamentId: tournamentId, openOnly: true)));
    final joinState  = ref.watch(joinTeamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Join a Team')),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error:   (e, _) => ErrorCard(message: e.toString(),
            onRetry: () => ref.invalidate(teamsProvider((tournamentId: tournamentId, openOnly: true)))),
        data: (teams) {
          if (teams.isEmpty) {
            return const EmptyState(
              icon: Icons.group_off,
              title: 'No open teams',
              subtitle: 'All teams are full. Create your own team instead.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: teams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _TeamTile(
              team:       teams[i],
              joining:    joinState.isLoading,
              onJoin:     () => _join(context, ref, teams[i].id),
            ),
          );
        },
      ),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref, String teamId) async {
    final ok = await ref.read(joinTeamProvider.notifier).join(teamId);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined team!'), backgroundColor: AppColors.success));
      context.pop();
    } else if (context.mounted) {
      final err = ref.read(joinTeamProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err?.toString() ?? 'Failed to join'), backgroundColor: AppColors.error));
    }
  }
}

class _TeamTile extends StatelessWidget {
  final TeamModel team;
  final bool joining;
  final VoidCallback onJoin;

  const _TeamTile({required this.team, required this.joining, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(team.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              _SpotBadge(memberCount: team.memberCount),
            ]),
            if (team.members.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Current Members',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...team.members.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(m.name),
                  const Spacer(),
                  Text('HCP ${m.handicap.toStringAsFixed(1)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ]),
              )),
            ],
            const SizedBox(height: 14),
            CSButton(
              label: 'Join This Team',
              loading: joining,
              onPressed: onJoin,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotBadge extends StatelessWidget {
  final int memberCount;
  const _SpotBadge({required this.memberCount});

  @override
  Widget build(BuildContext context) {
    final full = memberCount >= 2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: full ? AppColors.error.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        full ? 'Full' : '1 Spot Left',
        style: TextStyle(
          color: full ? AppColors.error : AppColors.success,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
