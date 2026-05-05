import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tournaments/models/tournament_model.dart';
import '../models/clubhouse_model.dart';
import '../providers/clubhouse_provider.dart';
import 'invite_member_sheet.dart';

Color _hex(String s) {
  final h = s.replaceAll('#', '');
  final v = int.tryParse(h.length == 6 ? 'ff$h' : h, radix: 16) ?? 0xff1B3D2C;
  return Color(v);
}

class ClubhousePageScreen extends ConsumerWidget {
  final String slug;
  const ClubhousePageScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clubhouseBySlugProvider(slug));
    final me = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Scaffold(body: ErrorCard(message: e.toString())),
        data: (page) {
          final ch = page.clubhouse;
          final primary = _hex(ch.primaryColor);
          final accent  = _hex(ch.accentColor);
          // Backend tells us whether the current user can manage. Falls back
          // to ownership for older clients/responses.
          final canEdit = page.canManage ||
              (me != null && me.id == ch.ownerId);

          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: ch.bannerUrl != null ? 220 : 110,
              pinned: true,
              backgroundColor: primary,
              foregroundColor: Colors.white,
              actions: [
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push('/clubhouses/edit', extra: ch),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(ch.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                background: Stack(fit: StackFit.expand, children: [
                  if (ch.bannerUrl != null && ch.bannerUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: ch.bannerUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: primary),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary, primary.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: _Header(clubhouse: ch, accent: accent, primary: primary),
            ),
            if (!canEdit)
              SliverToBoxAdapter(
                child: _MembershipBar(
                  clubhouseId: ch.id,
                  slug: ch.slug,
                  status: page.membershipStatus,
                  memberCount: page.memberCount,
                  isPublic: ch.isPublic,
                  primary: primary,
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(children: [
                    Text('${page.memberCount} members',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: AppColors.background,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => InviteMemberSheet(
                            clubhouseId:   ch.id,
                            clubhouseName: ch.name,
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text('Invite member'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                    ),
                  ]),
                ),
              ),
            if (ch.about != null && ch.about!.trim().isNotEmpty)
              SliverToBoxAdapter(
                child: _AboutSection(text: ch.about!),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 12, 8),
                child: Row(children: [
                  Text('TOURNAMENTS · ${page.tournaments.length}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: AppColors.textSecondary)),
                  const Spacer(),
                  if (canEdit)
                    TextButton.icon(
                      onPressed: () =>
                          context.push('/admin/create-tournament'),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Post Tournament'),
                      style: TextButton.styleFrom(
                        foregroundColor: primary,
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                ]),
              ),
            ),
            if (page.tournaments.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Text(
                    'No tournaments yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _TournamentRow(
                      tournament: page.tournaments[i], accent: accent),
                  childCount: page.tournaments.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ]);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ClubhouseModel clubhouse;
  final Color accent, primary;
  const _Header({
    required this.clubhouse,
    required this.accent,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final ch = clubhouse;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (ch.logoUrl != null && ch.logoUrl!.isNotEmpty)
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
              imageUrl: ch.logoUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Icon(Icons.flag, color: accent),
            ),
          ),
        if (ch.logoUrl != null && ch.logoUrl!.isNotEmpty)
          const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ch.name,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900)),
            if (ch.courseName != null && ch.courseName!.isNotEmpty)
              Text(ch.courseName!,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primary)),
            if (ch.locationLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(ch.locationLabel,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (ch.isPublicCourse)
                _Chip(label: 'PUBLIC COURSE', color: accent),
              _Chip(
                  label: ch.isPublic ? 'PUBLIC PAGE' : 'PRIVATE',
                  color: ch.isPublic ? primary : AppColors.textSecondary),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: color)),
      );
}

class _AboutSection extends StatelessWidget {
  final String text;
  const _AboutSection({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(text,
              style: const TextStyle(height: 1.55, fontSize: 14)),
        ),
      );
}

class _TournamentRow extends StatelessWidget {
  final TournamentModel tournament;
  final Color accent;
  const _TournamentRow({required this.tournament, required this.accent});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return InkWell(
      onTap: () => context.push('/tournament/${t.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.sports_golf, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      '${DateFormat('MMM d, yyyy').format(t.date)} · ${t.formatLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(t.status).withOpacity(0.13),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(t.status.toUpperCase(),
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: _statusColor(t.status))),
            ),
          ]),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'active':    return AppColors.success;
      case 'completed': return AppColors.textSecondary;
      default:          return const Color(0xFFC9A84C);
    }
  }
}

class _MembershipBar extends ConsumerStatefulWidget {
  final String clubhouseId;
  final String slug;
  final String? status;
  final int memberCount;
  final bool isPublic;
  final Color primary;
  const _MembershipBar({
    required this.clubhouseId,
    required this.slug,
    required this.status,
    required this.memberCount,
    required this.isPublic,
    required this.primary,
  });

  @override
  ConsumerState<_MembershipBar> createState() => _MembershipBarState();
}

class _MembershipBarState extends ConsumerState<_MembershipBar> {
  bool _busy = false;

  Future<void> _do(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(clubhouseBySlugProvider(widget.slug));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.read(clubhouseMembershipProvider);
    final s = widget.status;

    Widget btn(String label, VoidCallback? onPressed,
        {bool filled = true, IconData? icon}) {
      return ElevatedButton.icon(
        onPressed: _busy ? null : onPressed,
        icon: _busy
            ? const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon ?? Icons.add, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? widget.primary : AppColors.surface,
          foregroundColor: filled ? Colors.white : widget.primary,
          elevation: 0,
          side: filled
              ? null
              : BorderSide(color: widget.primary.withOpacity(0.5)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
      );
    }

    Widget action;
    if (s == 'invited') {
      action = btn('Accept invite',
          () => _do(() => actions.acceptInvite(widget.clubhouseId)),
          icon: Icons.check);
    } else if (s == 'member') {
      action = btn('Following',
          () => _do(() => actions.unfollow(widget.clubhouseId)),
          filled: false, icon: Icons.check);
    } else if (widget.isPublic) {
      action = btn('Follow',
          () => _do(() => actions.follow(widget.clubhouseId)),
          icon: Icons.add);
    } else {
      action = const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('Invite-only — ask the host to add you.',
            style: TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(children: [
        Text('${widget.memberCount} members',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        action,
      ]),
    );
  }
}
