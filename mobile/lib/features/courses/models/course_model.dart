int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
double? _dn(dynamic v) =>
    v == null ? null : double.tryParse(v.toString());

class CourseSummary {
  final int id;
  final String clubName;
  final String? courseName;
  final String? location;

  const CourseSummary({
    required this.id,
    required this.clubName,
    this.courseName,
    this.location,
  });

  String get displayName {
    final c = courseName?.trim();
    if (c == null || c.isEmpty || c == clubName) return clubName;
    return '$clubName · $c';
  }

  factory CourseSummary.fromJson(Map<String, dynamic> j) => CourseSummary(
        id:         _i(j['id']),
        clubName:   (j['club_name'] ?? 'Course') as String,
        courseName: j['course_name'] as String?,
        location:   j['location'] as String?,
      );
}

class CourseHole {
  final int number;
  final int par;
  final int yardage;
  final int handicap;

  const CourseHole({
    required this.number,
    required this.par,
    required this.yardage,
    required this.handicap,
  });

  factory CourseHole.fromJson(Map<String, dynamic> j) => CourseHole(
        number:   _i(j['number']),
        par:      _i(j['par']),
        yardage:  _i(j['yardage']),
        handicap: _i(j['handicap']),
      );
}

class CourseTee {
  final String id;
  final String gender;
  final String teeName;
  final double? courseRating;
  final double? slopeRating;
  final int totalYards;
  final int parTotal;
  final List<CourseHole> holes;

  const CourseTee({
    required this.id,
    required this.gender,
    required this.teeName,
    this.courseRating,
    this.slopeRating,
    required this.totalYards,
    required this.parTotal,
    required this.holes,
  });

  String get displayName {
    final g = gender == 'female' ? '♀' : '♂';
    return '$teeName  $g';
  }

  factory CourseTee.fromJson(Map<String, dynamic> j) => CourseTee(
        id:           j['id'] as String,
        gender:       (j['gender'] ?? 'male') as String,
        teeName:      (j['tee_name'] ?? 'Tee') as String,
        courseRating: _dn(j['course_rating']),
        slopeRating:  _dn(j['slope_rating']),
        totalYards:   _i(j['total_yards']),
        parTotal:     _i(j['par_total']),
        holes:        (j['holes'] as List? ?? [])
                         .map((e) => CourseHole.fromJson(e as Map<String, dynamic>))
                         .toList(),
      );
}

class CourseDetail {
  final int id;
  final String clubName;
  final String? courseName;
  final String? location;
  final List<CourseTee> tees;

  const CourseDetail({
    required this.id,
    required this.clubName,
    this.courseName,
    this.location,
    required this.tees,
  });

  String get displayName {
    final c = courseName?.trim();
    if (c == null || c.isEmpty || c == clubName) return clubName;
    return '$clubName — $c';
  }

  factory CourseDetail.fromJson(Map<String, dynamic> j) => CourseDetail(
        id:         _i(j['id']),
        clubName:   (j['club_name'] ?? 'Course') as String,
        courseName: j['course_name'] as String?,
        location:   j['location'] as String?,
        tees:       (j['tees'] as List? ?? [])
                       .map((e) => CourseTee.fromJson(e as Map<String, dynamic>))
                       .toList(),
      );
}
