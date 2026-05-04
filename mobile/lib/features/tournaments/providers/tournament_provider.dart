import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/tournament_model.dart';

// ── Upcoming tournaments (status=upcoming, optional city) ────────────────────
final tournamentsProvider = FutureProvider.family<List<TournamentModel>, String?>(
  (ref, city) async {
    final api = ref.read(apiClientProvider);
    final params = <String, dynamic>{'status': 'upcoming'};
    if (city != null) params['city'] = city;
    try {
      final resp = await api.get(ApiConstants.tournaments, queryParams: params);
      final list = resp.data['tournaments'] as List;
      return list.map((e) => TournamentModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  },
);

// ── All tournaments (admin — no status filter) ───────────────────────────────
final allTournamentsProvider = FutureProvider.autoDispose<List<TournamentModel>>(
  (ref) async {
    final api = ref.read(apiClientProvider);
    try {
      final resp = await api.get(ApiConstants.tournaments);
      final list = resp.data['tournaments'] as List;
      return list.map((e) => TournamentModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  },
);

// ── Active / live tournaments ────────────────────────────────────────────────
final activeTournamentsProvider = FutureProvider.autoDispose<List<TournamentModel>>(
  (ref) async {
    final api = ref.read(apiClientProvider);
    try {
      final resp = await api.get(ApiConstants.tournaments, queryParams: {'status': 'active'});
      final list = resp.data['tournaments'] as List;
      return list.map((e) => TournamentModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  },
);

// ── Completed tournaments ─────────────────────────────────────────────────────
final pastTournamentsProvider = FutureProvider.autoDispose<List<TournamentModel>>(
  (ref) async {
    final api = ref.read(apiClientProvider);
    try {
      final resp = await api.get(ApiConstants.tournaments, queryParams: {'status': 'completed'});
      final list = resp.data['tournaments'] as List;
      return list.map((e) => TournamentModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  },
);

// ── My enrolled tournaments (always fetches fresh) ───────────────────────────
final myTournamentsProvider = FutureProvider.autoDispose<List<TournamentModel>>(
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

// ── Participants (publicly visible roster) ───────────────────────────────────
class TournamentParticipant {
  final String id;
  final String name;
  final String? profilePictureUrl;
  final double? handicap;
  final String? city;
  final String? teamId;

  const TournamentParticipant({
    required this.id,
    required this.name,
    this.profilePictureUrl,
    this.handicap,
    this.city,
    this.teamId,
  });

  factory TournamentParticipant.fromJson(Map<String, dynamic> json) =>
      TournamentParticipant(
        id:                json['id'] as String,
        name:              json['name'] as String? ?? 'Golfer',
        profilePictureUrl: json['profile_picture_url'] as String?,
        handicap:          json['handicap'] == null
            ? null
            : double.tryParse(json['handicap'].toString()),
        city:              json['city'] as String?,
        teamId:            json['team_id'] as String?,
      );
}

final participantsProvider =
    FutureProvider.family<List<TournamentParticipant>, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  try {
    final resp = await api.get(ApiConstants.participants(id));
    final list = resp.data['participants'] as List;
    return list
        .map((e) => TournamentParticipant.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});

// ── Single tournament ────────────────────────────────────────────────────────
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

// ── Join tournament ──────────────────────────────────────────────────────────
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

// ── Enter skins ──────────────────────────────────────────────────────────────
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
