import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class UserStats {
  final int golds;
  final int silvers;
  final int bronzes;
  final double careerEarnings;
  final int tournamentsEntered;
  final int tournamentsPlayed;
  final int? bestScore;

  const UserStats({
    required this.golds,
    required this.silvers,
    required this.bronzes,
    required this.careerEarnings,
    required this.tournamentsEntered,
    required this.tournamentsPlayed,
    this.bestScore,
  });

  int get totalPodiums => golds + silvers + bronzes;

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
    golds:               int.tryParse(json['golds']?.toString() ?? '0') ?? 0,
    silvers:             int.tryParse(json['silvers']?.toString() ?? '0') ?? 0,
    bronzes:             int.tryParse(json['bronzes']?.toString() ?? '0') ?? 0,
    careerEarnings:      double.tryParse(json['career_earnings']?.toString() ?? '0') ?? 0,
    tournamentsEntered:  int.tryParse(json['tournaments_entered']?.toString() ?? '0') ?? 0,
    tournamentsPlayed:   int.tryParse(json['tournaments_played']?.toString() ?? '0') ?? 0,
    bestScore:           json['best_score'] != null
                           ? int.tryParse(json['best_score'].toString())
                           : null,
  );
}

final myStatsProvider = FutureProvider<UserStats>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final resp = await api.get(ApiConstants.myStats);
    return UserStats.fromJson(resp.data['stats'] as Map<String, dynamic>);
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});
