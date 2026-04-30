import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/entry_model.dart';

final myScoreProvider = FutureProvider.family<EntryModel?, String>(
  (ref, tournamentId) async {
    final api = ref.read(apiClientProvider);
    try {
      final resp = await api.get(ApiConstants.myScore(tournamentId));
      return EntryModel.fromJson(resp.data['entry'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDio(e);
    }
  },
);

class ScoreNotifier extends StateNotifier<AsyncValue<EntryModel?>> {
  final ApiClient _api;
  ScoreNotifier(this._api) : super(const AsyncData(null));

  Future<bool> submit({
    required String tournamentId,
    required List<int> holeScores,
  }) async {
    state = const AsyncLoading();
    try {
      final resp = await _api.post(ApiConstants.submitScore, data: {
        'tournament_id': tournamentId,
        'hole_scores':   holeScores,
      });
      final entry = EntryModel.fromJson(resp.data['entry'] as Map<String, dynamic>);
      state = AsyncData(entry);
      return true;
    } on DioException catch (e) {
      state = AsyncError(ApiException.fromDio(e), StackTrace.current);
      return false;
    }
  }
}

final scoreNotifierProvider =
    StateNotifierProvider.autoDispose<ScoreNotifier, AsyncValue<EntryModel?>>(
  (ref) => ScoreNotifier(ref.read(apiClientProvider)),
);
