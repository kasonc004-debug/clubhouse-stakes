import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/user_model.dart';

// ── State ───────────────────────────────────────────────────
class AuthState {
  final UserModel? user;
  final bool loading;
  final String? error;

  const AuthState({this.user, this.loading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({UserModel? user, bool? loading, String? error, bool clearUser = false}) =>
      AuthState(
        user:    clearUser ? null : (user ?? this.user),
        loading: loading ?? this.loading,
        error:   error,
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
      await _persist(resp.data);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: ApiException.fromDio(e).message);
      return false;
    }
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
    }
  }

  Future<bool> signInWithApple() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final resp = await _api.post(ApiConstants.apple, data: {
        'appleId': credential.userIdentifier,
        'email':   credential.email,
        'name':    [credential.givenName, credential.familyName]
                       .where((s) => s != null && s.isNotEmpty)
                       .join(' '),
      });
      await _persist(resp.data);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: ApiException.fromDio(e).message);
      return false;
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Apple Sign-In cancelled');
      return false;
    }
  }

  Future<bool> updateProfile({String? name, double? handicap, String? city}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final data = <String, dynamic>{};
      if (name     != null) data['name']     = name;
      if (handicap != null) data['handicap'] = handicap;
      if (city     != null) data['city']     = city;

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
