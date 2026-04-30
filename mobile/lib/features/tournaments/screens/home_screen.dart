import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/tournament_provider.dart';
import '../widgets/tournament_card.dart';

final _cityFilterProvider = StateProvider<String?>((ref) {
  return null; // null = use user's city
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user         = ref.watch(authProvider).user;
    final cityFilter   = ref.watch(_cityFilterProvider);
    final effectiveCity = cityFilter ?? user?.city;
    final tournamentsAsync = ref.watch(tournamentsProvider(effectiveCity));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubhouse Stakes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_city_outlined),
            onPressed: () => _showCityPicker(context, ref, effectiveCity),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(tournamentsProvider(effectiveCity)),
        child: CustomScrollView(
          slivers: [
            // City header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(children: [
                  const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    effectiveCity != null ? effectiveCity : 'All Cities',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  if (cityFilter != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => ref.read(_cityFilterProvider.notifier).state = null,
                      child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                    ),
                  ],
                ]),
              ),
            ),
            // Tournament list
            tournamentsAsync.when(
              loading: () => const SliverFillRemaining(child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary))),
              error: (e, _) => SliverFillRemaining(child: ErrorCard(
                  message: e.toString(), onRetry: () => ref.invalidate(tournamentsProvider(effectiveCity)))),
              data: (tournaments) {
                if (tournaments.isEmpty) {
                  return const SliverFillRemaining(child: EmptyState(
                    icon: Icons.sports_golf,
                    title: 'No tournaments yet',
                    subtitle: 'Check back soon or switch cities to find upcoming events.',
                  ));
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => TournamentCard(
                      tournament: tournaments[index],
                      onTap: () => context.push('/tournament/${tournaments[index].id}'),
                    ),
                    childCount: tournaments.length,
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  void _showCityPicker(BuildContext context, WidgetRef ref, String? current) {
    final cities = ['Austin', 'Dallas', 'Houston', 'San Antonio', 'Denver', 'Nashville'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Select City', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('All Cities'),
            selected: current == null,
            selectedColor: AppColors.primary,
            onTap: () {
              ref.read(_cityFilterProvider.notifier).state = null;
              Navigator.pop(context);
            },
          ),
          ...cities.map((city) => ListTile(
            leading: const Icon(Icons.location_city_outlined),
            title: Text(city),
            selected: current == city,
            selectedColor: AppColors.primary,
            onTap: () {
              ref.read(_cityFilterProvider.notifier).state = city;
              Navigator.pop(context);
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
