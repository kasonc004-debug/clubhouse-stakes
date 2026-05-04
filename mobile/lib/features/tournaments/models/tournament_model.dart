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
  final String? rules;
  final bool handicapEnabled;
  final List<int>? pars;
  final List<int>? yardages;
  final String? teeName;
  final String? clubhouseId;
  final String? clubhouseSlug;
  final String? clubhouseName;
  final int playerCount;
  final double purse;
  final double skinsFee;
  final int skinsCount;
  final double skinsPot;
  final bool mySkinsEntry;
  final String? myEntryId;
  /// 'pending' | 'paid' | 'refunded' | null (not enrolled)
  final String? myPaymentStatus;
  /// Same enum as above, only meaningful when mySkinsEntry == true.
  final String? mySkinsPaymentStatus;

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
    this.rules,
    this.handicapEnabled = true,
    this.pars,
    this.yardages,
    this.teeName,
    this.clubhouseId,
    this.clubhouseSlug,
    this.clubhouseName,
    this.playerCount = 0,
    this.purse = 0,
    this.skinsFee = 0,
    this.skinsCount = 0,
    this.skinsPot = 0,
    this.mySkinsEntry = false,
    this.myEntryId,
    this.myPaymentStatus,
    this.mySkinsPaymentStatus,
  });

  bool get isFourball   => format == 'fourball';
  bool get isScramble   => format == 'scramble';
  bool get isTeamFormat => isFourball || isScramble;
  bool get isUpcoming   => status == 'upcoming';
  bool get isFull       => playerCount >= maxPlayers;
  int  get spotsLeft    => maxPlayers - playerCount;
  bool get hasSkinsGame => skinsFee > 0;
  bool get isEnrolled   => myEntryId != null;

  bool get entryFeeOutstanding =>
      isEnrolled && (myPaymentStatus ?? 'pending') == 'pending';
  bool get skinsFeeOutstanding =>
      mySkinsEntry && (mySkinsPaymentStatus ?? 'pending') == 'pending';

  /// Total cash this user owes at the course right now.
  double get amountOwed {
    var owed = 0.0;
    if (entryFeeOutstanding) owed += signUpFee;
    if (skinsFeeOutstanding) owed += skinsFee;
    return owed;
  }

  String get formatLabel {
    switch (format) {
      case 'fourball': return 'Four-Ball (Best Ball)';
      case 'scramble': return 'Scramble';
      default:         return 'Individual Stroke Play';
    }
  }

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
    rules:        json['rules'] as String?,
    handicapEnabled: json['handicap_enabled'] != false,
    pars:         (json['pars'] as List?)
                    ?.map((e) => int.tryParse(e.toString()) ?? 0)
                    .toList(),
    yardages:     (json['yardages'] as List?)
                    ?.map((e) => int.tryParse(e.toString()) ?? 0)
                    .toList(),
    teeName:       json['tee_name'] as String?,
    clubhouseId:   json['clubhouse_id'] as String?,
    clubhouseSlug: json['clubhouse_slug'] as String?,
    clubhouseName: json['clubhouse_name'] as String?,
    playerCount:   int.tryParse(json['player_count']?.toString() ?? '0') ?? 0,
    purse:        double.tryParse(json['purse']?.toString() ?? '0') ?? 0,
    skinsFee:     double.tryParse(json['skins_fee']?.toString() ?? '0') ?? 0,
    skinsCount:   int.tryParse(json['skins_count']?.toString() ?? '0') ?? 0,
    skinsPot:     double.tryParse(json['skins_pot']?.toString() ?? '0') ?? 0,
    mySkinsEntry:         json['my_skins_entry'] == true,
    myEntryId:            json['my_entry_id'] as String?,
    myPaymentStatus:      json['my_payment_status'] as String?,
    mySkinsPaymentStatus: json['my_skins_payment_status'] as String?,
  );
}
