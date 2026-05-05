import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../clubhouses/providers/clubhouse_provider.dart';
import '../../notifications/widgets/bell_button.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/clubhouse_logo.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/tournament_provider.dart';
import '../models/tournament_model.dart';

// 0=UPCOMING  1=LIVE  2=MY EVENTS  3=PAST
final _tabProvider        = StateProvider<int>((ref) => 0);
final _cityFilterProvider = StateProvider<String?>((ref) => null);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user        = ref.watch(authProvider).user;
    final tab         = ref.watch(_tabProvider);
    final city        = ref.watch(_cityFilterProvider) ?? user?.city;
    final firstName   = user?.name.split(' ').first ?? 'Golfer';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeroBanner(
              name: firstName,
              effectiveCity: city,
              onProfileTap: () => context.push('/profile'),
              onCityTap:    () => _showCityPicker(context, ref, city),
              onSearchTap:  () => context.push('/search'),
              onAdminTap:   (user?.isAdmin ?? false)
                  ? () => context.push('/admin')
                  : null,
            ),
          ),

          // My Clubhouse quick-access card (only renders if user has any).
          const SliverToBoxAdapter(child: _MyClubhouseCard()),

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

          if (tab == 0) ..._upcomingSliver(ref, city, context)
          else if (tab == 1) ..._liveSliver(ref, context, user)
          else if (tab == 2) ..._myEventsSliver(ref, context, user)
          else ..._pastSliver(ref, context),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── Upcoming ────────────────────────────────────────────────
  List<Widget> _upcomingSliver(
      WidgetRef ref, String? city, BuildContext context) {
    final async = ref.watch(tournamentsProvider(city));
    return [
      _sectionHeader('UPCOMING TOURNAMENTS', onRefresh: () =>
          ref.invalidate(tournamentsProvider(city))),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      async.when(
        loading: () => _loadingSliver(),
        error: (e, _) => _errorSliver(e, () => ref.invalidate(tournamentsProvider(city))),
        data: (list) {
          if (list.isEmpty) {
            return _emptySliver(
              icon: Icons.sports_golf,
              title: 'No upcoming tournaments',
              sub: 'Check back soon or switch cities.',
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _TournamentCard(
                tournament: list[i],
                onTap: () => context.push('/tournament/${list[i].id}'),
              ),
              childCount: list.length,
            ),
          );
        },
      ),
    ];
  }

  // ── Live ─────────────────────────────────────────────────────
  List<Widget> _liveSliver(
      WidgetRef ref, BuildContext context, dynamic user) {
    final async = ref.watch(activeTournamentsProvider);
    return [
      _sectionHeader('LIVE TOURNAMENTS', live: true,
          onRefresh: () => ref.invalidate(activeTournamentsProvider)),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      async.when(
        loading: () => _loadingSliver(),
        error: (e, _) =>
            _errorSliver(e, () => ref.invalidate(activeTournamentsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return _emptySliver(
              icon: Icons.radio_button_checked,
              title: 'No live tournaments right now',
              sub: 'Check the upcoming tab for what\'s next.',
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final t = list[i];
                final enrolled = t.isEnrolled;
                return _LiveCard(
                  tournament: t,
                  enrolled: enrolled,
                  onTap: enrolled
                      ? () => context.push('/tournament/${t.id}/score')
                      : () => context.push('/tournament/${t.id}'),
                  onLeaderboard: () =>
                      context.push('/leaderboard/${t.id}'),
                  onEnterScore: enrolled
                      ? () => context.push('/tournament/${t.id}/score')
                      : null,
                );
              },
              childCount: list.length,
            ),
          );
        },
      ),
    ];
  }

  // ── My Events ────────────────────────────────────────────────
  List<Widget> _myEventsSliver(
      WidgetRef ref, BuildContext context, dynamic user) {
    if (user == null) {
      return [
        _emptySliver(
          icon: Icons.lock_outline,
          title: 'Sign in to see your events',
          sub: '',
        ),
      ];
    }
    final async = ref.watch(myTournamentsProvider);
    return [
      _sectionHeader('MY EVENTS',
          onRefresh: () => ref.invalidate(myTournamentsProvider)),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      async.when(
        loading: () => _loadingSliver(),
        error: (e, _) =>
            _errorSliver(e, () => ref.invalidate(myTournamentsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return _emptySliver(
              icon: Icons.calendar_today_outlined,
              title: 'No events yet',
              sub: 'Register for a tournament to see it here.',
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final t = list[i];
                final isLive = t.status == 'active';
                final isDone = t.status == 'completed';
                return _MyEventCard(
                  tournament: t,
                  onTap: isLive
                      ? () => context.push('/tournament/${t.id}/score')
                      : () => context.push('/tournament/${t.id}'),
                  onSecondaryTap: isLive
                      ? () => context.push('/leaderboard/${t.id}')
                      : isDone
                          ? () => context.push('/leaderboard/${t.id}')
                          : null,
                  secondaryLabel: isLive
                      ? 'VIEW LEADERBOARD'
                      : isDone
                          ? 'VIEW RESULTS'
                          : null,
                );
              },
              childCount: list.length,
            ),
          );
        },
      ),
    ];
  }

  // ── Past ─────────────────────────────────────────────────────
  List<Widget> _pastSliver(WidgetRef ref, BuildContext context) {
    final async = ref.watch(pastTournamentsProvider);
    return [
      _sectionHeader('PAST TOURNAMENTS',
          onRefresh: () => ref.invalidate(pastTournamentsProvider)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GestureDetector(
            onTap: () => context.push('/best-rounds'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFC9A84C).withOpacity(0.4),
                    width: 1.5),
              ),
              child: Row(children: [
                const Icon(Icons.emoji_events_outlined,
                    color: Color(0xFFC9A84C), size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Record Book',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                        Text('Best individual + four-ball rounds',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                      ]),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
              ]),
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 14)),
      async.when(
        loading: () => _loadingSliver(),
        error: (e, _) =>
            _errorSliver(e, () => ref.invalidate(pastTournamentsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return _emptySliver(
              icon: Icons.history,
              title: 'No completed tournaments yet',
              sub: '',
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _PastCard(
                tournament: list[i],
                onResults: () =>
                    context.push('/leaderboard/${list[i].id}'),
              ),
              childCount: list.length,
            ),
          );
        },
      ),
    ];
  }

  // ── Shared sliver helpers ─────────────────────────────────────
  SliverToBoxAdapter _sectionHeader(String title,
      {bool live = false, required VoidCallback onRefresh}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            if (live) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: AppColors.textPrimary,
                  )),
            ),
            GestureDetector(
              onTap: onRefresh,
              child: const Icon(Icons.refresh_rounded,
                  size: 20, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingSliver() => const SliverFillRemaining(
    child: Center(
        child: CircularProgressIndicator(color: AppColors.primary)),
  );

  Widget _errorSliver(Object e, VoidCallback retry) => SliverToBoxAdapter(
    child: ErrorCard(message: e.toString(), onRetry: retry),
  );

  Widget _emptySliver(
          {required IconData icon,
          required String title,
          required String sub}) =>
      SliverToBoxAdapter(
        child: EmptyState(icon: icon, title: title, subtitle: sub),
      );

  void _showCityPicker(
      BuildContext context, WidgetRef ref, String? current) {
    const cities = [
      'Austin', 'Dallas', 'Houston', 'San Antonio',
      'Kansas City', 'Scottsdale', 'Denver', 'Nashville',
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
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('SELECT CITY',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppColors.textPrimary)),
          const Divider(height: 24),
          ListTile(
            leading:
                const Icon(Icons.public, color: AppColors.primary),
            title: const Text('All Cities',
                style: TextStyle(fontWeight: FontWeight.w600)),
            selected: current == null,
            selectedColor: AppColors.primary,
            onTap: () {
              ref.read(_cityFilterProvider.notifier).state = null;
              Navigator.pop(context);
            },
          ),
          ...cities.map((c) => ListTile(
                leading: const Icon(Icons.location_city_outlined,
                    color: AppColors.textSecondary),
                title: Text(c,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                selected: current == c,
                selectedColor: AppColors.primary,
                onTap: () {
                  ref.read(_cityFilterProvider.notifier).state = c;
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Tab row ───────────────────────────────────────────────────────────────────
class _TabRow extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _TabRow({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const tabs = ['UPCOMING', 'LIVE', 'MY EVENTS', 'PAST'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final sel = i == selected;
          final isLive = i == 1;
          return Padding(
            padding: EdgeInsets.only(right: i < tabs.length - 1 ? 10 : 0),
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: sel
                      ? (isLive ? AppColors.error : const Color(0xFF1B3D2C))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: sel
                        ? (isLive ? AppColors.error : const Color(0xFF1B3D2C))
                        : AppColors.divider,
                    width: 1.5,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isLive && !sel) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(tabs[i],
                      style: TextStyle(
                        color: sel ? Colors.white : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      )),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Hero Banner ───────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final String name;
  final String? effectiveCity;
  final VoidCallback onProfileTap, onCityTap, onSearchTap;
  final VoidCallback? onAdminTap;
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3D2C), Color(0xFF2A5940), Color(0xFF3D7055)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40, right: -30,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 20, right: 40,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top action bar — right-aligned
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const BellButton(),
                      IconButton(
                        tooltip: 'Clubhouses',
                        icon: const Icon(Icons.flag_outlined,
                            color: Colors.white70, size: 22),
                        onPressed: () => context.push('/clubhouses'),
                      ),
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
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: onProfileTap,
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(
                                color: Colors.white30, width: 2),
                          ),
                          child: const Icon(Icons.person,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Big centered wordmark
                  const Center(child: ClubhouseLogo(width: 260)),
                  const SizedBox(height: 18),

                  // Welcome line
                  if (name.trim().isNotEmpty)
                    Center(
                      child: Text(
                        'Welcome back, ${name.split(' ').first}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // City filter pill (centered)
                  Center(
                    child: GestureDetector(
                      onTap: onCityTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: const Color(0xFFC9A84C).withOpacity(0.5)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.location_on_outlined,
                              color: Color(0xFFC9A84C), size: 16),
                          const SizedBox(width: 6),
                          Text(effectiveCity ?? 'All Cities',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down,
                              color: Colors.white70, size: 16),
                        ]),
                      ),
                    ),
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

// ── My Clubhouse quick-access card ───────────────────────────────────────────
class _MyClubhouseCard extends ConsumerWidget {
  const _MyClubhouseCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myClubhousesProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();

        // 1 clubhouse → tap goes straight to it. 2+ → goes to the list.
        final single = list.length == 1 ? list.first : null;
        final subtitle = single != null
            ? (single.locationLabel.isEmpty
                ? (single.myRole == 'staff' ? 'You\'re staff' : 'You\'re the owner')
                : single.locationLabel)
            : '${list.length} clubhouses you manage';
        final title = single != null ? single.name : 'My Clubhouses';

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: GestureDetector(
            onTap: () {
              if (single != null) {
                context.push('/clubhouses/${single.slug}');
              } else {
                context.push('/clubhouses/mine');
              }
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B3D2C), Color(0xFF2A5940)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFC9A84C).withOpacity(0.55),
                    width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A84C).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFC9A84C).withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.flag,
                      color: Color(0xFFC9A84C), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MY CLUBHOUSE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Color(0xFFC9A84C),
                          )),
                      const SizedBox(height: 2),
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right,
                    color: Colors.white70, size: 20),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ── Generic upcoming tournament card ─────────────────────────────────────────
class _TournamentCard extends StatelessWidget {
  final TournamentModel tournament;
  final VoidCallback onTap;
  const _TournamentCard({required this.tournament, required this.onTap});

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
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Green header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF1B3D2C), Color(0xFF3D7055)]),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (t.courseName != null)
                        Text(t.courseName!.toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFFC9A84C),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5)),
                      Text(t.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
              _FormatBadge(format: t.format),
            ]),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _Pill(Icons.calendar_today_outlined,
                        DateFormat('MMM d, yyyy').format(t.date)),
                    const SizedBox(width: 10),
                    _Pill(Icons.location_on_outlined, t.city),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                        child: _StatBox('ENTRY',
                            '\$${t.signUpFee.toStringAsFixed(0)}',
                            'per ${t.feePer}')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatBox(
                            'PURSE', '\$${t.purse.toStringAsFixed(0)}', 'total',
                            accent: true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatBox('SPOTS', '${t.spotsLeft}', 'remaining',
                            warn: t.isFull)),
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
                                  fontWeight: FontWeight.w600)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios,
                              size: 11, color: Color(0xFF1B3D2C)),
                        ]),
                      ]),
                ]),
          ),
        ]),
      ),
    );
  }
}

