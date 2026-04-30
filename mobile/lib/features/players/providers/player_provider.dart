import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/stats_provider.dart';

class PlayerProfile {
  final String id;
  final String name;
  final double handicap;
  final String? city;
  final String createdAt;

  const PlayerProfile({
    required this.id,
    required this.name,
    required this.handicap,
    this.city,
    required this.createdAt,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
    id:        json['id'] as String,
    name:      json['name'] as String,
    handicap:  double.tryParse(json['handicap']?.toString() ?? '0') ?? 0,
    city:      json['city'] as String?,
    createdAt: json['created_at'] as String? ?? '',
  );
}

// Search results
final playerSearchProvider =
    FutureProvider.family<List<PlayerProfile>, String>((ref, query) async {
  if (query.trim().length < 2) return [];
  final api = ref.read(apiClientProvider);
  try {
    final resp = await api.get(
      ApiConstants.userSearch,
      queryParams: {'q': query.trim()},
    );
    final list = resp.data['users'] as List;
    return list
        .map((e) => PlayerProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});

// Single player profile
final playerProfileProvider =
    FutureProvider.family<PlayerProfile, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  try {
    final resp = await api.get(ApiConstants.userProfile(id));
    return PlayerProfile.fromJson(
        resp.data['user'] as Map<String, dynamic>);
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});

// Global leaderboard entry
class LeaderboardEntry {
  final String id;
  final String name;
  final double handicap;
  final String? city;
  final double careerEarnings;
  final double avgNetScore;
  final int roundsPlayed;
  final int golds;

  const LeaderboardEntry({
    required this.id,
    required this.name,
    required this.handicap,
    this.city,
    required this.careerEarnings,
    required this.avgNetScore,
    required this.roundsPlayed,
    required this.golds,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        id:             json['id'] as String,
        name:           json['name'] as String,
        handicap:       double.tryParse(json['handicap']?.toString() ?? '0') ?? 0,
        city:           json['city'] as String?,
        careerEarnings: double.tryParse(json['career_earnings']?.toString() ?? '0') ?? 0,
        avgNetScore:    double.tryParse(json['avg_net_score']?.toString() ?? '0') ?? 0,
        roundsPlayed:   int.tryParse(json['rounds_played']?.toString() ?? '0') ?? 0,
        golds:          int.tryParse(json['golds']?.toString() ?? '0') ?? 0,
      );
}

final globalLeaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, String?>((ref, city) async {
  final api = ref.read(apiClientProvider);
  try {
    final params = city != null && city.isNotEmpty ? {'city': city} : null;
    final resp = await api.get(ApiConstants.globalLeaderboard, queryParams: params);
    final list = resp.data['leaderboard'] as List;
    return list
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});

// Another player's stats (reuses UserStats model from stats_provider)
final playerStatsProvider =
    FutureProvider.family<UserStats, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  try {
    final resp = await api.get(ApiConstants.userStats(id));
    return UserStats.fromJson(resp.data['stats'] as Map<String, dynamic>);
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});
