import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../auth/providers/auth_provider.dart';
import '../../clubhouses/models/clubhouse_model.dart';
import '../../clubhouses/providers/clubhouse_provider.dart';
import '../../tournaments/providers/tournament_provider.dart';
import '../../tournaments/models/tournament_model.dart';
import '../providers/admin_provider.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentsAsync = ref.watch(allTournamentsProvider);
    final clubhousesAsync  = ref.watch(myClubhousesProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allTournamentsProvider);
          ref.invalidate(myClubhousesProvider);
        },
        child: CustomScrollView(slivers: [
          // Hero header
          SliverToBoxAdapter(
            child: _Hero(
              userName: user?.name.split(' ').first ?? 'Admin',
              tournamentsAsync: tournamentsAsync,
              clubhousesAsync: clubhousesAsync,
            ),
          ),

          // Clubhouses section
          SliverToBoxAdapter(
            child: _SectionHeader(
              label: 'Clubhouses',
              actionLabel: 'New',
              onAction: () => context.push('/clubhouses/edit'),
            ),
          ),
          clubhousesAsync.when(
            loading: () => const SliverToBoxAdapter(child: _SectionLoader()),
            error: (e, _) => SliverToBoxAdapter(
                child: _SectionError(message: e.toString())),
            data: (list) {
              if (list.isEmpty) {
                return SliverToBoxAdapter(
                  child: _EmptyTile(
                    icon: Icons.flag_outlined,
                    title: 'No clubhouses yet',
                    subtitle: 'Create one to host tournaments under it.',
                    actionLabel: 'Create your first clubhouse',
                    onAction: () => context.push('/clubhouses/edit'),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _ClubhouseTile(clubhouse: list[i]),
                  childCount: list.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Tournaments section
          SliverToBoxAdapter(
            child: _SectionHeader(
              label: 'Tournaments',
              actionLabel: 'New',
              onAction: () => context.push('/admin/create-tournament'),
            ),
          ),
          tournamentsAsync.when(
            loading: () => const SliverToBoxAdapter(child: _SectionLoader()),
            error: (e, _) => SliverToBoxAdapter(
                child: _SectionError(message: e.toString())),
            data: (tournaments) {
              if (tournaments.isEmpty) {
                return SliverToBoxAdapter(
                  child: _EmptyTile(
                    icon: Icons.sports_golf,
                    title: 'No tournaments',
                    subtitle: 'Create one to start collecting registrations.',
                    actionLabel: 'Create your first tournament',
                    onAction: () => context.push('/admin/create-tournament'),
                  ),
                );
              }
              int rank(String s) =>
                  switch (s) { 'active' => 0, 'upcoming' => 1, _ => 2 };
              final sorted = [...tournaments]
                ..sort((a, b) {
                  final r = rank(a.status).compareTo(rank(b.status));
                  return r != 0 ? r : a.date.compareTo(b.date);
                });
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _TournamentTile(tournament: sorted[i]),
                  childCount: sorted.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ]),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

// ── Hero header ──────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final String userName;
  final AsyncValue<List<TournamentModel>> tournamentsAsync;
  final AsyncValue<List<ClubhouseModel>> clubhousesAsync;
  const _Hero({
    required this.userName,
    required this.tournamentsAsync,
    required this.clubhousesAsync,
  });

  @override
  Widget build(BuildContext context) {
    final tournaments = tournamentsAsync.valueOrNull ?? const [];
    final clubhouses  = clubhousesAsync.valueOrNull ?? const [];
    final activeCount =
        tournaments.where((t) => t.status == 'active').length;
    final upcomingCount =
        tournaments.where((t) => t.status == 'upcoming').length;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3D2C), Color(0xFF2A5940), Color(0xFF3D7055)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white70, size: 18),
                  onPressed: () => context.pop(),
                ),
              ]),
              const SizedBox(height: 4),
              Text('ADMIN',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5,
                  )),
              const SizedBox(height: 4),
              Text('Hello, $userName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 18),
              Row(children: [
                _StatPill(
                    label: 'CLUBHOUSES',
                    value: '${clubhouses.length}',
                    accent: false),
                const SizedBox(width: 10),
                _StatPill(
                    label: 'ACTIVE',
                    value: '$activeCount',
                    accent: activeCount > 0),
                const SizedBox(width: 10),
                _StatPill(
                    label: 'UPCOMING',
                    value: '$upcomingCount',
                    accent: false),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final bool accent;
  const _StatPill({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accent
                  ? const Color(0xFFC9A84C).withOpacity(0.6)
                  : Colors.white.withOpacity(0.15),
              width: 1.2,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    color: accent
                        ? const Color(0xFFC9A84C)
                        : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
          ]),
        ),
      );
}

// ── Section + tile widgets ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final String actionLabel;
  final VoidCallback onAction;
  const _SectionHeader({
    required this.label,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 12, 8),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
          const Spacer(),
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add, size: 16),
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
        padding: EdgeInsets.symmetric(vertical: 22),
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
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42, height: 42,
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
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
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

// ── Clubhouse tile (modern look + delete) ────────────────────────────────────

class _ClubhouseTile extends ConsumerWidget {
  final ClubhouseModel clubhouse;
  const _ClubhouseTile({required this.clubhouse});

  Color _hex(String s) {
    final h = s.replaceAll('#', '');
    final v = int.tryParse(h.length == 6 ? 'ff$h' : h, radix: 16) ?? 0xff1B3D2C;
    return Color(v);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = clubhouse;
    final primary = _hex(c.primaryColor);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/clubhouses/${c.slug}'),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(children: [
              // Logo / fallback
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: c.logoUrl != null && c.logoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: c.logoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Icon(Icons.flag, color: primary),
                      )
                    : Icon(Icons.flag, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(c.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                      if (c.myRole == 'staff') ...[
                        const SizedBox(width: 6),
                        const _ChipMicro(
                            label: 'STAFF',
                            color: Color(0xFFC9A84C)),
                      ],
                      if (c.isPublicCourse) ...[
                        const SizedBox(width: 6),
                        _ChipMicro(label: 'PUBLIC', color: primary),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      c.locationLabel.isEmpty
                          ? (c.isPublic ? 'Public page' : 'Private page')
                          : '${c.locationLabel} · ${c.isPublic ? 'public' : 'private'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined, size: 19),
                color: AppColors.textSecondary,
                onPressed: () => context.push('/clubhouses/edit', extra: c),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, size: 19),
                color: AppColors.error,
                onPressed: () => _confirmDelete(context, ref),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete this clubhouse?'),
        content: Text(
          'This removes "${clubhouse.name}", its members, and pending invites. '
          'Tournaments hosted by it stay but lose their clubhouse association. '
          'This cannot be undone.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final success =
        await ref.read(clubhouseEditProvider.notifier).deleteClubhouse(clubhouse.id);
    if (!context.mounted) return;
    if (success) {
      ref.invalidate(myClubhousesProvider);
      ref.invalidate(publicClubhousesProvider);
      ref.invalidate(allTournamentsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${clubhouse.name} deleted.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      final err = ref.read(clubhouseEditProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err?.toString() ?? 'Delete failed'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ── Tournament tile ──────────────────────────────────────────────────────────

class _TournamentTile extends ConsumerWidget {
  final TournamentModel tournament;
  const _TournamentTile({required this.tournament});

  Color _statusColor(String s) {
    switch (s) {
      case 'active':    return AppColors.success;
      case 'completed': return AppColors.textSecondary;
      default:          return const Color(0xFFC9A84C);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = tournament;
    final color = _statusColor(t.status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/admin/tournament/${t.id}', extra: t.name),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.sports_golf, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(t.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                      const SizedBox(width: 6),
                      _ChipMicro(
                          label: t.status.toUpperCase(),
                          color: color),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('MMM d, yyyy').format(t.date)} · '
                      '${t.formatLabel} · '
                      '${t.playerCount}/${t.maxPlayers} players',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, size: 19),
                color: AppColors.error,
                onPressed: () => _confirmDelete(context, ref),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete this tournament?'),
        content: Text(
          'This permanently removes "${tournament.name}", all entries, scores, '
          'teams, and payouts. Players who paid at the course will need to be '
          'refunded separately. This cannot be undone.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final success = await ref
        .read(deleteTournamentProvider.notifier)
        .delete(tournament.id);
    if (!context.mounted) return;
    if (success) {
      ref.invalidate(allTournamentsProvider);
      ref.invalidate(tournamentsProvider);
      ref.invalidate(myTournamentsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${tournament.name} deleted.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      final err = ref.read(deleteTournamentProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err?.toString() ?? 'Delete failed'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

class _ChipMicro extends StatelessWidget {
  final String label;
  final Color color;
  const _ChipMicro({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: color)),
      );
}
