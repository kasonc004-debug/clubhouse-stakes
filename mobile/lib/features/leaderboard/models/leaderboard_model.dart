class IndividualEntry {
  final String userId;
  final String name;
  final double handicap;
  final int grossScore;
  final double netScore;
  final List<int> holeScores;
  final int rank;

  const IndividualEntry({
    required this.userId,
    required this.name,
    required this.handicap,
    required this.grossScore,
    required this.netScore,
    required this.holeScores,
    required this.rank,
  });

  factory IndividualEntry.fromJson(Map<String, dynamic> json) => IndividualEntry(
    userId:     json['user_id'] as String,
    name:       json['name'] as String,
    handicap:   (json['handicap'] as num).toDouble(),
    grossScore: (json['gross_score'] as num).toInt(),
    netScore:   (json['net_score'] as num).toDouble(),
    holeScores: (json['hole_scores'] as List? ?? []).map((e) => (e as num).toInt()).toList(),
    rank:       (json['rank'] as num).toInt(),
  );
}

class FourballPlayer {
  final String userId;
  final String name;
  final double handicap;
  final List<int> holeScores;

  const FourballPlayer({
    required this.userId,
    required this.name,
    required this.handicap,
    required this.holeScores,
  });

  factory FourballPlayer.fromJson(Map<String, dynamic> json) => FourballPlayer(
    userId:     json['user_id'] as String,
    name:       json['name'] as String,
    handicap:   (json['handicap'] as num).toDouble(),
    holeScores: (json['hole_scores'] as List? ?? []).map((e) => (e as num).toInt()).toList(),
  );
}

class FourballEntry {
  final String teamId;
  final String teamName;
  final List<FourballPlayer> players;
  final double netTotal;
  final List<double> bestBallPerHole;
  final int rank;

  const FourballEntry({
    required this.teamId,
    required this.teamName,
    required this.players,
    required this.netTotal,
    required this.bestBallPerHole,
    required this.rank,
  });

  factory FourballEntry.fromJson(Map<String, dynamic> json) => FourballEntry(
    teamId:           json['team_id'] as String,
    teamName:         json['team_name'] as String,
    players:          (json['players'] as List)
                        .map((e) => FourballPlayer.fromJson(e as Map<String, dynamic>))
                        .toList(),
    netTotal:         (json['net_total'] as num).toDouble(),
    bestBallPerHole:  (json['best_ball_per_hole'] as List? ?? [])
                        .map((e) => (e as num).toDouble()).toList(),
    rank:             (json['rank'] as num).toInt(),
  );
}
