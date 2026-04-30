import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/tournament_model.dart';

// ── List provider (filterable by city) ──────────────────────
final tournamentsProvider = FutureProvider.family<List<TournamentModel>, String?>(
  (ref, city) async {
    final api = ref.read(apiClientProvider);
    final params = city != null ? {'city': city} : null;
    try {
      final resp = await api.get(ApiConstants.tournaments, queryParams: params);
      final list = resp.data['tournaments'] as List;
      return list.map((e) => TournamentModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  },
);

// ── Single tournament ────────────────────────────────────────
final tournamentDetailProvider = FutureProvider.family<TournamentModel, String>(
  (ref, id) async {
    final api = ref.read(apiClientProvider);
    try {
      final resp = await api.get(ApiConstants.tournamentById(id));
      return TournamentModel.fromJson(resp.data['tournament'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  },
);

// ── My enrolled tournaments ──────────────────────────────────
final myTournamentsProvider = FutureProvider<List<TournamentModel>>(
  (ref) async {
    final api = ref.read(apiClientProvider);
    try {
      final resp = await api.get(ApiConstants.myTournaments);
      final list = resp.data['tournaments'] as List;
      return list.map((e) => TournamentModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  },
);

// ── Join action state ────────────────────────────────────────
class JoinTournamentNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _api;
  JoinTournamentNotifier(this._api) : super(const AsyncData(null));

  Future<bool> join(String tournamentId) async {
    state = const AsyncLoading();
    try {
      await _api.post(ApiConstants.joinTournament(tournamentId));
      state = const AsyncData(null);
      return true;
    } on DioException catch (e) {
      state = AsyncError(ApiException.fromDio(e), StackTrace.current);
      return false;
    }
  }
}

final joinTournamentProvider =
    StateNotifierProvider.autoDispose<JoinTournamentNotifier, AsyncValue<void>>(
  (ref) => JoinTournamentNotifier(ref.read(apiClientProvider)),
);

// ── Enter skins action ───────────────────────────────────────
class EnterSkinsNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _api;
  EnterSkinsNotifier(this._api) : super(const AsyncData(null));

  Future<bool> enter(String tournamentId) async {
    state = const AsyncLoading();
    try {
      await _api.post(ApiConstants.joinSkins(tournamentId));
      state = const AsyncData(null);
      return true;
    } on DioException catch (e) {
      state = AsyncError(ApiException.fromDio(e), StackTrace.current);
      return false;
    }
  }
}

final enterSkinsProvider =
    StateNotifierProvider.autoDispose<EnterSkinsNotifier, AsyncValue<void>>(
  (ref) => EnterSkinsNotifier(ref.read(apiClientProvider)),
);
