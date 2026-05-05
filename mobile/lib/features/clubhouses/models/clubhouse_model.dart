import '../../tournaments/models/tournament_model.dart';

class ClubhouseModel {
  final String id;
  final String slug;
  final String ownerId;
  final String? ownerName;
  final String name;
  final String? courseName;
  final String? city;
  final String? state;
  final String? country;
  final String? about;
  final String? logoUrl;
  final String? bannerUrl;
  final String primaryColor;
  final String accentColor;
  final bool isPublic;
  final bool isPublicCourse;
  final String? courseApiId;
  /// 'owner' | 'staff' | null. Populated by the /clubhouses/mine listing.
  final String? myRole;

  const ClubhouseModel({
    required this.id,
    required this.slug,
    required this.ownerId,
    this.ownerName,
    required this.name,
    this.courseName,
    this.city,
    this.state,
    this.country,
    this.about,
    this.logoUrl,
    this.bannerUrl,
    required this.primaryColor,
    required this.accentColor,
    required this.isPublic,
    required this.isPublicCourse,
    this.courseApiId,
    this.myRole,
  });

  String get locationLabel {
    final parts = [city, state, country].where((s) => s != null && s.isNotEmpty).toList();
    return parts.join(', ');
  }

  factory ClubhouseModel.fromJson(Map<String, dynamic> j) => ClubhouseModel(
        id:              j['id'] as String,
        slug:            j['slug'] as String,
        ownerId:         j['owner_id'] as String,
        ownerName:       j['owner_name'] as String?,
        name:            j['name'] as String,
        courseName:      j['course_name'] as String?,
        city:            j['city'] as String?,
        state:           j['state'] as String?,
        country:         j['country'] as String?,
        about:           j['about'] as String?,
        logoUrl:         j['logo_url'] as String?,
        bannerUrl:       j['banner_url'] as String?,
        primaryColor:    j['primary_color'] as String? ?? '#1B3D2C',
        accentColor:     j['accent_color']  as String? ?? '#C9A84C',
        isPublic:        j['is_public'] != false,
        isPublicCourse:  j['is_public_course'] == true,
        courseApiId:     j['course_api_id'] as String?,
        myRole:          j['my_role'] as String?,
      );
}

class ClubhousePage {
  final ClubhouseModel clubhouse;
  final List<TournamentModel> tournaments;
  /// 'member' | 'invited' | null
  final String? membershipStatus;
  /// 'owner' | 'staff' | 'member' | null
  final String? memberRole;
  /// True if the current user can edit the clubhouse + post tournaments.
  final bool canManage;
  final int memberCount;

  const ClubhousePage({
    required this.clubhouse,
    required this.tournaments,
    this.membershipStatus,
    this.memberRole,
    this.canManage = false,
    this.memberCount = 0,
  });

  bool get isMember  => membershipStatus == 'member';
  bool get isInvited => membershipStatus == 'invited';
  bool get isOwner   => memberRole == 'owner';
  bool get isStaff   => memberRole == 'staff';

  factory ClubhousePage.fromJson(Map<String, dynamic> j) => ClubhousePage(
        clubhouse:        ClubhouseModel.fromJson(j['clubhouse'] as Map<String, dynamic>),
        tournaments:      (j['tournaments'] as List? ?? [])
                            .map((e) => TournamentModel.fromJson(e as Map<String, dynamic>))
                            .toList(),
        membershipStatus: j['membership_status'] as String?,
        memberRole:       j['member_role'] as String?,
        canManage:        j['can_manage'] == true,
        memberCount:      int.tryParse(j['member_count']?.toString() ?? '0') ?? 0,
      );
}
