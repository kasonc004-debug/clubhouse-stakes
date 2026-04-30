class ApiConstants {
  ApiConstants._();

  // Change to your server IP / domain before building
  static const String baseUrl = 'http://localhost:3000/api';

  // Auth
  static const String signup    = '/auth/signup';
  static const String login     = '/auth/login';
  static const String apple     = '/auth/apple';
  static const String me        = '/auth/me';

  // Tournaments
  static const String tournaments = '/tournaments';
  static String tournamentById(String id) => '/tournaments/$id';
  static String joinTournament(String id)  => '/tournaments/$id/join';
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

  // Admin
  static const String adminTournaments = '/admin/tournaments';
  static String adminUpdateTournament(String id) => '/admin/tournaments/$id';
}
