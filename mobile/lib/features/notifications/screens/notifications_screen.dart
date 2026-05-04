import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (async.valueOrNull?.unread != null && async.valueOrNull!.unread > 0)
            TextButton(
              onPressed: () async {
                await ref.read(notificationActionsProvider).markAllRead();
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadCountProvider);
              },
              child: const Text('Read all',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: async.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => ErrorCard(
              message: e.toString(),
              onRetry: () => ref.invalidate(notificationsProvider)),
          data: (page) {
            if (page.notifications.isEmpty) {
              return const EmptyState(
                icon: Icons.notifications_none,
                title: 'No notifications yet',
                subtitle:
                    'Clubhouse invites and tournament announcements appear here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
              itemCount: page.notifications.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (_, i) {
                final n = page.notifications[i];
                return _NotificationTile(
                  n: n,
                  onTap: () async {
                    if (n.isUnread) {
                      await ref.read(notificationActionsProvider).markRead(n.id);
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadCountProvider);
                    }
                    if (!context.mounted) return;
                    final link = n.link;
                    if (link != null && link.isNotEmpty) {
                      context.push(link);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel n;
  final VoidCallback onTap;
  const _NotificationTile({required this.n, required this.onTap});

  IconData get _icon {
    switch (n.type) {
      case 'clubhouse_invite':     return Icons.flag_outlined;
      case 'clubhouse_tournament': return Icons.sports_golf;
      default:                      return Icons.notifications_outlined;
    }
  }

  Color get _color {
    switch (n.type) {
      case 'clubhouse_invite':     return const Color(0xFFC9A84C);
      case 'clubhouse_tournament': return AppColors.primary;
      default:                      return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: n.isUnread ? AppColors.primary.withOpacity(0.04) : null,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, color: _color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(n.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: n.isUnread
                            ? FontWeight.w800
                            : FontWeight.w600,
                      )),
                ),
                if (n.isUnread) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                  ),
                ],
              ]),
              if (n.body != null && n.body!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(n.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
              const SizedBox(height: 4),
              Text(_relative(n.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
      ),
    );
  }

  String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24)   return '${d.inHours}h ago';
    if (d.inDays < 7)     return '${d.inDays}d ago';
    return DateFormat('MMM d').format(t);
  }
}
