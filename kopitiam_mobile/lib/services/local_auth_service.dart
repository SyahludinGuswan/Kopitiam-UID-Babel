import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kredensial offline hanya berlaku 24 jam sejak login online terakhir dan
/// hanya untuk akun yang sama. Akun berbeda wajib diverifikasi online.
class LocalAuthService {
  static const _storage = FlutterSecureStorage();
  static const _usernameKey = 'local_auth_username';
  static const _hashKey = 'local_auth_password_hash';
  static const _saltKey = 'local_auth_password_salt';
  static const _sessionKey = 'local_auth_session_json';
  static const _verifiedAtKey = 'local_auth_verified_at';
  static const offlineValidity = Duration(days: 1);

  static String normalizeUsername(Object? value) =>
      '${value ?? ''}'.trim().toLowerCase();

  static bool sameOfflineAccount(String requested, String saved) =>
      normalizeUsername(requested).isNotEmpty &&
      normalizeUsername(requested) == normalizeUsername(saved);

  static Future<String> offlineOwner() async =>
      normalizeUsername(await _storage.read(key: _usernameKey));

  static Future<void> saveAfterOnlineLogin({
    required String username,
    required String password,
    required Map<String, dynamic> profile,
  }) async {
    final requested = normalizeUsername(username);
    final verified = normalizeUsername(profile['username']);
    if (requested.isEmpty || verified.isEmpty || requested != verified) {
      throw StateError('Identitas akun hasil verifikasi server tidak cocok.');
    }
    final salt = _randomSalt();
    final hash = _hash(password, salt);
    final verifiedAt = DateTime.now().toUtc();
    await _storage.write(key: _usernameKey, value: verified);
    await _storage.write(key: _hashKey, value: hash);
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _sessionKey, value: jsonEncode(profile));
    await _storage.write(
      key: _verifiedAtKey,
      value: verifiedAt.toIso8601String(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offlineLogin');
    await prefs.remove('offlineExpiresAt');
  }

  static Future<Map<String, dynamic>?> verifyOffline({
    required String username,
    required String password,
  }) async {
    final savedUsername = await _storage.read(key: _usernameKey);
    if (savedUsername == null ||
        !sameOfflineAccount(username, savedUsername)) {
      return null;
    }
    final savedHash = await _storage.read(key: _hashKey);
    final salt = await _storage.read(key: _saltKey);
    final sessionRaw = await _storage.read(key: _sessionKey);
    final verifiedAtRaw = await _storage.read(key: _verifiedAtKey);
    final verifiedAt = DateTime.tryParse(verifiedAtRaw ?? '')?.toUtc();
    final now = DateTime.now().toUtc();

    if (savedHash == null ||
        salt == null ||
        sessionRaw == null ||
        verifiedAt == null ||
        now.difference(verifiedAt) >= offlineValidity ||
        now.isBefore(verifiedAt)) {
      await clear();
      return null;
    }
    if (_hash(password, salt) != savedHash) return null;
    try {
      final decoded = jsonDecode(sessionRaw);
      if (decoded is Map &&
          sameOfflineAccount(username, '${decoded['username'] ?? ''}')) {
        final expiresAt = verifiedAt.add(offlineValidity).toIso8601String();
        final session = Map<String, dynamic>.from(decoded)
          ..['roleVerifiedOnline'] = false
          ..['offlineLogin'] = true
          ..['offlineExpiresAt'] = expiresAt;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('offlineLogin', true);
        await prefs.setString('offlineExpiresAt', expiresAt);
        return session;
      }
    } catch (_) {}
    return null;
  }

  static bool offlineSessionExpired(Map<String, dynamic> session) {
    if (session['offlineLogin'] != true) return false;
    final expiresAt = DateTime.tryParse(
      (session['offlineExpiresAt'] ?? '').toString(),
    )?.toUtc();
    return expiresAt == null || !DateTime.now().toUtc().isBefore(expiresAt);
  }

  static Future<void> clear() async {
    for (final key in [
      _usernameKey,
      _hashKey,
      _saltKey,
      _sessionKey,
      _verifiedAtKey,
    ]) {
      await _storage.delete(key: key);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offlineLogin');
    await prefs.remove('offlineExpiresAt');
  }

  static String _hash(String password, String salt) {
    var value = '$salt:$password';
    for (var i = 0; i < 12000; i++) {
      value = sha256.convert(utf8.encode(value)).toString();
    }
    return value;
  }

  static String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
