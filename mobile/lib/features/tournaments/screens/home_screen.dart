import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../auth/providers/auth_provider.dart';
import '../../players/screens/global_leaderboard_screen.dart';
import '../providers/tournament_provider.dart';
import '../models/tournament_model.dart';
import '../../../core/widgets/clubhouse_logo.dart';

final _tabProvider        = StateProvider<int>((ref) => 0);
final _cityFilterProvider = StateProvider<String?>((ref) => null);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user         = ref.watch(authProvider).user;
    final tab          = ref.watch(_tabProvider);
    final cityFilter   = ref.watch(_cityFilterProvider);
    final effectiveCity = cityFilter ?? user?.city;
    final firstName    = user?.name.split(' ').first ?? 'Golfer';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeroBanner(
              name: firstName,
              effectiveCity: effectiveCity,
              onProfileTap: () => context.push('/profile'),
              onCityTap: () => _showCityPicker(context, ref, effectiveCity),
              onSearchTap: () => context.push('/search'),
              onAdminTap: (user?.isAdmin ?? false) ? () => context.push('/admin') : null,
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _TabRow(
                selected: tab,
                onTap: (i) => ref.read(_tabProvider.notifier).state = i,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          if (tab == 0)
            ..._upcomingTab(ref, effectiveCity, context)
          else if (tab == 1)
            ..._myEventsTab(ref, context)
          else
            ..._leaderboardTab(),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  List<Widget> _upcomingTab(WidgetRef ref, String? city, BuildContext context) {
    final tournamentsAsync = ref.watch(tournamentsProvider(city));
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'UPCOMING TOURNAMENTS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => ref.invalidate(tournamentsProvider(city)),
                child: const Icon(Icons.refresh_rounded,
                    size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      tournamentsAsync.when(
        loading: () => const SliverFillRemaining(
          child: Center(
              child: CircularProgressIndicator(color: AppColors.primary))),
        error: (e, _) => SliverToBoxAdapter(
          child: ErrorCard(
            message: e.toString(),
            onRetry: () => ref.invalidate(tournamentsProvider(city)),
          ),
        ),
        data: (tournaments) {
          if (tournaments.isEmpty) {
            return const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.sports_golf,
                title: 'No tournaments yet',
                subtitle: 'Check back soon or switch cities.',
              ),
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _MatchCard(
                tournament: tournaments[i],
                onTap: () => context.push('/tournament/${tournaments[i].id}'),
              ),
              childCount: tournaments.length,
            ),
          );
        },
      ),
    ];
  }

  List<Widget> _leaderboardTab() => [
    const SliverFillRemaining(
      hasScrollBody: true,
      child: GlobalLeaderboardTab(),
    ),
  ];

  List<Widget> _myEventsTab(WidgetRef ref, BuildContext context) {
    final myAsync = ref.watch(myTournamentsProvider);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MY EVENTS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => ref.invalidate(myTournamentsProvider),
                child: const Icon(Icons.refresh_rounded,
                    size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      myAsync.when(
        loading: () => const SliverFillRemaining(
          child: Center(
              child: CircularProgressIndicator(color: AppColors.primary))),
        error: (e, _) => SliverToBoxAdapter(
          child: ErrorCard(
            message: e.toString(),
            onRetry: () => ref.invalidate(myTournamentsProvider),
          ),
        ),
        data: (tournaments) {
          if (tournaments.isEmpty) {
            return const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.calendar_today_outlined,
                title: 'No events yet',
                subtitle: 'Register for a tournament to see it here.',
              ),
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final t = tournaments[i];
                return _MatchCard(
                  tournament: t,
                  onTap: () => context.push('/tournament/${t.id}'),
                  enrolled: true,
                  onScoreTap: t.status == 'active'
                      ? () => context.push('/tournament/${t.id}/score')
                      : null,
                );
              },
              childCount: tournaments.length,
            ),
          );
        },
      ),
    ];
  }

  void _showCityPicker(
      BuildContext context, WidgetRef ref, String? current) {
    final cities = [
      'Austin', 'Dallas', 'Houston', 'San Antonio',
      'Scottsdale', 'Denver', 'Nashville',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('SELECT CITY',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AppColors.textPrimary,
              )),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.public, color: AppColors.primary),
            title: const Text('All Cities',
                style: TextStyle(fontWeight: FontWeight.w600)),
            selected: current == null,
            selectedColor: AppColors.primary,
            onTap: () {
              ref.read(_cityFilterProvider.notifier).state = null;
              Navigator.pop(context);
            },
          ),
          ...cities.map((city) => ListTile(
                leading: const Icon(Icons.location_city_outlined,
                    color: AppColors.textSecondary),
                title: Text(city,
                    style:
                        const TextStyle(fontWeight: FontWeight.w500)),
                selected: current == city,
                selectedColor: AppColors.primary,
                onTap: () {
                  ref.read(_cityFilterProvider.notifier).state = city;
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Hero Banner ──────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final String name;
  final String? effectiveCity;
  final VoidCallback onProfileTap;
  final VoidCallback onCityTap;
  final VoidCallback? onAdminTap;

  final VoidCallback onSearchTap;

  const _HeroBanner({
    required this.name,
    required this.effectiveCity,
    required this.onProfileTap,
    required this.onCityTap,
    required this.onSearchTap,
    this.onAdminTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B3D2C),
            Color(0xFF2A5940),
            Color(0xFF3D7055),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo
                      const _InlineLogo(),
                      Row(children: [
                        IconButton(
                          icon: const Icon(Icons.search_rounded,
                              color: Colors.white70, size: 22),
                          onPressed: onSearchTap,
                        ),
                        if (onAdminTap != null)
                          IconButton(
                            icon: const Icon(
                                Icons.admin_panel_settings_outlined,
                                color: Colors.white70,
                                size: 22),
                            onPressed: onAdminTap,
                          ),
                        GestureDetector(
                          onTap: onProfileTap,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.15),
                              border:
                                  Border.all(color: Colors.white30, width: 2),
                            ),
                            child: const Icon(Icons.person,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ]),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'HELLO',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    '${name.toUpperCase()}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: onCityTap,
                    child: Row(children: [
                      const Icon(Icons.location_on_outlined,
                          color: Color(0xFFC9A84C), size: 14),
                      const SizedBox(width: 5),
                      Text(
                        effectiveCity ?? 'All Cities',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white60, size: 16),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab Row ──────────────────────────────────────────────────────────────────
class _TabRow extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;

  const _TabRow({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const tabs = ['UPCOMING', 'MY EVENTS', 'LEADERS'];
    return Row(
      children: List.generate(tabs.length, (i) {
        final isSelected = i == selected;
        return Padding(
          padding: EdgeInsets.only(right: i < tabs.length - 1 ? 10 : 0),
          child: GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1B3D2C)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1B3D2C)
                      : AppColors.divider,
                  width: 1.5,
                ),
              ),
              child: Text(
                tabs[i],
                style: TextStyle(
                  color:
                      isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Match Card ───────────────────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final TournamentModel tournament;
  final VoidCallback onTap;
  final VoidCallback? onScoreTap;
  final bool enrolled;

  const _MatchCard({
    required this.tournament,
    required this.onTap,
    this.onScoreTap,
    this.enrolled = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Green header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B3D2C), Color(0xFF3D7055)],
                ),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(18)),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (t.courseName != null)
                          Text(
                            t.courseName!.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFC9A84C),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                        Text(
                          t.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (enrolled)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC9A84C).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFC9A84C), width: 1),
                      ),
                      child: const Text(
                        'ENROLLED',
                        style: TextStyle(
                          color: Color(0xFFC9A84C),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  _FormatBadge(format: t.format),
                ],
              ),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _InfoPill(
                      icon: Icons.calendar_today_outlined,
                      label: DateFormat('MMM d, yyyy').format(t.date),
                    ),
                    const SizedBox(width: 10),
                    _InfoPill(
                      icon: Icons.location_on_outlined,
                      label: t.city,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _StatBox(
                        label: 'ENTRY',
                        value: '\$${t.signUpFee.toStringAsFixed(0)}',
                        sub: 'per ${t.feePer}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatBox(
                        label: 'PURSE',
                        value: '\$${t.purse.toStringAsFixed(0)}',
                        sub: 'total',
                        accent: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatBox(
                        label: 'SPOTS',
                        value: '${t.spotsLeft}',
                        sub: 'remaining',
                        warn: t.isFull,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatusChip(status: t.status),
                      const Row(children: [
                        Text('View details',
                            style: TextStyle(
                              color: Color(0xFF1B3D2C),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            )),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios,
                            size: 11, color: Color(0xFF1B3D2C)),
                      ]),
                    ],
                  ),
                  // Enter score CTA when tournament is active
                  if (onScoreTap != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: onScoreTap,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1B3D2C), Color(0xFF3D7055)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sports_golf, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'ENTER SCORE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              )),
        ],
      );
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final bool accent;
  final bool warn;

  const _StatBox({
    required this.label,
    required this.value,
    required this.sub,
    this.accent = false,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = warn
        ? AppColors.error
        : accent
            ? const Color(0xFFC9A84C)
            : AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent
            ? const Color(0xFFC9A84C).withOpacity(0.08)
            : AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.textSecondary,
              )),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: valueColor,
              )),
          Text(sub,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              )),
        ],
      ),
    );
  }
}

class _InlineLogo extends StatelessWidget {
  const _InlineLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.emoji_events_rounded,
          color: Color(0xFFC9A84C),
          size: 26,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'CLUBHOUSE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                height: 1.1,
              ),
            ),
            Text(
              'STAKES',
              style: TextStyle(
                color: Color(0xFFC9A84C),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormatBadge extends StatelessWidget {
  final String format;
  const _FormatBadge({required this.format});

  @override
  Widget build(BuildContext context) {
    final label = format == 'fourball' ? 'FOUR-BALL' : 'STROKE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          )),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      'active'    => (AppColors.success, AppColors.success.withOpacity(0.12)),
      'completed' => (AppColors.textSecondary, AppColors.divider),
      _           => (const Color(0xFF1B3D2C), const Color(0xFF1B3D2C).withOpacity(0.1)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
