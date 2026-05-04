import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../providers/clubhouse_provider.dart';

class MyClubhousesScreen extends ConsumerWidget {
  const MyClubhousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myClubhousesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Clubhouses'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/clubhouses/edit'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Clubhouse',
            style: TextStyle(color: Colors.white)),
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => ErrorCard(
            message: e.toString(),
            onRetry: () => ref.invalidate(myClubhousesProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.flag_outlined,
              title: 'No clubhouses yet',
              subtitle: 'Create one to give your tournaments a home page.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: list.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (_, i) {
              final ch = list[i];
              return ListTile(
                title: Text(ch.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${ch.locationLabel.isEmpty ? '—' : ch.locationLabel} · '
                  '${ch.isPublic ? 'public' : 'private'}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    tooltip: 'View page',
                    onPressed: () =>
                        context.push('/clubhouses/${ch.slug}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit',
                    onPressed: () =>
                        context.push('/clubhouses/edit', extra: ch),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
