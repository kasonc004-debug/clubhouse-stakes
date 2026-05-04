import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../tournaments/providers/tournament_provider.dart';
import '../../tournaments/models/tournament_model.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentsAsync = ref.watch(allTournamentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'My Clubhouses',
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => context.push('/clubhouses/mine'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/create-tournament'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Tournament', style: TextStyle(color: Colors.white)),
      ),
      body: tournamentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error:   (e, _) => ErrorCard(message: e.toString()),
        data: (tournaments) {
          if (tournaments.isEmpty) {
            return const EmptyState(
              icon: Icons.event_note,
              title: 'No tournaments',
              subtitle: 'Create your first tournament using the button below.',
            );
          }
          // Sort: active → upcoming → completed; date asc within group.
          int rank(String s) => switch (s) { 'active' => 0, 'upcoming' => 1, _ => 2 };
          final sorted = [...tournaments]
            ..sort((a, b) {
              final r = rank(a.status).compareTo(rank(b.status));
              return r != 0 ? r : a.date.compareTo(b.date);
            });
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: sorted.length,
            itemBuilder: (context, i) => _AdminTournamentTile(tournament: sorted[i]),
          );
        },
      ),
    );
  }
}

class _AdminTournamentTile extends StatelessWidget {
  final TournamentModel tournament;
  const _AdminTournamentTile({required this.tournament});

  Color _statusColor(String status) {
    switch (status) {
      case 'active':    return Colors.green;
      case 'completed': return Colors.grey;
      default:          return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: () => context.push(
          '/admin/tournament/${t.id}',
          extra: t.name,
        ),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.sports_golf, color: AppColors.primary),
        ),
        title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t.city} · ${t.formatLabel}', style: const TextStyle(fontSize: 12)),
            Text('${t.playerCount}/${t.maxPlayers} players · \$${t.purse.toStringAsFixed(0)} purse',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(t.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _statusColor(t.status).withOpacity(0.4)),
              ),
              child: Text(
                t.status.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _statusColor(t.status)),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
