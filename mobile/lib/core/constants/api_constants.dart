class ApiConstants {
  ApiConstants._();

  // Override at build time with --dart-define=API_BASE_URL=https://api.clubhousestakes.com/api
  // Defaults to localhost for local development.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  // Auth
  static const String signup    = '/auth/signup';
  static const String login     = '/auth/login';
  static const String me        = '/auth/me';
  static const String myStats   = '/auth/stats';

  // Tournaments
  static const String tournaments    = '/tournaments';
  static const String myTournaments  = '/tournaments/mine';
  static String tournamentById(String id) => '/tournaments/$id';
  static String joinTournament(String id)  => '/tournaments/$id/join';
  static String joinSkins(String id)       => '/tournaments/$id/skins';
  static String participants(String id)    => '/tournaments/$id/participants';

  // Teams
  static const String teams       = '/teams';
  static const String myTeam      = '/teams/mine';
  static const String createTeam  = '/teams/create';
  static String joinTeam(String id) => '/teams/$id/join';

  // Scores
  static const String submitScore = '/scores/submit';
  static String myScore(String tournamentId)        => '/scores/$tournamentId/me';
  static String updateHoleScore(String tournamentId) => '/scores/$tournamentId/hole';

  // Leaderboard
  static String leaderboard(String tournamentId)      => '/leaderboard/$tournamentId';
  static String skinsLeaderboard(String tournamentId) => '/leaderboard/$tournamentId/skins';
  static const String bestRounds                      = '/leaderboard/best-rounds';

  // Users
  static const String userSearch              = '/users/search';
  static const String globalLeaderboard       = '/users/leaderboard';
  static String userProfile(String id)        => '/users/$id';
  static String userStats(String id)          => '/users/$id/stats';

  // Courses (golfcourseapi proxy)
  static const String courseSearch = '/courses/search';
  static String courseById(String id) => '/courses/$id';

  // Uploads
  static const String uploadImage = '/uploads/image';

  // Notifications
  static const String notifications        = '/notifications';
  static const String markAllNotifications = '/notifications/read-all';
  static String markNotificationRead(String id) => '/notifications/$id/read';

  // Clubhouse membership
  static String clubhouseFollow(String id)         => '/clubhouses/$id/follow';
  static String clubhouseAcceptInvite(String id)   => '/clubhouses/$id/accept-invite';
  static String clubhouseInvite(String id)         => '/clubhouses/$id/invite';

  // Clubhouses
  static const String clubhouses     = '/clubhouses';
  static const String myClubhouses   = '/clubhouses/mine';
  static String clubhouseBySlug(String slug) => '/clubhouses/$slug';
  static String clubhouseById(String id)     => '/clubhouses/$id';

  // Admin
  static const String adminTournaments = '/admin/tournaments';
  static String adminUpdateTournament(String id)    => '/admin/tournaments/$id';
  static String adminParticipants(String id)        => '/admin/tournaments/$id/participants';
  static String adminFinancials(String id)           => '/admin/tournaments/$id/financials';
  static String adminUpdateScore(String id, String entryId) => '/admin/tournaments/$id/scores/$entryId';
  static String adminUpdatePayment(String id, String entryId) => '/admin/tournaments/$id/entries/$entryId/payment';
}
