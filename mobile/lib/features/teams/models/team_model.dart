class TeamMemberModel {
  final String id;
  final String name;
  final double handicap;

  const TeamMemberModel({required this.id, required this.name, required this.handicap});

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) => TeamMemberModel(
    id:       json['id'] as String,
    name:     json['name'] as String,
    handicap: (json['handicap'] as num?)?.toDouble() ?? 0,
  );
}

class TeamModel {
  final String id;
  final String tournamentId;
  final String? name;
  final int memberCount;
  final List<TeamMemberModel> members;
  final String createdAt;

  const TeamModel({
    required this.id,
    required this.tournamentId,
    this.name,
    required this.memberCount,
    required this.members,
    required this.createdAt,
  });

  bool get isFull      => memberCount >= 2;
  bool get hasOneSpot  => memberCount == 1;

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
    memberCount:  (json['member_count'] as num?)?.toInt() ?? 0,
    members:      (json['members'] as List? ?? [])
                    .map((e) => TeamMemberModel.fromJson(e as Map<String, dynamic>))
                    .toList(),
    createdAt:    json['created_at'] as String? ?? '',
  );
}
