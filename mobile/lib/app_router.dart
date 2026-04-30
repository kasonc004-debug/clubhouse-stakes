import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/tournaments/screens/home_screen.dart';
import 'features/tournaments/screens/tournament_detail_screen.dart';
import 'features/teams/screens/create_team_screen.dart';
import 'features/teams/screens/join_team_screen.dart';
import 'features/scoring/screens/score_entry_screen.dart';
import 'features/leaderboard/screens/leaderboard_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/players/screens/player_search_screen.dart';
import 'features/players/screens/player_profile_screen.dart';
import 'features/admin/screens/admin_screen.dart';
import 'features/admin/screens/create_tournament_screen.dart';
import 'features/admin/screens/admin_tournament_detail_screen.dart';
import 'features/admin/screens/admin_scores_screen.dart';

// Thin ChangeNotifier that pings GoRouter when auth state changes.
// Using this instead of ref.watch avoids recreating GoRouter on every state change.
class _RouterNotifier extends ChangeNotifier {
  void update() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier();
  ref.listen<AuthState>(authProvider, (_, __) => notifier.update());

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth      = ref.read(authProvider);
      final loggedIn  = auth.isAuthenticated;
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn  && loggingIn)  return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login',  builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),

      GoRoute(path: '/home',   builder: (_, __) => const HomeScreen()),

      GoRoute(
        path: '/tournament/:id',
        builder: (_, state) => TournamentDetailScreen(
          tournamentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tournament/:id/create-team',
        builder: (_, state) => CreateTeamScreen(
          tournamentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tournament/:id/join-team',
        builder: (_, state) => JoinTeamScreen(
          tournamentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tournament/:id/score',
        builder: (_, state) => ScoreEntryScreen(
          tournamentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/leaderboard/:id',
        builder: (_, state) => LeaderboardScreen(
          tournamentId: state.pathParameters['id']!),
      ),

      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/search',  builder: (_, __) => const PlayerSearchScreen()),
      GoRoute(
        path: '/player/:id',
        builder: (_, state) => PlayerProfileScreen(
          playerId: state.pathParameters['id']!),
      ),

      GoRoute(path: '/admin',   builder: (_, __) => const AdminScreen()),
      GoRoute(path: '/admin/create-tournament', builder: (_, __) => const CreateTournamentScreen()),
      GoRoute(
        path: '/admin/tournament/:id',
        builder: (_, state) => AdminTournamentDetailScreen(
          tournamentId:   state.pathParameters['id']!,
          tournamentName: (state.extra as String?) ?? 'Tournament',
        ),
      ),
      GoRoute(
        path: '/admin/tournament/:id/scores',
        builder: (_, state) => AdminScoresScreen(
          tournamentId:   state.pathParameters['id']!,
          tournamentName: (state.extra as String?) ?? 'Scores',
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Page not found', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
