import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/player_provider.dart';

class PlayerSearchScreen extends ConsumerStatefulWidget {
  const PlayerSearchScreen({super.key});

  @override
  ConsumerState<PlayerSearchScreen> createState() => _PlayerSearchScreenState();
}

class _PlayerSearchScreenState extends ConsumerState<PlayerSearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _SearchHeader(
            ctrl: _ctrl,
            onChanged: (v) => setState(() => _query = v),
            onBack: () => context.pop(),
          ),
          Expanded(child: _SearchBody(query: _query)),
        ],
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _SearchHeader extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
  final VoidCallback onBack;

  const _SearchHeader({
    required this.ctrl,
    required this.onChanged,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3D2C), Color(0xFF2A5940)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white70, size: 20),
                ),
                const Text(
                  'PLAYER SEARCH',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name…',
                    hintStyle:
                        TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.white60, size: 22),
                    suffixIcon: ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white60, size: 18),
                            onPressed: () {
                              ctrl.clear();
                              onChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────
class _SearchBody extends ConsumerWidget {
  final String query;
  const _SearchBody({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.trim().length < 2) {
      return _EmptyPrompt(
        icon: Icons.person_search_outlined,
        message: 'Type at least 2 characters\nto search for players.',
      );
    }

    final resultsAsync = ref.watch(playerSearchProvider(query.trim()));
    return resultsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1B3D2C)),
      ),
      error: (e, _) => _EmptyPrompt(
        icon: Icons.error_outline,
        message: 'Search failed. Check your connection.',
      ),
      data: (players) {
        if (players.isEmpty) {
          return _EmptyPrompt(
            icon: Icons.search_off_rounded,
            message: 'No players found for\n"$query"',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          itemCount: players.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) =>
              _PlayerTile(player: players[i]),
        );
      },
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final PlayerProfile player;
  const _PlayerTile({required this.player});

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

    return GestureDetector(
      onTap: () => context.push('/player/${player.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B3D2C), Color(0xFF3D7055)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    if (player.city != null) ...[
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(player.city!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          )),
                      const SizedBox(width: 10),
                    ],
                    const Icon(Icons.sports_golf_rounded,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text('HCP $handicapStr',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        )),
                  ]),
                ],
              ),
            ),

            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyPrompt({required this.icon, required this.message});

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
          ],
        ),
      );
}
