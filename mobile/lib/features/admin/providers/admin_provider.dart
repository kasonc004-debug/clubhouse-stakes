import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/financials_model.dart';

// ── Financials fetch ──────────────────────────────────────────────────────────

final adminFinancialsProvider = FutureProvider.autoDispose
    .family<FinancialsModel, String>((ref, id) async {
  final api  = ref.read(apiClientProvider);
  final resp = await api.get(ApiConstants.adminFinancials(id));
  return FinancialsModel.fromJson(resp.data['financials'] as Map<String, dynamic>);
});

// ── Financials update ─────────────────────────────────────────────────────────

class UpdateFinancialsNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _api;
  UpdateFinancialsNotifier(this._api) : super(const AsyncData(null));

  Future<bool> save(
    String tournamentId, {
    double? houseCutPct,
    double? skinsFee,
    List<PayoutPlace>? payoutPlaces,
  }) async {
    state = const AsyncLoading();
    try {
      final body = <String, dynamic>{};
      if (houseCutPct  != null) body['house_cut_pct']  = houseCutPct;
      if (skinsFee     != null) body['skins_fee']       = skinsFee;
      if (payoutPlaces != null) body['payout_places']   = payoutPlaces.map((p) => p.toJson()).toList();

      await _api.patch(ApiConstants.adminFinancials(tournamentId), data: body);
      state = const AsyncData(null);
      return true;
    } on DioException catch (e) {
      state = AsyncError(ApiException.fromDio(e), StackTrace.current);
      return false;
    }
  }
}

final updateFinancialsProvider = StateNotifierProvider.autoDispose
    .family<UpdateFinancialsNotifier, AsyncValue<void>, String>((ref, _) {
  return UpdateFinancialsNotifier(ref.read(apiClientProvider));
});

// ── Participants fetch ────────────────────────────────────────────────────────

final adminParticipantsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, tournamentId) async {
  final api  = ref.read(apiClientProvider);
  final resp = await api.get(ApiConstants.adminParticipants(tournamentId));
  return List<Map<String, dynamic>>.from(resp.data['participants'] as List);
});

// ── Admin score update ────────────────────────────────────────────────────────

class AdminScoreNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _api;
  AdminScoreNotifier(this._api) : super(const AsyncData(null));

  Future<bool> updateScore(
      String tournamentId, String entryId, List<int> holeScores) async {
    state = const AsyncLoading();
    try {
      await _api.patch(
        ApiConstants.adminUpdateScore(tournamentId, entryId),
        data: {'hole_scores': holeScores},
      );
      state = const AsyncData(null);
      return true;
    } on DioException catch (e) {
      state = AsyncError(ApiException.fromDio(e), StackTrace.current);
      return false;
    }
  }
}

final adminScoreProvider = StateNotifierProvider.autoDispose
    .family<AdminScoreNotifier, AsyncValue<void>, String>((ref, _) {
  return AdminScoreNotifier(ref.read(apiClientProvider));
});

// ── Status update ─────────────────────────────────────────────────────────────

class UpdateStatusNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _api;
  UpdateStatusNotifier(this._api) : super(const AsyncData(null));

  Future<bool> setStatus(String tournamentId, String status) async {
    state = const AsyncLoading();
    try {
      await _api.patch(ApiConstants.adminUpdateTournament(tournamentId),
          data: {'status': status});
      state = const AsyncData(null);
      return true;
    } on DioException catch (e) {
      state = AsyncError(ApiException.fromDio(e), StackTrace.current);
      return false;
    }
  }
}

final updateStatusProvider = StateNotifierProvider.autoDispose
    .family<UpdateStatusNotifier, AsyncValue<void>, String>((ref, _) {
  return UpdateStatusNotifier(ref.read(apiClientProvider));
});