// ── Live tournament card ───────────────────────────────────────────────────────
class _LiveCard extends StatelessWidget {
  final TournamentModel tournament;
  final bool enrolled;
  final VoidCallback onTap, onLeaderboard;
  final VoidCallback? onEnterScore;
  const _LiveCard({
    required this.tournament,
    required this.enrolled,
    required this.onTap,
    required this.onLeaderboard,
    this.onEnterScore,
  });

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.error.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header with LIVE badge
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF1B3D2C), Color(0xFF3D7055)]),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (t.courseName != null)
                        Text(t.courseName!.toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFFC9A84C),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5)),
                      Text(t.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
              // Live badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
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
            ]),
          ),
        ),

        // Info row
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Row(children: [
              _Pill(Icons.calendar_today_outlined,
                  DateFormat('MMM d, yyyy').format(t.date)),
              const SizedBox(width: 10),
              _Pill(Icons.location_on_outlined, t.city),
              const Spacer(),
              _Pill(Icons.people_outlined, '${t.playerCount} players'),
            ]),
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: Row(children: [
            // Leaderboard always available
            Expanded(
              child: _ActionButton(
                label: 'LEADERBOARD',
                icon: Icons.leaderboard_outlined,
                outlined: true,
                onTap: onLeaderboard,
              ),
            ),
            if (onEnterScore != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'ENTER SCORE',
                  icon: Icons.sports_golf,
                  onTap: onEnterScore!,
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── My Event card ─────────────────────────────────────────────────────────────
class _MyEventCard extends StatelessWidget {
  final TournamentModel tournament;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;
  final String? secondaryLabel;
  const _MyEventCard({
    required this.tournament,
    required this.onTap,
    this.onSecondaryTap,
    this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final isLive = t.status == 'active';
    final isDone = t.status == 'completed';

    final headerGrad = isLive
        ? const LinearGradient(
            colors: [Color(0xFF7B1818), Color(0xFFB23030)])
        : const LinearGradient(
            colors: [Color(0xFF1B3D2C), Color(0xFF3D7055)]);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: isLive
            ? Border.all(
                color: AppColors.error.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: headerGrad,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (t.courseName != null)
                        Text(t.courseName!.toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFFC9A84C),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5)),
                      Text(t.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
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
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A84C).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFC9A84C), width: 1),
                  ),
                  child: Text(
                    isDone ? 'COMPLETED' : 'ENROLLED',
                    style: const TextStyle(
                        color: Color(0xFFC9A84C),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1),
                  ),
                ),
            ]),
          ),
        ),

        // Date / city / purse
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _Pill(Icons.calendar_today_outlined,
                        DateFormat('MMM d, yyyy').format(t.date)),
                    const SizedBox(width: 10),
                    _Pill(Icons.location_on_outlined, t.city),
                  ]),
                  const SizedBox(height: 10),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Purse: \$${t.purse.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFC9A84C)),
                        ),
                        Text(
                          '${t.playerCount} players',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ]),
                ]),
          ),
        ),

        // Action buttons
        if (isLive || isDone)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Row(children: [
              if (isLive)
                Expanded(
                  child: _ActionButton(
                    label: 'ENTER SCORE',
                    icon: Icons.sports_golf,
                    onTap: onTap,
                  ),
                ),
              if (isLive && onSecondaryTap != null)
                const SizedBox(width: 10),
              if (onSecondaryTap != null)
                Expanded(
                  child: _ActionButton(
                    label: secondaryLabel ?? 'VIEW',
                    icon: Icons.leaderboard_outlined,
                    outlined: true,
                    onTap: onSecondaryTap!,
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

// ── Past tournament card ───────────────────────────────────────────────────────
class _PastCard extends StatelessWidget {
  final TournamentModel tournament;
  final VoidCallback onResults;
  const _PastCard({required this.tournament, required this.onResults});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Greyed header for completed
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1B3D2C).withOpacity(0.6),
                const Color(0xFF3D7055).withOpacity(0.6),
              ],
            ),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (t.courseName != null)
                      Text(t.courseName!.toUpperCase(),
                          style: const TextStyle(
                              color: Color(0xFFC9A84C),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5)),
                    Text(t.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('COMPLETED',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ),
          ]),
        ),

        // Details + results button
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _Pill(Icons.calendar_today_outlined,
                      DateFormat('MMM d, yyyy').format(t.date)),
                  const SizedBox(width: 10),
                  _Pill(Icons.location_on_outlined, t.city),
                ]),
                const SizedBox(height: 10),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Purse: \$${t.purse.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFC9A84C))),
                      Text('${t.playerCount} players',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ]),
                const SizedBox(height: 12),
                _ActionButton(
                  label: 'VIEW RESULTS',
                  icon: Icons.emoji_events_outlined,
                  outlined: true,
                  onTap: onResults,
                ),
              ]),
        ),
      ]),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : const Color(0xFF1B3D2C),
        borderRadius: BorderRadius.circular(12),
        border: outlined
            ? Border.all(color: const Color(0xFF1B3D2C), width: 1.5)
            : null,
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon,
            color: outlined ? const Color(0xFF1B3D2C) : Colors.white,
            size: 16),
        const SizedBox(width: 7),
        Text(label,
            style: TextStyle(
                color: outlined ? const Color(0xFF1B3D2C) : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      ]),
    ),
  );
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill(this.icon, this.label);

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
              fontWeight: FontWeight.w500)),
    ],
  );
}

class _StatBox extends StatelessWidget {
  final String label, value, sub;
  final bool accent, warn;
  const _StatBox(this.label, this.value, this.sub,
      {this.accent = false, this.warn = false});

  @override
  Widget build(BuildContext context) {
    final c = warn
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: c)),
        Text(sub,
            style: const TextStyle(
                fontSize: 9, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _FormatBadge extends StatelessWidget {
  final String format;
  const _FormatBadge({required this.format});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      format == 'fourball' ? '4-BALL' : 'STROKE',
      style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      'active'    => (AppColors.error, AppColors.error.withOpacity(0.12)),
      'completed' => (AppColors.textSecondary, AppColors.divider),
      _           => (const Color(0xFF1B3D2C),
                      const Color(0xFF1B3D2C).withOpacity(0.08)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1)),
    );
  }
}
