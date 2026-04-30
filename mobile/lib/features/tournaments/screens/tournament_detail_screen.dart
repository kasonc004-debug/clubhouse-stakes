import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/cs_button.dart';
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      error:   (e, _) => Scaffold(body: ErrorCard(message: e.toString())),
      data:    (t) => _TournamentDetailView(tournament: t, joinState: joinState),
    );
  }
}

class _TournamentDetailView extends ConsumerWidget {
  final TournamentModel tournament;
  final AsyncValue<void> joinState;

  const _TournamentDetailView({required this.tournament, required this.joinState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t    = tournament;
    final user = ref.watch(authProvider).user;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryDark, AppColors.primaryLight],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.sports_golf, size: 80, color: Colors.white24)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Purse highlight card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF5E642), Color(0xFFD4AF37)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      const Icon(Icons.emoji_events, color: Colors.black87, size: 32),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Total Purse', style: TextStyle(color: Colors.black54, fontSize: 12)),
                        Text('\$${t.purse.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87)),
                      ]),
                      const Spacer(),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('Entry Fee', style: TextStyle(color: Colors.black54, fontSize: 12)),
                        Text('\$${t.signUpFee.toStringAsFixed(0)} / ${t.feePer}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Info grid
                  _InfoRow(Icons.calendar_today_outlined, 'Date',
                      DateFormat('EEEE, MMMM d, yyyy · h:mm a').format(t.date)),
                  _InfoRow(Icons.location_on_outlined, 'Location',
                      t.courseName != null ? '${t.courseName}\n${t.city}' : t.city),
                  _InfoRow(Icons.format_list_bulleted, 'Format',
                      t.isFourball ? 'Four-Ball (Best Ball)' : 'Individual Stroke Play'),
                  _InfoRow(Icons.people_outlined, 'Players',
                      '${t.playerCount} / ${t.maxPlayers} registered (${t.spotsLeft} spots left)'),
                  if (t.description != null) ...[
                    const SizedBox(height: 12),
                    Text(t.description!, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
                  ],

                  const SizedBox(height: 24),

                  // Payout info
                  const Text('Payout Structure', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  _PayoutRow('1st Place', '50%', t.purse * 0.5),
                  _PayoutRow('2nd Place', '30%', t.purse * 0.3),
                  _PayoutRow('3rd Place', '20%', t.purse * 0.2),

                  const SizedBox(height: 28),

                  // Action buttons
                  if (t.isUpcoming && user != null) ...[
                    if (t.isFourball) ...[
                      CSButton(
                        label: 'Create Team',
                        icon: Icons.group_add,
                        loading: joinState.isLoading,
                        onPressed: () => context.push('/tournament/${t.id}/create-team'),
                      ),
                      const SizedBox(height: 10),
                      CSButton(
                        label: 'Join Existing Team',
                        icon: Icons.group,
                        outlined: true,
                        loading: joinState.isLoading,
                        onPressed: () => context.push('/tournament/${t.id}/join-team'),
                      ),
                    ] else ...[
                      CSButton(
                        label: t.isFull ? 'Tournament Full' : 'Register — \$${t.signUpFee.toStringAsFixed(0)}',
                        loading: joinState.isLoading,
                        onPressed: t.isFull ? null : () => _joinIndividual(context, ref, t.id),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],

                  // Leaderboard button
                  CSButton(
                    label: 'View Leaderboard',
                    icon: Icons.leaderboard,
                    outlined: true,
                    onPressed: () => context.push('/leaderboard/${t.id}'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinIndividual(BuildContext context, WidgetRef ref, String id) async {
    final ok = await ref.read(joinTournamentProvider.notifier).join(id);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registered successfully!'), backgroundColor: AppColors.success));
      ref.invalidate(tournamentDetailProvider(id));
    } else if (context.mounted) {
      final err = ref.read(joinTournamentProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err?.toString() ?? 'Failed to register'), backgroundColor: AppColors.error));
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  final String position;
  final String pct;
  final double amount;
  const _PayoutRow(this.position, this.pct, this.amount);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), shape: BoxShape.circle),
          child: Center(child: Text(position[0],
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold))),
        ),
        const SizedBox(width: 12),
        Text(position, style: const TextStyle(fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(pct, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(width: 16),
        Text('\$${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
      ]),
    );
  }
}
