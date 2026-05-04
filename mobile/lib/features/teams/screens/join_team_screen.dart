import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_button.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../tournaments/providers/tournament_provider.dart';
import '../models/team_model.dart';
import '../providers/team_provider.dart';

class JoinTeamScreen extends ConsumerWidget {
  final String tournamentId;
  const JoinTeamScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync      = ref.watch(teamsProvider((tournamentId: tournamentId, openOnly: true)));
    final joinState       = ref.watch(joinTeamProvider);
    final tournamentAsync = ref.watch(tournamentDetailProvider(tournamentId));
    final teamCap = tournamentAsync.valueOrNull?.isScramble == true ? 4 : 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Join a Team')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(teamsProvider((tournamentId: tournamentId, openOnly: true)));
        },
        child: teamsAsync.when(
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
                teamCap:    teamCap,
                joining:    joinState.isLoading,
                onJoin:     () => _join(context, ref, teams[i].id),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref, String teamId) async {
    final t = ref.read(tournamentDetailProvider(tournamentId)).valueOrNull;
    if (t != null && t.signUpFee > 0 && t.feePer != 'team') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirm registration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tournament entry',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('\$${t.signUpFee.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Online payments aren\'t live yet. By confirming you join the team '
                'and agree to pay at check-in. The host will mark you as paid once '
                'they collect.',
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
      if (ok != true || !context.mounted) return;
    }

    final ok = await ref.read(joinTeamProvider.notifier).join(teamId);
    if (ok && context.mounted) {
      // Refresh every screen that lists this tournament's teams + roster.
      ref.invalidate(teamsProvider((tournamentId: tournamentId, openOnly: true)));
      ref.invalidate(teamsProvider((tournamentId: tournamentId, openOnly: false)));
      ref.invalidate(myTeamProvider(tournamentId));
      ref.invalidate(tournamentDetailProvider(tournamentId));
      ref.invalidate(participantsProvider(tournamentId));
      ref.invalidate(myTournamentsProvider);
      ref.invalidate(tournamentsProvider);

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
  final int teamCap;
  final bool joining;
  final VoidCallback onJoin;

  const _TeamTile({
    required this.team,
    required this.teamCap,
    required this.joining,
    required this.onJoin,
  });

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
              _SpotBadge(memberCount: team.memberCount, teamCap: teamCap),
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
  final int teamCap;
  const _SpotBadge({required this.memberCount, required this.teamCap});

  @override
  Widget build(BuildContext context) {
    final full = memberCount >= teamCap;
    final left = teamCap - memberCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: full ? AppColors.error.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        full
            ? 'Full · $teamCap / $teamCap'
            : '$memberCount / $teamCap · ${left == 1 ? '1 spot left' : '$left spots left'}',
        style: TextStyle(
          color: full ? AppColors.error : AppColors.success,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
