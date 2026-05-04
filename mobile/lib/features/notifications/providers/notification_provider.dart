import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/notification_model.dart';

final notificationsProvider =
    FutureProvider.autoDispose<NotificationsPage>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final resp = await api.get(ApiConstants.notifications);
    return NotificationsPage.fromJson(resp.data as Map<String, dynamic>);
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});

/// Lightweight unread-count provider used by the bell badge.
/// Polls every 60s while mounted.
final unreadCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final api = ref.read(apiClientProvider);
  Future<int> fetch() async {
    try {
      final resp = await api.get(
        ApiConstants.notifications,
        queryParams: {'unread_only': 'true', 'limit': '1'},
      );
      return int.tryParse(resp.data['unread']?.toString() ?? '0') ?? 0;
    } catch (_) {
      return 0;
    }
  }
  yield await fetch();
  while (true) {
    await Future.delayed(const Duration(seconds: 60));
    yield await fetch();
  }
});

class NotificationActions {
  final ApiClient _api;
  NotificationActions(this._api);

  Future<void> markRead(String id) async {
    try {
      await _api.post(ApiConstants.markNotificationRead(id));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _api.post(ApiConstants.markAllNotifications);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final notificationActionsProvider = Provider<NotificationActions>(
  (ref) => NotificationActions(ref.read(apiClientProvider)),
);
