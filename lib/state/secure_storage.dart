import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }
  
  Future<Map<String, String>?> readAll() async {
    return await _storage.readAll();
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  Future<void> saveAccessToken(String token) async {
    await write('accessToken', token);
  }

  Future<String?> getAccessToken() async {
    return await read('accessToken');
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: 'accessToken');
  }

  Future<void> saveRefreshToken(String token) async {
    await write('refreshToken', token);
  }

  Future<String?> getRefreshToken() async {
    return await read('refreshToken');
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: 'refreshToken');
  }

  Future<void> saveProvider(String provider) async {
    await write('provider', provider);
  }

  Future<String?> getProvider() async {
    return await read('provider');
  }

  Future<void> deleteProvider() async {
    await _storage.delete(key: 'provider');
  }

  Future<void> saveEmail(String email) async {
    await write('email', email);
  }

  Future<String?> getEmail() async {
    return await read('email');
  }

  Future<void> deleteEmail() async {
    await _storage.delete(key: 'email');
  }
}