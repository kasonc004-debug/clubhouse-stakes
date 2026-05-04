import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../models/leaderboard_model.dart';
import '../providers/leaderboard_provider.dart';

// Skin pot color
const _kGold = Color(0xFFC9A84C);

const _kLiveInterval = Duration(seconds: 10);

class LeaderboardScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const LeaderboardScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  Timer?          _timer;
  DateTime        _lastRefreshed = DateTime.now();
  TabController?  _tabController;
  bool            _hasSkins = false;

  @override
  void initState() {
    super.initState();
    _scheduleTimer();
  }

  void _scheduleTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_kLiveInterval, (_) => _refresh());
  }

  void _refresh() {
    ref.invalidate(leaderboardProvider(widget.tournamentId));
    ref.invalidate(skinsLeaderboardProvider(widget.tournamentId));
    if (mounted) setState(() => _lastRefreshed = DateTime.now());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  void _ensureTabController(bool hasSkins) {
    if (_hasSkins == hasSkins) return;
    _hasSkins = hasSkins;
    _tabController?.dispose();
    _tabController = hasSkins
        ? TabController(length: 2, vsync: this)
        : null;
  }

  String get _agoLabel {
    final s = DateTime.now().difference(_lastRefreshed).inSeconds;
    if (s < 5) return 'just now';
    return '${s}s ago';
  }

  @override
  Widget build(BuildContext context) {
    final async      = ref.watch(leaderboardProvider(widget.tournamentId));
    final skinsAsync = ref.watch(skinsLeaderboardProvider(widget.tournamentId));
    final isActive   = async.valueOrNull?.status == 'active';

    final skinsData = skinsAsync.valueOrNull;
    final hasSkins  = skinsData != null && skinsData.players.isNotEmpty;
    _ensureTabController(hasSkins);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF1B3D2C), Color(0xFF2A5940)]),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              if (isActive) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('● LIVE',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1)),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                'Updated $_agoLabel',
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 11),
                              ),
                            ]),
                            const Text('LEADERBOARD',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900)),
                          ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: _refresh,
                    ),
                  ]),
                ),
                // Tabs (only when skins game exists)
                if (hasSkins && _tabController != null)
                  TabBar(
                    controller: _tabController,
                    indicatorColor: _kGold,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1),
                    tabs: const [
                      Tab(text: 'MAIN'),
                      Tab(text: '🃏 SKINS'),
                    ],
                  ),
              ]),
            ),
          ),

          // ── Body ──────────────────────────────────────────────
          Expanded(
            child: hasSkins && _tabController != null
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _mainLeaderboardBody(async, isActive),
                      _SkinsLeaderboard(data: skinsData, isActive: isActive),
                    ],
                  )
                : _mainLeaderboardBody(async, isActive),
          ),
        ],
      ),
    );
  }

  Widget _mainLeaderboardBody(AsyncValue<LeaderboardData> async, bool isActive) {
    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) =>
          ErrorCard(message: e.toString(), onRetry: _refresh),
      data: (data) {
        if (data.individual.isEmpty && data.fourball.isEmpty) {
          return const EmptyState(
            icon: Icons.leaderboard_outlined,
            title: 'No scores yet',
            subtitle: 'Scores will appear as players enter each hole.',
          );
        }
        if (data.format == 'individual') {
          return _IndividualLeaderboard(
              entries: data.individual,
              isActive: isActive,
              handicapEnabled: data.handicapEnabled,
              pars: data.pars,
              yardages: data.yardages);
        }
        return _FourballLeaderboard(
            entries: data.fourball,
            isActive: isActive,
            handicapEnabled: data.handicapEnabled);
      },
    );
  }
}

