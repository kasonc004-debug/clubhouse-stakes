import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

class SecureStorage {
  static const _tokenKey = 'cs_jwt_token';
  static const _userKey  = 'cs_user_json';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void>    saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<String?> getToken()              => _storage.read(key: _tokenKey);
  Future<void>    deleteToken()           => _storage.delete(key: _tokenKey);

  Future<void>    saveUser(String json)   => _storage.write(key: _userKey, value: json);
  Future<String?> getUser()              => _storage.read(key: _userKey);
  Future<void>    deleteUser()           => _storage.delete(key: _userKey);

  Future<void> clearAll() => _storage.deleteAll();
}
