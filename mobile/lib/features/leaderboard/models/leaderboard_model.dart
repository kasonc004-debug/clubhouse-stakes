double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
int    _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

class IndividualEntry {
  final String userId;
  final String name;
  final double handicap;
  final int grossScore;
  final double? netScore;   // null until all 18 holes entered
  final int holesPlayed;    // 0–18
  final List<int> holeScores;
  final int rank;

  const IndividualEntry({
    required this.userId,
    required this.name,
    required this.handicap,
    required this.grossScore,
    this.netScore,
    required this.holesPlayed,
    required this.holeScores,
    required this.rank,
  });

  bool get isComplete => holesPlayed == 18;

  factory IndividualEntry.fromJson(Map<String, dynamic> json) {
    final rawNet = json['net_score'];
    return IndividualEntry(
      userId:      json['user_id'] as String,
      name:        json['name'] as String,
      handicap:    _d(json['handicap']),
      grossScore:  _i(json['gross_score']),
      netScore:    rawNet != null ? _d(rawNet) : null,
      holesPlayed: _i(json['holes_played']),
      holeScores:  (json['hole_scores'] as List? ?? []).map((e) => _i(e)).toList(),
      rank:        _i(json['rank']),
    );
  }
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
    handicap:   _d(json['handicap']),
    holeScores: (json['hole_scores'] as List? ?? []).map((e) => _i(e)).toList(),
  );
}

class FourballEntry {
  final String teamId;
  final String teamName;
  final List<FourballPlayer> players;
  final double netTotal;
  final int holesPlayed;
  final List<double> bestBallPerHole;
  final int rank;

  const FourballEntry({
    required this.teamId,
    required this.teamName,
    required this.players,
    required this.netTotal,
    required this.holesPlayed,
    required this.bestBallPerHole,
    required this.rank,
  });

  factory FourballEntry.fromJson(Map<String, dynamic> json) => FourballEntry(
    teamId:           json['team_id'] as String,
    teamName:         json['team_name'] as String,
    players:          (json['players'] as List)
                        .map((e) => FourballPlayer.fromJson(e as Map<String, dynamic>))
                        .toList(),
    netTotal:         _d(json['net_total']),
    holesPlayed:      _i(json['holes_played']),
    bestBallPerHole:  (json['best_ball_per_hole'] as List? ?? [])
                        .map((e) => _d(e)).toList(),
    rank:             _i(json['rank']),
  );
}