// ── Individual ────────────────────────────────────────────────────────────────
class _IndividualLeaderboard extends StatelessWidget {
  final List<IndividualEntry> entries;
  final bool isActive;
  final bool handicapEnabled;
  final List<int>? pars;
  final List<int>? yardages;
  const _IndividualLeaderboard({
    required this.entries,
    required this.isActive,
    required this.handicapEnabled,
    this.pars,
    this.yardages,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Column header
      Container(
        color: const Color(0xFF1B3D2C),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          const SizedBox(
              width: 40,
              child: Text('POS',
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5))),
          const Expanded(
              child: Text('PLAYER',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5))),
          if (isActive)
            const SizedBox(
                width: 50,
                child: Center(
                    child: Text('THRU',
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5)))),
          SizedBox(
              width: 52,
              child: Center(
                  child: Text('GROSS',
                      style: TextStyle(
                          color: handicapEnabled
                              ? Colors.white60
                              : Colors.white,
                          fontSize: 10,
                          fontWeight: handicapEnabled
                              ? FontWeight.w700
                              : FontWeight.w800,
                          letterSpacing: 1.5)))),
          if (handicapEnabled)
            const SizedBox(
                width: 52,
                child: Center(
                    child: Text('NET',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)))),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (context, i) => _IndividualRow(
              entry: entries[i],
              isActive: isActive,
              handicapEnabled: handicapEnabled,
              pars: pars,
              yardages: yardages),
        ),
      ),
    ]);
  }
}

class _IndividualRow extends StatelessWidget {
  final IndividualEntry entry;
  final bool isActive;
  final bool handicapEnabled;
  final List<int>? pars;
  final List<int>? yardages;
  const _IndividualRow({
    required this.entry,
    required this.isActive,
    required this.handicapEnabled,
    this.pars,
    this.yardages,
  });

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final topThree = e.rank <= 3;

    return InkWell(
      onTap: e.holeScores.isNotEmpty
          ? () => _showHoles(context, e, pars, yardages)
          : null,
      child: Container(
        color: topThree
            ? AppColors.gold.withOpacity(0.05)
            : null,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(children: [
          // Rank
          SizedBox(width: 40, child: _RankBadge(rank: e.rank)),

          // Name + handicap
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  if (handicapEnabled)
                    Text('HCP ${e.handicap.toStringAsFixed(1)}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                ]),
          ),

          // Thru (live only)
          if (isActive)
            SizedBox(
              width: 50,
              child: Center(child: _ThruPill(
                  isComplete: e.isComplete, holesPlayed: e.holesPlayed)),
            ),

          // Gross
          SizedBox(
            width: 52,
            child: Center(
              child: Text(
                e.grossScore > 0 ? '${e.grossScore}' : '—',
                style: TextStyle(
                    color: handicapEnabled
                        ? AppColors.textSecondary
                        : AppColors.primary,
                    fontWeight: handicapEnabled
                        ? FontWeight.w600
                        : FontWeight.w800,
                    fontSize: handicapEnabled ? 14 : 16),
              ),
            ),
          ),

          // Net (only when handicap enabled)
          if (handicapEnabled)
            SizedBox(
              width: 52,
              child: Center(
                child: e.netScore != null
                    ? Text(
                        e.netScore!.toStringAsFixed(1),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.primary),
                      )
                    : Text(
                        e.holesPlayed > 0
                            ? '${e.grossScore}'
                            : '—',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.primary.withOpacity(0.45),
                        ),
                      ),
              ),
            ),
        ]),
      ),
    );
  }

  void _showHoles(BuildContext context, IndividualEntry e,
      List<int>? parsArg, List<int>? yardagesArg) {
    final pars = (parsArg != null && parsArg.length == 18)
        ? parsArg
        : const [4, 4, 3, 4, 5, 3, 4, 4, 5, 4, 3, 4, 5, 4, 3, 4, 5, 4];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        builder: (_, ctrl) => Column(children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(e.name,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            e.isComplete
                ? 'Final · Gross ${e.grossScore} · Net ${e.netScore?.toStringAsFixed(1) ?? "—"}'
                : 'Thru ${e.holesPlayed} · Gross ${e.grossScore}',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
          const Divider(height: 24),
          Expanded(
            child: GridView.builder(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                childAspectRatio: 1.1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 18,
              itemBuilder: (_, i) {
                final raw = i < e.holeScores.length
                    ? e.holeScores[i]
                    : 0;
                final entered = raw > 0;
                final diff = entered ? raw - pars[i] : 0;
                final color = entered
                    ? _scoreColor(diff)
                    : AppColors.divider;
                return Column(children: [
                  Text('${i + 1}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary)),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: entered
                          ? color.withOpacity(0.15)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: entered
                              ? color.withOpacity(0.4)
                              : AppColors.divider),
                    ),
                    child: Center(
                        child: Text(
                      entered ? '$raw' : '·',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: entered
                              ? color
                              : AppColors.textSecondary),
                    )),
                  ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }

  Color _scoreColor(int diff) {
    if (diff <= -2) return const Color(0xFF7B1FA2);
    if (diff == -1) return const Color(0xFF1565C0);
    if (diff == 0) return const Color(0xFF1B3D2C);
    if (diff == 1) return AppColors.warning;
    return AppColors.error;
  }
}

// ── Fourball ──────────────────────────────────────────────────────────────────
class _FourballLeaderboard extends StatelessWidget {
  final List<FourballEntry> entries;
  final bool isActive;
  final bool handicapEnabled;
  const _FourballLeaderboard({
    required this.entries,
    required this.isActive,
    required this.handicapEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final scoreLabel = handicapEnabled ? 'NET' : 'GROSS';
    return Column(children: [
      Container(
        color: const Color(0xFF1B3D2C),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          const SizedBox(
              width: 40,
              child: Text('POS',
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5))),
          const Expanded(
              child: Text('TEAM',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5))),
          if (isActive)
            const SizedBox(
                width: 50,
                child: Center(
                    child: Text('THRU',
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5)))),
          SizedBox(
              width: 68,
              child: Center(
                  child: Text(scoreLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)))),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (context, i) => _FourballRow(
              entry: entries[i],
              isActive: isActive,
              handicapEnabled: handicapEnabled),
        ),
      ),
    ]);
  }
}

