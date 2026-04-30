class TournamentModel {
  final String id;
  final String name;
  final String city;
  final DateTime date;
  final String format;
  final double signUpFee;
  final int maxPlayers;
  final String feePer;
  final String status;
  final String? courseName;
  final String? description;
  final int playerCount;
  final double purse;
  final double skinsFee;
  final int skinsCount;
  final double skinsPot;
  final bool mySkinsEntry;
  final String? myEntryId;

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
    this.skinsFee = 0,
    this.skinsCount = 0,
    this.skinsPot = 0,
    this.mySkinsEntry = false,
    this.myEntryId,
  });

  bool get isFourball   => format == 'fourball';
  bool get isUpcoming   => status == 'upcoming';
  bool get isFull       => playerCount >= maxPlayers;
  int  get spotsLeft    => maxPlayers - playerCount;
  bool get hasSkinsGame => skinsFee > 0;
  bool get isEnrolled   => myEntryId != null;

  factory TournamentModel.fromJson(Map<String, dynamic> json) => TournamentModel(
    id:           json['id'] as String,
    name:         json['name'] as String,
    city:         json['city'] as String,
    date:         DateTime.parse(json['date'] as String),
    format:       json['format'] as String,
    signUpFee:    double.tryParse(json['sign_up_fee']?.toString() ?? '0') ?? 0,
    maxPlayers:   int.tryParse(json['max_players']?.toString() ?? '0') ?? 0,
    feePer:       json['fee_per'] as String? ?? 'player',
    status:       json['status'] as String? ?? 'upcoming',
    courseName:   json['course_name'] as String?,
    description:  json['description'] as String?,
    playerCount:  int.tryParse(json['player_count']?.toString() ?? '0') ?? 0,
    purse:        double.tryParse(json['purse']?.toString() ?? '0') ?? 0,
    skinsFee:     double.tryParse(json['skins_fee']?.toString() ?? '0') ?? 0,
    skinsCount:   int.tryParse(json['skins_count']?.toString() ?? '0') ?? 0,
    skinsPot:     double.tryParse(json['skins_pot']?.toString() ?? '0') ?? 0,
    mySkinsEntry: json['my_skins_entry'] == true,
    myEntryId:   json['my_entry_id'] as String?,
  );
}
