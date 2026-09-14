import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceSessionService {
  static const _storage = FlutterSecureStorage();
  static const _deviceTokenKey = 'simandist_device_token';
  static const _profileKey = 'simandist_device_profile';
  static const _verifiedAtKey = 'simandist_device_verified_at';
  static const _verifiedUsernameKey = 'simandist_verified_username';

  static String normalizeUsername(Object? value) =>
      '${value ?? ''}'.trim().toLowerCase();

  static Future<String> token() =>
      _storage.read(key: _deviceTokenKey).then((value) => value ?? '');

  static Future<String> verifiedUsername() => _storage
      .read(key: _verifiedUsernameKey)
      .then((value) => normalizeUsername(value));

  static Future<void> save({
    required String deviceToken,
    required Map<String, dynamic> profile,
  }) async {
    final username = normalizeUsername(profile['username']);
    if (username.isEmpty) {
      throw StateError('Profil sesi tidak memiliki username terverifikasi.');
    }
    await _storage.write(key: _deviceTokenKey, value: deviceToken);
    await _storage.write(key: _profileKey, value: jsonEncode(profile));
    await _storage.write(key: _verifiedUsernameKey, value: username);
    await _storage.write(
      key: _verifiedAtKey,
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  static Future<Map<String, dynamic>?> profile() async {
    final raw = await _storage.read(key: _profileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map) return null;
      final result = Map<String, dynamic>.from(value);
      final owner = await verifiedUsername();
      if (owner.isEmpty || normalizeUsername(result['username']) != owner) {
        await clear();
        return null;
      }
      return result;
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<DateTime?> verifiedAt() async {
    final raw = await _storage.read(key: _verifiedAtKey);
    return DateTime.tryParse(raw ?? '')?.toUtc();
  }

  static Future<String> deviceName() async {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'perangkat';
    }
  }

  static Future<void> clear() async {
    await _storage.delete(key: _deviceTokenKey);
    await _storage.delete(key: _profileKey);
    await _storage.delete(key: _verifiedAtKey);
    await _storage.delete(key: _verifiedUsernameKey);
  }
}
