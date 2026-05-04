import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/team_model.dart';

// ── My team for a tournament (fourball) ─────────────────────
final myTeamProvider = FutureProvider.family<TeamModel?, String>(
  (ref, tournamentId) async {
    final api = ref.read(apiClientProvider);
    try {
      final resp = await api.get(ApiConstants.myTeam,
          queryParams: {'tournament_id': tournamentId});
      return TeamModel.fromJson(resp.data['team'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDio(e);
    }
  },
);

// ── List of teams for a tournament ──────────────────────────
final teamsProvider = FutureProvider.family<List<TeamModel>, ({String tournamentId, bool openOnly})>(
  (ref, args) async {
    final api = ref.read(apiClientProvider);
    try {
      final resp = await api.get(ApiConstants.teams, queryParams: {
        'tournament_id': args.tournamentId,
        if (args.openOnly) 'open': 'true',
      });
      final list = resp.data['teams'] as List;
      return list.map((e) => TeamModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  },
);

// ── Create team ──────────────────────────────────────────────
class CreateTeamNotifier extends StateNotifier<AsyncValue<TeamModel?>> {
  final ApiClient _api;
  CreateTeamNotifier(this._api) : super(const AsyncData(null));

  Future<TeamModel?> create({
    required String tournamentId,
    String? name,
    String? partnerId,
  }) async {
    state = const AsyncLoading();
    try {
      final resp = await _api.post(ApiConstants.createTeam, data: {
        'tournament_id': tournamentId,
        if (name != null && name.isNotEmpty) 'name': name,
        if (partnerId != null) 'partner_id': partnerId,
      });
      final team = TeamModel.fromJson(resp.data['team'] as Map<String, dynamic>);
      state = AsyncData(team);
      return team;
    } on DioException catch (e) {
      state = AsyncError(ApiException.fromDio(e), StackTrace.current);
      return null;
    }
  }
}

final createTeamProvider =
    StateNotifierProvider.autoDispose<CreateTeamNotifier, AsyncValue<TeamModel?>>(
  (ref) => CreateTeamNotifier(ref.read(apiClientProvider)),
);

// ── Join team ────────────────────────────────────────────────
class JoinTeamNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiClient _api;
  JoinTeamNotifier(this._api) : super(const AsyncData(null));

  Future<bool> join(String teamId) async {
    state = const AsyncLoading();
    try {
      await _api.post(ApiConstants.joinTeam(teamId));
      state = const AsyncData(null);
      return true;
    } on DioException catch (e) {
      state = AsyncError(ApiException.fromDio(e), StackTrace.current);
      return false;
    }
  }
}

final joinTeamProvider =
    StateNotifierProvider.autoDispose<JoinTeamNotifier, AsyncValue<void>>(
  (ref) => JoinTeamNotifier(ref.read(apiClientProvider)),
);
