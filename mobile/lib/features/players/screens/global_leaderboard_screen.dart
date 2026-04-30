import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/player_provider.dart';

final _leaderboardCityProvider = StateProvider<String?>((ref) => null);

class GlobalLeaderboardTab extends ConsumerWidget {
  const GlobalLeaderboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city    = ref.watch(_leaderboardCityProvider);
    final async   = ref.watch(globalLeaderboardProvider(city));

    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: _FilterBar(
            selected: city,
            onChanged: (c) =>
                ref.read(_leaderboardCityProvider.notifier).state = c,
          ),
        ),

        // List
        Expanded(
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B3D2C)),
            ),
            error: (e, _) => _EmptyState(
              icon: Icons.error_outline,
              message: 'Could not load leaderboard.',
              onRetry: () => ref.invalidate(globalLeaderboardProvider(city)),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return const _EmptyState(
                  icon: Icons.emoji_events_outlined,
                  message: 'No players on the board yet.\nPlay a tournament to appear here.',
                );
              }
              return RefreshIndicator(
                color: const Color(0xFF1B3D2C),
                onRefresh: () async =>
                    ref.invalidate(globalLeaderboardProvider(city)),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      _LeaderRow(rank: i + 1, entry: entries[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _FilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const cities = [
      'All Cities', 'Austin', 'Dallas', 'Houston',
      'San Antonio', 'Scottsdale', 'Denver', 'Nashville',
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = cities[i];
          final value = i == 0 ? null : label;
          final isSelected = selected == value;
          return GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1B3D2C)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1B3D2C)
                      : AppColors.divider,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Leaderboard row ───────────────────────────────────────────────────────────
class _LeaderRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  const _LeaderRow({required this.rank, required this.entry});

  @override
  Widget build(BuildContext context) {
    final initials = entry.name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    final rankEmoji = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };

    return GestureDetector(
      onTap: () => context.push('/player/${entry.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: rank <= 3
              ? _podiumColor(rank).withOpacity(0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: rank <= 3
              ? Border.all(color: _podiumColor(rank).withOpacity(0.25))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 36,
              child: Center(
                child: rankEmoji != null
                    ? Text(rankEmoji,
                        style: const TextStyle(fontSize: 22))
                    : Text(
                        '$rank',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),

            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B3D2C), Color(0xFF3D7055)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + city
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (entry.city != null) ...[
                      const Icon(Icons.location_on_outlined,
                          size: 11, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Text(entry.city!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          )),
                      const SizedBox(width: 8),
                    ],
                    Text('${entry.roundsPlayed} rounds',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        )),
                  ]),
                ],
              ),
            ),

            // Stats
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '\$${entry.careerEarnings.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFC9A84C),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'avg ${entry.avgNetScore.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Color _podiumColor(int rank) => switch (rank) {
        1 => const Color(0xFFC9A84C),
        2 => const Color(0xFF9E9E9E),
        _ => const Color(0xFFCD7F32),
      };
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  const _EmptyState(
      {required this.icon, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.divider),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      );
}
