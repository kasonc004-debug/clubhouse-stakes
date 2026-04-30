class TournamentModel {
  final String id;
  final String name;
  final String city;
  final DateTime date;
  final String format; // 'individual' | 'fourball'
  final double signUpFee;
  final int maxPlayers;
  final String feePer; // 'player' | 'team'
  final String status; // 'upcoming' | 'active' | 'completed'
  final String? courseName;
  final String? description;
  final int playerCount;
  final double purse;

  const TournamentModel({
    required this.id,
    required this.name,
    required this.city,
    required this.date,
    required this.format,
    required this.signUpFee,
    required this.maxPlayers,
    this.feePer = 'player',
    this.status = 'upcoming',
    this.courseName,
    this.description,
    this.playerCount = 0,
    this.purse = 0,
  });

  bool get isFourball   => format == 'fourball';
  bool get isUpcoming   => status == 'upcoming';
  bool get isFull       => playerCount >= maxPlayers;
  int  get spotsLeft    => maxPlayers - playerCount;

  factory TournamentModel.fromJson(Map<String, dynamic> json) => TournamentModel(
    id:          json['id'] as String,
    name:        json['name'] as String,
    city:        json['city'] as String,
    date:        DateTime.parse(json['date'] as String),
    format:      json['format'] as String,
    signUpFee:   (json['sign_up_fee'] as num).toDouble(),
    maxPlayers:  (json['max_players'] as num).toInt(),
    feePer:      json['fee_per'] as String? ?? 'player',
    status:      json['status'] as String? ?? 'upcoming',
    courseName:  json['course_name'] as String?,
    description: json['description'] as String?,
    playerCount: (json['player_count'] as num?)?.toInt() ?? 0,
    purse:       (json['purse'] as num?)?.toDouble() ?? 0,
  );
}
