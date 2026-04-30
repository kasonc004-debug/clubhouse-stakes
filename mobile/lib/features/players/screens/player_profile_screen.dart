import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/stats_provider.dart';
import '../providers/player_provider.dart';

class PlayerProfileScreen extends ConsumerWidget {
  final String playerId;
  const PlayerProfileScreen({super.key, required this.playerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(playerProfileProvider(playerId));
    final statsAsync   = ref.watch(playerStatsProvider(playerId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B3D2C)),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              const Text('Could not load profile',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
        data: (player) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _PlayerHeader(player: player, onBack: () => context.pop()),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: _StatsSection(statsAsync: statsAsync),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _PlayerHeader extends StatelessWidget {
  final PlayerProfile player;
  final VoidCallback onBack;
  const _PlayerHeader({required this.player, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final initials = player.name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    final handicapStr = player.handicap == 0
        ? 'Scratch'
        : player.handicap.toStringAsFixed(1);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3D2C), Color(0xFF2A5940)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(children: [
            // Top bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white70, size: 20),
                ),
                const Text(
                  'PLAYER PROFILE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 20),

            // Avatar
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: const Color(0xFFC9A84C), width: 2),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 34,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              player.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),

            // Badges
            Wrap(
              spacing: 8,
              children: [
                if (player.city != null)
                  _Badge(
                    icon: Icons.location_on_outlined,
                    label: player.city!,
                  ),
                _Badge(
                  icon: Icons.sports_golf_rounded,
                  label: 'HCP $handicapStr',
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              )),
        ]),
      );
}

// ── Stats Section ────────────────────────────────────────────────────────────
class _StatsSection extends StatelessWidget {
  final AsyncValue<UserStats> statsAsync;
  const _StatsSection({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    return statsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF1B3D2C)),
        ),
      ),
      error: (_, __) => const Center(
        child: Text('Could not load stats.',
            style: TextStyle(color: AppColors.textSecondary)),
      ),
      data: (stats) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('CAREER RECORD'),
          const SizedBox(height: 12),

          // Medal panel
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(children: [
              Expanded(
                child: _MedalTile(
                  emoji: '🥇',
                  label: 'GOLD',
                  count: stats.golds,
                  color: const Color(0xFFC9A84C),
                ),
              ),
              _VDivider(),
              Expanded(
                child: _MedalTile(
                  emoji: '🥈',
                  label: 'SILVER',
                  count: stats.silvers,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
              _VDivider(),
              Expanded(
                child: _MedalTile(
                  emoji: '🥉',
                  label: 'BRONZE',
                  count: stats.bronzes,
                  color: const Color(0xFFCD7F32),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Earnings + played
          Row(children: [
            Expanded(
              child: _InfoCard(
                icon: Icons.attach_money_rounded,
                label: 'CAREER EARNINGS',
                value: '\$${stats.careerEarnings.toStringAsFixed(0)}',
                color: const Color(0xFF1B3D2C),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoCard(
                icon: Icons.sports_golf_outlined,
                label: 'PLAYED',
                value:
                    '${stats.tournamentsPlayed} / ${stats.tournamentsEntered}',
                color: AppColors.textSecondary,
              ),
            ),
          ]),

          if (stats.totalPodiums == 0 && stats.tournamentsPlayed == 0) ...[
            const SizedBox(height: 32),
            Center(
              child: Column(children: [
                const Icon(Icons.sports_golf_rounded,
                    size: 40, color: AppColors.divider),
                const SizedBox(height: 10),
                const Text(
                  'No tournament history yet.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: AppColors.textSecondary,
        ),
      );
}

class _MedalTile extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final Color color;
  const _MedalTile(
      {required this.emoji,
      required this.label,
      required this.count,
      required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text('$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: AppColors.textSecondary,
            )),
      ]);
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.textSecondary,
                    )),
                const SizedBox(height: 1),
                Text(value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: color,
                    )),
              ],
            ),
          ),
        ]),
      );
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 56, color: AppColors.divider);
}
