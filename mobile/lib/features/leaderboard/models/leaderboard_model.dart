double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
int    _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

// ── Skins models ──────────────────────────────────────────────────────────────

class SkinsPlayerInfo {
  final String userId;
  final String name;
  final double handicap;

  const SkinsPlayerInfo({required this.userId, required this.name, required this.handicap});

  factory SkinsPlayerInfo.fromJson(Map<String, dynamic> j) => SkinsPlayerInfo(
    userId:   j['userId'] as String,
    name:     j['name']   as String,
    handicap: _d(j['handicap']),
  );
}

class SkinsHolePlayer {
  final String userId;
  final String name;
  final double netScore;

  const SkinsHolePlayer({required this.userId, required this.name, required this.netScore});

  factory SkinsHolePlayer.fromJson(Map<String, dynamic> j) => SkinsHolePlayer(
    userId:   j['userId'] as String,
    name:     j['name']   as String,
    netScore: _d(j['netScore']),
  );
}

// status values: 'pending' | 'leading' | 'provisional_tied' | 'tied' | 'won'
class SkinsHole {
  final int hole;
  final double pot;
  final String status;
  final SkinsHolePlayer? leader;   // present when status == 'leading'
  final SkinsHolePlayer? winner;   // present when status == 'won'
  final List<SkinsHolePlayer> tiedPlayers;
  final int carryIn;
  final int playersIn;
  final int totalPlayers;

  const SkinsHole({
    required this.hole,
    required this.pot,
    required this.status,
    this.leader,
    this.winner,
    required this.tiedPlayers,
    required this.carryIn,
    required this.playersIn,
    required this.totalPlayers,
  });

  bool get isDecided    => status == 'won' || status == 'tied';
  bool get isProvisional => status == 'leading' || status == 'provisional_tied';
  bool get isPending    => status == 'pending';

  factory SkinsHole.fromJson(Map<String, dynamic> j) {
    SkinsHolePlayer? _player(dynamic raw) =>
        raw != null ? SkinsHolePlayer.fromJson(raw as Map<String, dynamic>) : null;

    return SkinsHole(
      hole:        _i(j['hole']),
      pot:         _d(j['pot']),
      status:      j['status'] as String? ?? 'pending',
      leader:      _player(j['leader']),
      winner:      _player(j['winner']),
      tiedPlayers: (j['tiedPlayers'] as List? ?? [])
                     .map((e) => SkinsHolePlayer.fromJson(e as Map<String, dynamic>))
                     .toList(),
      carryIn:     _i(j['carryIn']),
      playersIn:   _i(j['playersIn']),
      totalPlayers: _i(j['totalPlayers']),
    );
  }
}

class SkinsWinner {
  final String userId;
  final String name;
  final List<int> holesWon;
  final double amount;

  const SkinsWinner({required this.userId, required this.name, required this.holesWon, required this.amount});

  factory SkinsWinner.fromJson(Map<String, dynamic> j) => SkinsWinner(
    userId:   j['userId'] as String,
    name:     j['name']   as String,
    holesWon: (j['holesWon'] as List? ?? []).map((e) => _i(e)).toList(),
    amount:   _d(j['amount']),
  );
}

class SkinsSummary {
  final double totalPot;
  final double holeValue;
  final List<SkinsWinner> skinsWon;
  final bool isComplete;
  final int carryoverHoles;
  final double totalAwarded;

  const SkinsSummary({
    required this.totalPot,
    required this.holeValue,
    required this.skinsWon,
    required this.isComplete,
    required this.carryoverHoles,
    required this.totalAwarded,
  });

  factory SkinsSummary.fromJson(Map<String, dynamic> j) => SkinsSummary(
    totalPot:       _d(j['totalPot']),
    holeValue:      _d(j['holeValue']),
    skinsWon:       (j['skinsWon'] as List? ?? [])
                      .map((e) => SkinsWinner.fromJson(e as Map<String, dynamic>))
                      .toList(),
    isComplete:     j['isComplete'] == true,
    carryoverHoles: _i(j['carryoverHoles']),
    totalAwarded:   _d(j['totalAwarded']),
  );
}

class SkinsData {
  final String status;
  final double skinsFee;
  final double skinsPot;
  final List<SkinsPlayerInfo> players;
  final List<SkinsHole> holes;
  final SkinsSummary? summary;

  const SkinsData({
    required this.status,
    required this.skinsFee,
    required this.skinsPot,
    required this.players,
    required this.holes,
    this.summary,
  });

  factory SkinsData.fromJson(Map<String, dynamic> j) => SkinsData(
    status:   j['status']   as String? ?? 'upcoming',
    skinsFee: _d(j['skinsFee']),
    skinsPot: _d(j['skinsPot']),
    players:  (j['players'] as List? ?? [])
                .map((e) => SkinsPlayerInfo.fromJson(e as Map<String, dynamic>))
                .toList(),
    holes:    (j['holes'] as List? ?? [])
                .map((e) => SkinsHole.fromJson(e as Map<String, dynamic>))
                .toList(),
    summary:  j['summary'] != null ? SkinsSummary.fromJson(j['summary'] as Map<String, dynamic>) : null,
  );
}

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
