import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/user_model.dart';

// ── State ───────────────────────────────────────────────────
class AuthState {
  final UserModel? user;
  final bool loading;
  final String? error;
  /// Clubhouse slugs that were auto-attached during the most recent signup,
  /// so the UI can surface a "you've joined X" toast. Cleared after read.
  final List<String> attachedClubhouses;

  const AuthState({
    this.user,
    this.loading = false,
    this.error,
    this.attachedClubhouses = const [],
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? loading,
    String? error,
    List<String>? attachedClubhouses,
    bool clearUser = false,
  }) =>
      AuthState(
        user:               clearUser ? null : (user ?? this.user),
        loading:            loading ?? this.loading,
        error:              error,
        attachedClubhouses: attachedClubhouses ?? this.attachedClubhouses,
      );
}

// ── Notifier ────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  final SecureStorage _storage;

  AuthNotifier(this._api, this._storage) : super(const AuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token    = await _storage.getToken();
    final userJson = await _storage.getUser();
    if (token != null && userJson != null) {
      try {
        final user = UserModel.fromJsonString(userJson);
        state = AuthState(user: user);
        // Refresh from server
        final resp = await _api.get(ApiConstants.me);
        final fresh = UserModel.fromJson(resp.data['user'] as Map<String, dynamic>);
        await _storage.saveUser(fresh.toJsonString());
        state = AuthState(user: fresh);
      } catch (_) {
        await _storage.clearAll();
        state = const AuthState();
      }
    }
  }

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
    double handicap = 0,
    String? city,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final resp = await _api.post(ApiConstants.signup, data: {
        'name': name, 'email': email, 'password': password,
        'handicap': handicap, 'city': city,
      });
      // The backend tags new users with any clubhouses they were
      // auto-added to via pending email invites.
      final attached = <String>[];
      final raw = resp.data['user']?['attached_clubhouses'];
      if (raw is List) {
        for (final v in raw) {
          if (v is String && v.isNotEmpty) attached.add(v);
        }
      }
      await _persist(resp.data);
      if (attached.isNotEmpty) {
        state = state.copyWith(attachedClubhouses: attached);
      }
      return true;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: ApiException.fromDio(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Signup failed. Please try again.');
      return false;
    }
  }

  /// One-shot consumer: returns the slugs and clears the list.
  List<String> consumeAttachedClubhouses() {
    final list = state.attachedClubhouses;
    if (list.isEmpty) return const [];
    state = state.copyWith(attachedClubhouses: const []);
    return list;
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final resp = await _api.post(ApiConstants.login, data: {
        'email': email, 'password': password,
      });
      await _persist(resp.data);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: ApiException.fromDio(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Login failed. Please try again.');
      return false;
    }
  }

  Future<bool> updateProfile({
    String? name,
    double? handicap,
    String? city,
    String? profilePictureUrl,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final data = <String, dynamic>{};
      if (name              != null) data['name']                 = name;
      if (handicap          != null) data['handicap']             = handicap;
      if (city              != null) data['city']                 = city;
      if (profilePictureUrl != null) data['profile_picture_url']  = profilePictureUrl;

      final resp  = await _api.patch(ApiConstants.me, data: data);
      final fresh = UserModel.fromJson(resp.data['user'] as Map<String, dynamic>);
      await _storage.saveUser(fresh.toJsonString());
      state = AuthState(user: fresh);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: ApiException.fromDio(e).message);
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
    state = const AuthState();
  }

  Future<void> _persist(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final user  = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveToken(token);
    await _storage.saveUser(user.toJsonString());
    state = AuthState(user: user);
  }
}

// ── Providers ───────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(apiClientProvider),
    ref.read(secureStorageProvider),
  );
});
