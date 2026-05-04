import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../models/leaderboard_model.dart';
import '../providers/leaderboard_provider.dart';

class BestRoundsScreen extends ConsumerStatefulWidget {
  const BestRoundsScreen({super.key});

  @override
  ConsumerState<BestRoundsScreen> createState() => _BestRoundsScreenState();
}

class _BestRoundsScreenState extends ConsumerState<BestRoundsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bestRoundsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        // Header
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF1B3D2C), Color(0xFF2A5940)]),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 6),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 18),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RECORD BOOK',
                              style: TextStyle(
                                  color: Color(0xFFC9A84C),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2)),
                          Text('Best Rounds',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900)),
                        ]),
                  ),
                ]),
              ),
              TabBar(
                controller: _tab,
                indicatorColor: const Color(0xFFC9A84C),
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1),
                tabs: const [
                  Tab(text: 'INDIVIDUAL'),
                  Tab(text: 'FOUR-BALL'),
                ],
              ),
            ]),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => ErrorCard(
                message: e.toString(),
                onRetry: () => ref.invalidate(bestRoundsProvider)),
            data: (data) => TabBarView(
              controller: _tab,
              children: [
                _IndividualList(rounds: data.individual),
                _FourballList(rounds: data.fourball),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _IndividualList extends StatelessWidget {
  final List<BestIndividualRound> rounds;
  const _IndividualList({required this.rounds});

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) {
      return const EmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'No completed rounds yet',
        subtitle:
            'Once an individual tournament finishes, the lowest rounds appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      itemCount: rounds.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (_, i) => _IndividualRow(rank: i + 1, round: rounds[i]),
    );
  }
}

class _IndividualRow extends StatelessWidget {
  final int rank;
  final BestIndividualRound round;
  const _IndividualRow({required this.rank, required this.round});

  @override
  Widget build(BuildContext context) {
    final r = round;
    return InkWell(
      onTap: () => context.push('/tournament/${r.tournamentId}'),
      child: Container(
        color: rank <= 3 ? AppColors.gold.withOpacity(0.05) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          SizedBox(width: 40, child: _RankBadge(rank: rank)),
          _Avatar(name: r.name, url: r.profilePictureUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    '${r.tournamentName} · ${DateFormat('MMM d, yyyy').format(r.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${r.grossScore}',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary)),
            if (r.netScore != null)
              Text('net ${r.netScore!.toStringAsFixed(1)}',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ]),
      ),
    );
  }
}

class _FourballList extends StatelessWidget {
  final List<BestFourballRound> rounds;
  const _FourballList({required this.rounds});

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_2_outlined,
        title: 'No completed team rounds',
        subtitle:
            'Once a four-ball tournament finishes, the lowest team scores appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      itemCount: rounds.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (_, i) => _FourballRow(rank: i + 1, round: rounds[i]),
    );
  }
}

class _FourballRow extends StatelessWidget {
  final int rank;
  final BestFourballRound round;
  const _FourballRow({required this.rank, required this.round});

  @override
  Widget build(BuildContext context) {
    final r = round;
    return InkWell(
      onTap: () => context.push('/tournament/${r.tournamentId}'),
      child: Container(
        color: rank <= 3 ? AppColors.gold.withOpacity(0.05) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          SizedBox(width: 40, child: _RankBadge(rank: rank)),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    r.players.map((p) => p.name).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  Text(
                    '${r.tournamentName} · ${DateFormat('MMM d, yyyy').format(r.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary),
                  ),
                ]),
          ),
          const SizedBox(width: 8),
          Text(r.netTotal.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary)),
        ]),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final medal = {
      1: AppColors.gold,
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32),
    }[rank];
    if (medal != null) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: medal, shape: BoxShape.circle),
        child: Center(
            child: Text('$rank',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14))),
      );
    }
    return Center(
      child: Text('$rank',
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 14)),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? url;
  const _Avatar({required this.name, required this.url});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters =
        parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withOpacity(0.10),
      ),
      child: Center(
          child: Text(_initials,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13))),
    );
    if (url == null || url!.isEmpty) return fallback;
    return Container(
      width: 36, height: 36,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => fallback,
        placeholder: (_, __) =>
            Container(color: AppColors.divider.withOpacity(0.3)),
      ),
    );
  }
}
