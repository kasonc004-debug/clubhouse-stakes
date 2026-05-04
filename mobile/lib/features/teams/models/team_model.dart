class TeamMemberModel {
  final String id;
  final String name;
  final double handicap;
  final String? profilePictureUrl;
  final List<int> holeScores;

  const TeamMemberModel({
    required this.id,
    required this.name,
    required this.handicap,
    this.profilePictureUrl,
    this.holeScores = const [],
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) => TeamMemberModel(
    id:       json['id'] as String,
    name:     json['name'] as String,
    handicap: double.tryParse(json['handicap']?.toString() ?? '0') ?? 0,
    profilePictureUrl: json['profile_picture_url'] as String?,
    holeScores: (json['hole_scores'] as List? ?? [])
                  .map((e) => int.tryParse(e?.toString() ?? '0') ?? 0)
                  .toList(),
  );
}

class TeamModel {
  final String id;
  final String tournamentId;
  final String? name;
  final int memberCount;
  final List<TeamMemberModel> members;
  final String createdAt;
  final String? scorerId;

  const TeamModel({
    required this.id,
    required this.tournamentId,
    this.name,
    required this.memberCount,
    required this.members,
    required this.createdAt,
    this.scorerId,
  });

  bool get isFull      => memberCount >= 2;
  bool get hasOneSpot  => memberCount == 1;

  bool isScorer(String userId) => scorerId != null && scorerId == userId;

  TeamMemberModel? get scorer =>
      scorerId == null ? null : members.where((m) => m.id == scorerId).firstOrNull;

  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    if (members.length >= 2) return '${members[0].name} / ${members[1].name}';
    if (members.length == 1) return '${members[0].name} + ?';
    return 'Team';
  }

  factory TeamModel.fromJson(Map<String, dynamic> json) => TeamModel(
    id:           json['id'] as String,
    tournamentId: json['tournament_id'] as String? ?? '',
    name:         json['name'] as String?,
    memberCount:  int.tryParse(json['member_count']?.toString() ?? '0') ?? 0,
    members:      (json['members'] as List? ?? [])
                    .map((e) => TeamMemberModel.fromJson(e as Map<String, dynamic>))
                    .toList(),
    createdAt:    json['created_at'] as String? ?? '',
    scorerId:     json['scorer_id'] as String?,
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
