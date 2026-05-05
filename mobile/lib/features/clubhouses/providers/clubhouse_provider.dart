import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/clubhouse_model.dart';

// ── Public directory ────────────────────────────────────────────────────────
final publicClubhousesProvider =
    FutureProvider.family<List<ClubhouseModel>, String?>((ref, query) async {
  final api = ref.read(apiClientProvider);
  try {
    final resp = await api.get(
      ApiConstants.clubhouses,
      queryParams: {if (query != null && query.trim().isNotEmpty) 'q': query.trim()},
    );
    final list = resp.data['clubhouses'] as List? ?? [];
    return list
        .map((e) => ClubhouseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});

// ── My clubhouses (admin) ───────────────────────────────────────────────────
final myClubhousesProvider =
    FutureProvider.autoDispose<List<ClubhouseModel>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final resp = await api.get(ApiConstants.myClubhouses);
    final list = resp.data['clubhouses'] as List? ?? [];
    return list
        .map((e) => ClubhouseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});

// ── Single clubhouse page (by slug) ─────────────────────────────────────────
final clubhouseBySlugProvider =
    FutureProvider.family<ClubhousePage, String>((ref, slug) async {
  final api = ref.read(apiClientProvider);
  try {
    final resp = await api.get(ApiConstants.clubhouseBySlug(slug));
    return ClubhousePage.fromJson(resp.data as Map<String, dynamic>);
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});

// ── Mutations ───────────────────────────────────────────────────────────────
class ClubhouseEditNotifier extends StateNotifier<AsyncValue<ClubhouseModel?>> {
  final ApiClient _api;
  ClubhouseEditNotifier(this._api) : super(const AsyncData(null));

  Future<ClubhouseModel?> create(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      final resp = await _api.post(ApiConstants.clubhouses, data: data);
      final ch = ClubhouseModel.fromJson(resp.data['clubhouse'] as Map<String, dynamic>);
      state = AsyncData(ch);
      return ch;
    } on DioException catch (e) {
      state = AsyncError(ApiException.fromDio(e), StackTrace.current);
      return null;
    }
  }

  Future<ClubhouseModel?> update(String id, Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      final resp = await _api.patch(ApiConstants.clubhouseById(id), data: data);
      final ch = ClubhouseModel.fromJson(resp.data['clubhouse'] as Map<String, dynamic>);
      state = AsyncData(ch);
      return ch;
    } on DioException catch (e) {
      state = AsyncError(ApiException.fromDio(e), StackTrace.current);
      return null;
    }
  }
}

final clubhouseEditProvider =
    StateNotifierProvider.autoDispose<ClubhouseEditNotifier, AsyncValue<ClubhouseModel?>>(
  (ref) => ClubhouseEditNotifier(ref.read(apiClientProvider)),
);

// ── Membership actions ──────────────────────────────────────────────────────
class ClubhouseMembershipActions {
  final ApiClient _api;
  ClubhouseMembershipActions(this._api);

  Future<void> follow(String id) async {
    try {
      await _api.post(ApiConstants.clubhouseFollow(id));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> unfollow(String id) async {
    try {
      await _api.delete(ApiConstants.clubhouseFollow(id));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> acceptInvite(String id) async {
    try {
      await _api.post(ApiConstants.clubhouseAcceptInvite(id));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Returns the kind: 'existing_user' or 'email_invite' so the UI can
  /// give the right confirmation message.
  Future<String> invite({
    required String clubhouseId,
    String? userId,
    String? email,
    bool asStaff = false,
  }) async {
    try {
      final resp = await _api.post(
        ApiConstants.clubhouseInvite(clubhouseId),
        data: {
          if (userId != null) 'user_id': userId,
          if (email != null) 'email': email,
          'role': asStaff ? 'staff' : 'member',
        },
      );
      return resp.data['kind'] as String? ?? 'invited';
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final clubhouseMembershipProvider = Provider<ClubhouseMembershipActions>(
  (ref) => ClubhouseMembershipActions(ref.read(apiClientProvider)),
);
