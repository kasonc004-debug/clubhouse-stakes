import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../models/clubhouse_model.dart';
import '../providers/clubhouse_provider.dart';

class ClubhouseDirectoryScreen extends ConsumerStatefulWidget {
  const ClubhouseDirectoryScreen({super.key});

  @override
  ConsumerState<ClubhouseDirectoryScreen> createState() =>
      _ClubhouseDirectoryScreenState();
}

class _ClubhouseDirectoryScreenState
    extends ConsumerState<ClubhouseDirectoryScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String? _query;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(publicClubhousesProvider(_query));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Clubhouses'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: 'Search by name or course',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() => _query = null);
                      },
                    ),
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () {
                if (mounted) setState(() => _query = v.trim().isEmpty ? null : v.trim());
              });
            },
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => ErrorCard(
                message: e.toString(),
                onRetry: () => ref.invalidate(publicClubhousesProvider(_query))),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.flag_outlined,
                  title: 'No clubhouses yet',
                  subtitle: 'Public clubhouses will appear here.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (_, i) => _Tile(clubhouse: list[i]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

Color _hex(String s) {
  final h = s.replaceAll('#', '');
  final v = int.tryParse(h.length == 6 ? 'ff$h' : h, radix: 16) ?? 0xff1B3D2C;
  return Color(v);
}

class _Tile extends StatelessWidget {
  final ClubhouseModel clubhouse;
  const _Tile({required this.clubhouse});

  @override
  Widget build(BuildContext context) {
    final ch = clubhouse;
    final primary = _hex(ch.primaryColor);
    return ListTile(
      onTap: () => context.push('/clubhouses/${ch.slug}'),
      leading: SizedBox(
        width: 48, height: 48,
        child: ch.logoUrl != null && ch.logoUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: ch.logoUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                      color: primary.withOpacity(0.15),
                      child: Icon(Icons.flag, color: primary)),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.flag, color: primary),
              ),
      ),
      title: Text(ch.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(
        [
          if (ch.courseName != null && ch.courseName!.isNotEmpty) ch.courseName!,
          if (ch.locationLabel.isNotEmpty) ch.locationLabel,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: ch.isPublicCourse
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFC9A84C).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('PUBLIC COURSE',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: Color(0xFFC9A84C))),
            )
          : const Icon(Icons.chevron_right),
    );
  }
}
