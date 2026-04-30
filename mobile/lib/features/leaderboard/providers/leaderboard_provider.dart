import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/leaderboard_model.dart';

class LeaderboardData {
  final String format;
  final List<IndividualEntry> individual;
  final List<FourballEntry> fourball;

  const LeaderboardData({
    required this.format,
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

      if (format == 'individual') {
        return LeaderboardData(
          format:     format,
          individual: list.map((e) => IndividualEntry.fromJson(e as Map<String, dynamic>)).toList(),
        );
      } else {
        return LeaderboardData(
          format:   format,
          fourball: list.map((e) => FourballEntry.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  },
);