class _FourballRow extends StatelessWidget {
  final FourballEntry entry;
  final bool isActive;
  final bool handicapEnabled;
  const _FourballRow({
    required this.entry,
    required this.isActive,
    required this.handicapEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return InkWell(
      onTap: () => _showDetail(context, e),
      child: Container(
        color: e.rank <= 3 ? AppColors.gold.withOpacity(0.05) : null,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(children: [
          SizedBox(width: 40, child: _RankBadge(rank: e.rank)),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(
                    e.players
                        .map((p) => handicapEnabled
                            ? '${p.name} (${p.handicap.toStringAsFixed(1)})'
                            : p.name)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary),
                  ),
                ]),
          ),
          if (isActive)
            SizedBox(
              width: 50,
              child: Center(
                  child: _ThruPill(
                      isComplete: e.holesPlayed == 18,
                      holesPlayed: e.holesPlayed)),
            ),
          SizedBox(
            width: 68,
            child: Center(
              child: Text(
                handicapEnabled
                    ? e.netTotal.toStringAsFixed(1)
                    : e.netTotal.toStringAsFixed(0),
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.primary),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _showDetail(BuildContext context, FourballEntry e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Text(e.teamName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                Text(
                  e.holesPlayed == 18
                      ? 'Final · Net ${e.netTotal.toStringAsFixed(1)}'
                      : 'Thru ${e.holesPlayed} · Net ${e.netTotal.toStringAsFixed(1)}',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
                ),
                const Divider(height: 24),
                // For formats where individual player scores aren't stored
                // (e.g. scramble), show the team scorecard from bestBallPerHole.
                if (e.players.every((p) => p.holeScores.isEmpty) &&
                    e.bestBallPerHole.isNotEmpty) ...[
                  const Text('TEAM SCORECARD',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: List.generate(18, (i) {
                      final raw = i < e.bestBallPerHole.length
                          ? e.bestBallPerHole[i].round()
                          : 0;
                      return Container(
                        width: 32, height: 36,
                        decoration: BoxDecoration(
                          color: raw > 0
                              ? AppColors.background
                              : AppColors.divider.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${i + 1}',
                                  style: const TextStyle(
                                      fontSize: 8,
                                      color: AppColors.textSecondary)),
                              Text(raw > 0 ? '$raw' : '·',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                            ]),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text('TEAM',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  for (final p in e.players)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        const Icon(Icons.person,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(p.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('HCP ${p.handicap.toStringAsFixed(1)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ]),
                    ),
                ] else
                ...e.players.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.person,
                                  size: 16,
                                  color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(p.name,
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w600)),
                              const Spacer(),
                              Text(
                                  'HCP ${p.handicap.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                      color:
                                          AppColors.textSecondary,
                                      fontSize: 12)),
                            ]),
                            if (p.holeScores.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children:
                                    List.generate(18, (i) {
                                  final raw =
                                      i < p.holeScores.length
                                          ? p.holeScores[i]
                                          : 0;
                                  return Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: raw > 0
                                          ? AppColors.background
                                          : AppColors.divider
                                              .withOpacity(0.3),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: Border.all(
                                          color: AppColors.divider),
                                    ),
                                    child: Center(
                                        child: Text(
                                      raw > 0 ? '$raw' : '·',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight:
                                              FontWeight.w600),
                                    )),
                                  );
                                }),
                              ),
                            ],
                          ]),
                    )),
              ]),
        ),
      ),
    );
  }
}

