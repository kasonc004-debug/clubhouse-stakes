import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/leaderboard_model.dart';

final skinsLeaderboardProvider = FutureProvider.family<SkinsData?, String>(
  (ref, tournamentId) async {
    final api = ref.read(apiClientProvider);
    try {
      final resp = await api.get(ApiConstants.skinsLeaderboard(tournamentId));
      return SkinsData.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 404 = no skins game on this tournament
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDio(e);
    }
  },
);

class LeaderboardData {
  final String format;
  final String status;
  final List<IndividualEntry> individual;
  final List<FourballEntry> fourball;

  const LeaderboardData({
    required this.format,
    this.status     = 'upcoming',
    this.individual = const [],
    this.fourball   = const [],
  });
}

final leaderboardProvider = FutureProvider.family<LeaderboardData, String>(
  (ref, tournamentId) async {
    final api = ref.read(apiClientProvider);
    try {
      final resp   = await api.get(ApiConstants.leaderboard(tournamentId));
      final format = resp.data['format'] as String;
      final list   = resp.data['leaderboard'] as List;

      final status = resp.data['status'] as String? ?? 'upcoming';
      if (format == 'individual') {
        return LeaderboardData(
          format:     format,
          status:     status,
          individual: list.map((e) => IndividualEntry.fromJson(e as Map<String, dynamic>)).toList(),
        );
      } else {
        return LeaderboardData(
          format:   format,
          status:   status,
          fourball: list.map((e) => FourballEntry.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  },
);
