import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../models/leaderboard_model.dart';
import '../providers/leaderboard_provider.dart';

// 10 s when active, 30 s otherwise — provider tells us the status
const _kLiveInterval     = Duration(seconds: 10);
const _kStandardInterval = Duration(seconds: 30);

class LeaderboardScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const LeaderboardScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  Timer? _timer;
  DateTime _lastRefreshed = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduleTimer();
  }

  void _scheduleTimer() {
    _timer?.cancel();
    // Start with live interval; once data loads we keep it
    _timer = Timer.periodic(_kLiveInterval, (_) => _refresh());
  }

  void _refresh() {
    ref.invalidate(leaderboardProvider(widget.tournamentId));
    if (mounted) setState(() => _lastRefreshed = DateTime.now());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _agoLabel {
    final s = DateTime.now().difference(_lastRefreshed).inSeconds;
    if (s < 5) return 'just now';
    return '${s}s ago';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(leaderboardProvider(widget.tournamentId));
    final isActive = async.valueOrNull?.status == 'active';

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
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(8, 8, 16, 16),
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
                                  borderRadius:
                                      BorderRadius.circular(20),
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
                                  color: Colors.white60,
                                  fontSize: 11),
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
                    icon: const Icon(Icons.refresh,
                        color: Colors.white70),
                    onPressed: _refresh,
                  ),
                ]),
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary)),
              error: (e, _) => ErrorCard(
                  message: e.toString(), onRetry: _refresh),
              data: (data) {
                if (data.individual.isEmpty &&
                    data.fourball.isEmpty) {
                  return const EmptyState(
                    icon: Icons.leaderboard_outlined,
                    title: 'No scores yet',
                    subtitle:
                        'Scores will appear as players enter each hole.',
                  );
                }
                if (data.format == 'individual') {
                  return _IndividualLeaderboard(
                      entries: data.individual,
                      isActive: isActive);
                }
                return _FourballLeaderboard(
                    entries: data.fourball, isActive: isActive);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual ────────────────────────────────────────────────────────────────
class _IndividualLeaderboard extends StatelessWidget {
  final List<IndividualEntry> entries;
  final bool isActive;
  const _IndividualLeaderboard(
      {required this.entries, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Column header
      Container(
        color: const Color(0xFF1B3D2C),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const SizedBox(
              width: 36,
              child: Text('#',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12))),
          const Expanded(
              child: Text('Player',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600))),
          if (isActive)
            const SizedBox(
                width: 50,
                child: Center(
                    child: Text('Thru',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12)))),
          const SizedBox(
              width: 48,
              child: Center(
                  child: Text('Gross',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12)))),
          const SizedBox(
              width: 48,
              child: Center(
                  child: Text('Net',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)))),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (context, i) => _IndividualRow(
              entry: entries[i], isActive: isActive),
        ),
      ),
    ]);
  }
}

class _IndividualRow extends StatelessWidget {
  final IndividualEntry entry;
  final bool isActive;
  const _IndividualRow(
      {required this.entry, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final topThree = e.rank <= 3;
    final thruLabel = e.isComplete
        ? 'F'
        : e.holesPlayed > 0
            ? '${e.holesPlayed}'
            : '—';

    return InkWell(
      onTap: e.holeScores.isNotEmpty
          ? () => _showHoles(context, e)
          : null,
      child: Container(
        color: topThree
            ? AppColors.gold.withOpacity(0.05)
            : null,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(children: [
          // Rank
          SizedBox(
              width: 36, child: _RankBadge(rank: e.rank)),

          // Name + handicap
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
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
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: e.isComplete
                        ? AppColors.success.withOpacity(0.12)
                        : e.holesPlayed > 0
                            ? AppColors.warning.withOpacity(0.12)
                            : AppColors.divider,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    thruLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: e.isComplete
                          ? AppColors.success
                          : e.holesPlayed > 0
                              ? AppColors.warning
                              : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),

          // Gross
          SizedBox(
            width: 48,
            child: Center(
              child: Text(
                e.grossScore > 0 ? '${e.grossScore}' : '—',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14),
              ),
            ),
          ),

          // Net
          SizedBox(
            width: 48,
            child: Center(
              child: e.netScore != null
                  ? Text(
                      e.netScore!.toStringAsFixed(1),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.primary),
                    )
                  : Text(
                      e.holesPlayed > 0
                          ? '${e.grossScore}'
                          : '—',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.primary
                            .withOpacity(0.5),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  void _showHoles(BuildContext context, IndividualEntry e) {
    const pars = [4, 4, 3, 4, 5, 3, 4, 4, 5, 4, 3, 4, 5, 4, 3, 4, 5, 4];
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
  const _FourballLeaderboard(
      {required this.entries, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: const Color(0xFF1B3D2C),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const SizedBox(
              width: 36,
              child: Text('#',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12))),
          const Expanded(
              child: Text('Team',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600))),
          if (isActive)
            const SizedBox(
                width: 50,
                child: Center(
                    child: Text('Thru',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12)))),
          const SizedBox(
              width: 64,
              child: Center(
                  child: Text('Net',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)))),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (context, i) =>
              _FourballRow(entry: entries[i], isActive: isActive),
        ),
      ),
    ]);
  }
}

class _FourballRow extends StatelessWidget {
  final FourballEntry entry;
  final bool isActive;
  const _FourballRow(
      {required this.entry, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final thruLabel = e.holesPlayed == 18
        ? 'F'
        : e.holesPlayed > 0
            ? '${e.holesPlayed}'
            : '—';
    return InkWell(
      onTap: () => _showDetail(context, e),
      child: Container(
        color: e.rank <= 3 ? AppColors.gold.withOpacity(0.05) : null,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(children: [
          SizedBox(width: 36, child: _RankBadge(rank: e.rank)),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.teamName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(
                    e.players
                        .map((p) =>
                            '${p.name} (${p.handicap.toStringAsFixed(1)})')
                        .join(' · '),
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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: e.holesPlayed == 18
                        ? AppColors.success.withOpacity(0.12)
                        : e.holesPlayed > 0
                            ? AppColors.warning.withOpacity(0.12)
                            : AppColors.divider,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(thruLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: e.holesPlayed == 18
                              ? AppColors.success
                              : e.holesPlayed > 0
                                  ? AppColors.warning
                                  : AppColors.textSecondary)),
                ),
              ),
            ),
          SizedBox(
            width: 64,
            child: Center(
              child: Text(
                e.netTotal.toStringAsFixed(1),
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
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

// ── Rank badge ────────────────────────────────────────────────────────────────
class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final colors = {
      1: (AppColors.gold, Colors.white),
      2: (const Color(0xFFC0C0C0), Colors.white),
      3: (const Color(0xFFCD7F32), Colors.white),
    };
    final (bg, fg) = colors[rank] ??
        (AppColors.background, AppColors.textPrimary);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(
          child: Text(rank.toString(),
              style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 13))),
    );
  }
}
