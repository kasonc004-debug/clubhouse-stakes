import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/cs_button.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../tournaments/providers/tournament_provider.dart';
import '../../tournaments/models/tournament_model.dart';
import 'create_tournament_screen.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentsAsync = ref.watch(tournamentsProvider(null));

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
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
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: tournaments.length,
            itemBuilder: (context, i) => _AdminTournamentTile(tournament: tournaments[i]),
          );
        },
      ),
    );
  }
}

class _AdminTournamentTile extends StatelessWidget {
  final TournamentModel tournament;
  const _AdminTournamentTile({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
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
            Text('${t.city} · ${t.format}', style: const TextStyle(fontSize: 12)),
            Text('${t.playerCount}/${t.maxPlayers} players · \$${t.purse.toStringAsFixed(0)} purse',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'participants') {
              context.push('/admin/tournament/${t.id}/participants');
            } else if (action == 'activate') {
              _updateStatus(context, t.id, 'active');
            } else if (action == 'complete') {
              _updateStatus(context, t.id, 'completed');
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'participants', child: Text('View Participants')),
            PopupMenuItem(value: 'activate',     child: Text('Set Active')),
            PopupMenuItem(value: 'complete',     child: Text('Mark Complete')),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _updateStatus(BuildContext context, String id, String status) async {
    // Would call PATCH /admin/tournaments/:id in a real impl
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tournament status updated to $status')),
    );
  }
}
