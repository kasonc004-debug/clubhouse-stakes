import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../clubhouses/providers/clubhouse_provider.dart';
import '../../tournaments/providers/tournament_provider.dart';
import '../../tournaments/models/tournament_model.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentsAsync = ref.watch(allTournamentsProvider);
    final clubhousesAsync  = ref.watch(myClubhousesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create',
            style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allTournamentsProvider);
          ref.invalidate(myClubhousesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            // ── Clubhouses section ────────────────────────────
            _SectionHeader(
              label: 'CLUBHOUSES',
              actionLabel: 'New Clubhouse',
              actionIcon: Icons.add,
              onAction: () => context.push('/clubhouses/edit'),
            ),
            clubhousesAsync.when(
              loading: () => const _SectionLoader(),
              error: (e, _) => _SectionError(message: e.toString()),
              data: (list) {
                if (list.isEmpty) {
                  return _EmptyTile(
                    icon: Icons.flag_outlined,
                    title: 'No clubhouses yet',
                    subtitle: 'Create one to host tournaments under it.',
                    actionLabel: 'Create your first clubhouse',
                    onAction: () => context.push('/clubhouses/edit'),
                  );
                }
                return Column(children: [
                  for (final c in list)
                    Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        onTap: () => context.push('/clubhouses/${c.slug}'),
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              const Icon(Icons.flag, color: AppColors.primary),
                        ),
                        title: Text(c.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${c.locationLabel.isEmpty ? '—' : c.locationLabel} · '
                          '${c.isPublic ? 'public' : 'private'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Edit',
                          onPressed: () =>
                              context.push('/clubhouses/edit', extra: c),
                        ),
                      ),
                    ),
                ]);
              },
            ),

            const SizedBox(height: 22),

            // ── Tournaments section ────────────────────────────
            _SectionHeader(
              label: 'TOURNAMENTS',
              actionLabel: 'New Tournament',
              actionIcon: Icons.add,
              onAction: () => context.push('/admin/create-tournament'),
            ),
            tournamentsAsync.when(
              loading: () => const _SectionLoader(),
              error: (e, _) => _SectionError(message: e.toString()),
              data: (tournaments) {
                if (tournaments.isEmpty) {
                  return _EmptyTile(
                    icon: Icons.event_note,
                    title: 'No tournaments',
                    subtitle: 'Create one to start collecting registrations.',
                    actionLabel: 'Create your first tournament',
                    onAction: () =>
                        context.push('/admin/create-tournament'),
                  );
                }
                int rank(String s) =>
                    switch (s) { 'active' => 0, 'upcoming' => 1, _ => 2 };
                final sorted = [...tournaments]
                  ..sort((a, b) {
                    final r = rank(a.status).compareTo(rank(b.status));
                    return r != 0 ? r : a.date.compareTo(b.date);
                  });
                return Column(children: [
                  for (final t in sorted)
                    _AdminTournamentTile(tournament: t),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sports_golf,
                    color: AppColors.primary, size: 22),
              ),
              title: const Text('New Tournament',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Set up a paid event with scoring + payouts'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/admin/create-tournament');
              },
            ),
            ListTile(
              leading: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFC9A84C).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flag,
                    color: Color(0xFFC9A84C), size: 22),
              ),
              title: const Text('New Clubhouse',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle:
                  const Text('A branded page that hosts your tournaments'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/clubhouses/edit');
              },
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Section helpers ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  const _SectionHeader({
    required this.label,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppColors.textSecondary)),
          const Spacer(),
          TextButton.icon(
            onPressed: onAction,
            icon: Icon(actionIcon, size: 16),
            label: Text(actionLabel),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      );
}

class _SectionLoader extends StatelessWidget {
  const _SectionLoader();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.primary)),
        ),
      );
}

class _SectionError extends StatelessWidget {
  final String message;
  const _SectionError({required this.message});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text(message,
            style: const TextStyle(color: AppColors.error, fontSize: 12)),
      );
}

class _EmptyTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, actionLabel;
  final VoidCallback onAction;
  const _EmptyTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ]),
            ),
          ]),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 16),
              label: Text(actionLabel),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ]),
      );
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