// ── Skins leaderboard ─────────────────────────────────────────────────────────

class _SkinsLeaderboard extends StatelessWidget {
  final SkinsData data;
  final bool      isActive;
  const _SkinsLeaderboard({required this.data, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    return CustomScrollView(
      slivers: [
        // Pot summary strip
        SliverToBoxAdapter(child: _SkinsPotStrip(data: data)),

        // Payout summary when complete
        if (summary != null && summary.isComplete && summary.skinsWon.isNotEmpty)
          SliverToBoxAdapter(child: _SkinsPayoutSummary(summary: summary)),

        // Column header
        SliverToBoxAdapter(
          child: Container(
            color: const Color(0xFF1B3D2C),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const SizedBox(width: 38,
                  child: Text('HOLE', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1))),
              const SizedBox(width: 60,
                  child: Center(child: Text('POT', style: TextStyle(color: _kGold, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)))),
              const Expanded(
                  child: Text('STATUS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1))),
            ]),
          ),
        ),

        // Hole rows
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final hole = data.holes[i];
              return Column(children: [
                _SkinsHoleRow(hole: hole),
                if (i < data.holes.length - 1)
                  const Divider(height: 1, color: AppColors.divider),
              ]);
            },
            childCount: data.holes.length,
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _SkinsPotStrip extends StatelessWidget {
  final SkinsData data;
  const _SkinsPotStrip({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGold.withOpacity(0.3), width: 1.5),
      ),
      child: Row(children: [
        _SkinsStat(label: 'ENTRANTS',  value: '${data.players.length}'),
        _SkinsVDiv(),
        _SkinsStat(label: 'ENTRY FEE', value: '\$${data.skinsFee.toStringAsFixed(0)}'),
        _SkinsVDiv(),
        _SkinsStat(label: 'TOTAL POT',
            value: '\$${data.skinsPot.toStringAsFixed(0)}', gold: true),
      ]),
    );
  }
}

class _SkinsStat extends StatelessWidget {
  final String label, value;
  final bool gold;
  const _SkinsStat({required this.label, required this.value, this.gold = false});

