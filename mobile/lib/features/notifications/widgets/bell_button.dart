import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/notification_provider.dart';

class BellButton extends ConsumerWidget {
  final Color color;
  final double size;
  const BellButton({super.key, this.color = Colors.white70, this.size = 22});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(
        tooltip: 'Notifications',
        onPressed: () => context.push('/notifications'),
        icon: Icon(Icons.notifications_outlined, color: color, size: size),
      ),
      if (unread > 0)
        Positioned(
          right: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFC9A84C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              unread > 99 ? '99+' : '$unread',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.w900),
            ),
          ),
        ),
    ]);
  }
}
