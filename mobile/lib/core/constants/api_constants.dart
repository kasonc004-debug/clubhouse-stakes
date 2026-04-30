class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://localhost:3000/api';

  // Auth
  static const String signup    = '/auth/signup';
  static const String login     = '/auth/login';
  static const String apple     = '/auth/apple';
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
  static const String createTeam  = '/teams/create';
  static String joinTeam(String id) => '/teams/$id/join';

  // Scores
  static const String submitScore = '/scores/submit';
  static String myScore(String tournamentId) => '/scores/$tournamentId/me';

  // Leaderboard
  static String leaderboard(String tournamentId) => '/leaderboard/$tournamentId';

  // Users
  static const String userSearch              = '/users/search';
  static const String globalLeaderboard       = '/users/leaderboard';
  static String userProfile(String id)        => '/users/$id';
  static String userStats(String id)          => '/users/$id/stats';

  // Admin
  static const String adminTournaments = '/admin/tournaments';
  static String adminUpdateTournament(String id)    => '/admin/tournaments/$id';
  static String adminParticipants(String id)        => '/admin/tournaments/$id/participants';
  static String adminFinancials(String id)           => '/admin/tournaments/$id/financials';
  static String adminUpdateScore(String id, String entryId) => '/admin/tournaments/$id/scores/$entryId';
}
