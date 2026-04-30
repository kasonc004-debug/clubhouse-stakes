class EntryModel {
  final String id;
  final String userId;
  final String tournamentId;
  final String? teamId;
  final List<int> holeScores;
  final int? grossScore;
  final double? netScore;
  final String paymentStatus;
  final double handicap;

  const EntryModel({
    required this.id,
    required this.userId,
    required this.tournamentId,
    this.teamId,
    required this.holeScores,
    this.grossScore,
    this.netScore,
    required this.paymentStatus,
    required this.handicap,
  });

  bool get hasScores => holeScores.isNotEmpty;
  bool get isComplete => holeScores.length == 18;

  factory EntryModel.fromJson(Map<String, dynamic> json) => EntryModel(
    id:            json['id'] as String,
    userId:        json['user_id'] as String,
    tournamentId:  json['tournament_id'] as String,
    teamId:        json['team_id'] as String?,
    holeScores:    (json['hole_scores'] as List? ?? []).map((e) => int.tryParse(e?.toString() ?? '0') ?? 0).toList(),
    grossScore:    json['gross_score'] != null ? int.tryParse(json['gross_score'].toString()) : null,
    netScore:      json['net_score'] != null ? double.tryParse(json['net_score'].toString()) : null,
    paymentStatus: json['payment_status'] as String? ?? 'pending',
    handicap:      double.tryParse(json['handicap']?.toString() ?? '0') ?? 0,
  );
}