  @override
  Widget build(BuildContext context) => Expanded(
      child: Column(children: [
        Text(label, style: const TextStyle(
            fontSize: 9, fontWeight: FontWeight.w700,
            letterSpacing: 1.5, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900,
            color: gold ? _kGold : AppColors.textPrimary)),
      ]));
}

class _SkinsVDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 32, width: 1, color: AppColors.divider,
          margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _SkinsPayoutSummary extends StatelessWidget {
  final SkinsSummary summary;
  const _SkinsPayoutSummary({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('FINAL PAYOUTS',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800,
                letterSpacing: 2, color: AppColors.success)),
        const SizedBox(height: 10),
        ...summary.skinsWon.map((w) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(w.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(
                'Holes ${w.holesWon.join(', ')} · ${w.holesWon.length} skin${w.holesWon.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ])),
            Text('\$${w.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.success)),
          ]),
        )),
        if (summary.carryoverHoles > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${summary.carryoverHoles} hole${summary.carryoverHoles == 1 ? '' : 's'} tied out — pot carries into next round',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
      ]),
    );
  }
}

class _SkinsHoleRow extends StatelessWidget {
  final SkinsHole hole;
  const _SkinsHoleRow({required this.hole});

  @override
  Widget build(BuildContext context) {
    final h = hole;

    Color  statusColor;
    Widget statusWidget;

    switch (h.status) {
      case 'won':
        statusColor = AppColors.success;
        statusWidget = Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              h.winner!.name,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
            ),
          ),
          const SizedBox(width: 6),
          Text('net ${h.winner!.netScore.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]);

      case 'tied':
        statusColor = AppColors.warning;
        final names = h.tiedPlayers.map((p) => p.name).join(' · ');
        statusWidget = Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('CARRY OVER',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: AppColors.warning, letterSpacing: 1)),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(names,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
        ]);

      case 'leading':
        statusColor = AppColors.primary;
        statusWidget = Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              h.leader!.name,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 6),
          const Text('leading',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic)),
        ]);

      case 'provisional_tied':
        statusColor = AppColors.textSecondary;
        final names = h.tiedPlayers.map((p) => p.name).join(' · ');
        statusWidget = Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('TIED',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary, letterSpacing: 1)),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(names,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic)),
          ),
        ]);

      default: // pending
        statusColor = AppColors.divider;
        statusWidget = const Text('—',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        // Hole number badge
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: h.status == 'won'
                ? AppColors.success.withOpacity(0.12)
                : h.status == 'tied'
                    ? AppColors.warning.withOpacity(0.10)
                    : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: statusColor.withOpacity(0.35)),
          ),
          child: Center(
            child: Text('${h.hole}',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: statusColor)),
          ),
        ),
        const SizedBox(width: 8),

        // Pot column
        SizedBox(
          width: 52,
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('\$${h.pot.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: _kGold)),
            if (h.carryIn > 0)
              Text('+${h.carryIn}',
                  style: const TextStyle(fontSize: 9, color: _kGold)),
          ]),
        ),
        const SizedBox(width: 8),

        // Status
        Expanded(child: statusWidget),

        // Thru indicator
        if (h.totalPlayers > 0 && !h.isPending)
          Text(
            '${h.playersIn}/${h.totalPlayers}',
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
      ]),
    );
  }
}

// ── Rank badge ────────────────────────────────────────────────────────────────
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
            child: Text(rank.toString(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14))),
      );
    }
    // Ranks 4+ — flat numeric chip, no fill, easier on the eye
    return Center(
      child: Text('$rank',
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 14)),
    );
  }
}

class _ThruPill extends StatelessWidget {
  final bool isComplete;
  final int holesPlayed;
  const _ThruPill({required this.isComplete, required this.holesPlayed});

  @override
  Widget build(BuildContext context) {
    final label = isComplete
        ? 'F'
        : holesPlayed > 0
            ? '$holesPlayed'
            : '—';
    final fg = isComplete
        ? AppColors.success
        : holesPlayed > 0
            ? AppColors.warning
            : AppColors.textSecondary;
    final bg = isComplete
        ? AppColors.success.withOpacity(0.13)
        : holesPlayed > 0
            ? AppColors.warning.withOpacity(0.13)
            : AppColors.divider.withOpacity(0.5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg)),
    );
  }
}
