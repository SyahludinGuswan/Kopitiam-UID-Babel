import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'api_activity.dart';
import 'api_backoff.dart';
import 'device_session_service.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://script.google.com/macros/s/AKfycbxi45JX9sm_sgeLvXzI6KZsvJAlzaWhjtfT6p2W51vqwvp-TY7gAsXC9PA-Q_HZYp0o3Q/exec',
  );
  static const _redirectCodes = {301, 302, 303, 307, 308};
  static const _appsScriptHost = 'script.google.com';
  static const _contentHost = 'script.googleusercontent.com';
  static final _jitter = Random.secure();

  static Duration _timeoutFor(Map<String, dynamic> payload) {
    final action = '${payload['action'] ?? ''}';
    if (action == 'loginPerangkat' || action == 'cekPerangkat') return const Duration(seconds: 25);
    if (action.startsWith('sync')) return const Duration(seconds: 150);
    if (action == 'getMasterData' || action == 'getMasterGardu') return const Duration(seconds: 90);
    return const Duration(seconds: 45);
  }

  static Future<http.Response> _postAppsScript(Map<String, dynamic> payload) async {
    final client = http.Client();
    final timeout = _timeoutFor(payload);
    final initialUri = Uri.parse(baseUrl);
    if (initialUri.scheme != 'https' || initialUri.host != _appsScriptHost) {
      throw StateError('Alamat API Apps Script tidak valid.');
    }
    try {
      final request = http.Request('POST', initialUri)
        ..followRedirects = false
        ..headers['Accept'] = 'application/json'
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..body = jsonEncode(payload);
      final response = await http.Response.fromStream(await client.send(request).timeout(timeout));
      if (!_redirectCodes.contains(response.statusCode)) return response;
      final location = response.headers['location'];
      if (location == null || location.trim().isEmpty) throw StateError('API mengirim redirect tanpa alamat tujuan.');
      final contentUri = initialUri.resolve(location.trim());
      if (contentUri.scheme != 'https' || contentUri.host != _contentHost) {
        throw StateError('Redirect respons API menuju alamat yang tidak diizinkan.');
      }
      final contentRequest = http.Request('GET', contentUri)
        ..followRedirects = false
        ..headers['Accept'] = 'application/json';
      final contentResponse = await http.Response.fromStream(await client.send(contentRequest).timeout(timeout));
      if (_redirectCodes.contains(contentResponse.statusCode)) {
        throw StateError('Redirect ContentService berulang (HTTP ${contentResponse.statusCode}). Perbarui deployment Apps Script.');
      }
      return contentResponse;
    } on TimeoutException {
      final action = '${payload['action'] ?? 'permintaan'}';
      throw StateError(action.startsWith('sync')
          ? 'Sinkronisasi melewati batas waktu. Periksa jaringan lalu coba lagi; data lokal tetap aman.'
          : 'Server terlalu lama merespons. Periksa jaringan lalu coba lagi.');
    } finally {
      client.close();
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) throw StateError('Respons API kosong (HTTP ${response.statusCode}).');
    if (response.statusCode < 200 || response.statusCode >= 300) throw StateError('API gagal (HTTP ${response.statusCode}).');
    final value = jsonDecode(body);
    if (value is Map) return Map<String, dynamic>.from(value);
    throw StateError('Format respons API tidak valid.');
  }

  static Future<Map<String, dynamic>> _postMap(Map<String, dynamic> payload) {
    final action = '${payload['action'] ?? ''}';
    return ApiActivity.track(action, () async {
      var retryCount = 0;
      while (true) {
        final response = _decode(await _postAppsScript(payload));
        if (!ApiBackoff.shouldRetry(response, retryCount)) return response;
        final delay = ApiBackoff.delayFor(
          retryCount: retryCount,
          retryAfterSeconds: response['retryAfterSeconds'],
          jitterMilliseconds: _jitter.nextInt(1001),
        );
        retryCount++;
        await Future<void>.delayed(delay);
      }
    });
  }

  static Future<Map<String, dynamic>> loginPerangkat(String username, String password) async {
    final device = await DeviceSessionService.deviceName();
    final response = await _postMap({'action': 'loginPerangkat', 'username': username, 'password': password, 'perangkat': device});
    if (response['success'] == true && response['deviceToken'] != null) {
      response['roleVerifiedOnline'] = true;
      response['offlineLogin'] = false;
      await DeviceSessionService.save(deviceToken: response['deviceToken'].toString(), profile: response);
    }
    return response;
  }

  static Future<Map<String, dynamic>> cekPerangkat() async {
    final device = await DeviceSessionService.token();
    if (device.isEmpty) return {'success': false, 'kode': 'TANPA_TOKEN'};
    return _postMap({'action': 'cekPerangkat', 'deviceToken': device});
  }

  static Future<Map<String, dynamic>> getRoleProfile(String token) => _postMap({'action': 'getRoleProfile', 'token': token});
  static Future<Map<String, dynamic>> getMasterData(String token) => _postMap({'action': 'getMasterData', 'token': token});
  static Future<Map<String, dynamic>> getMasterGardu(String token) => _postMap({'action': 'getMasterGardu', 'token': token});
  static Future<Map<String, dynamic>> getWoInsjar(String token) => _postMap({'action': 'getWoInsjar', 'token': token});
  static Future<Map<String, dynamic>> getTemuan(String token, String kodeWo) => _postMap({'action': 'getTemuanInspeksi', 'token': token, 'kodeWo': kodeWo});
  static Future<Map<String, dynamic>> syncWoInsjar(String token, List<Map<String, dynamic>> rows) => _postMap({'action': 'syncWoInsjar', 'token': token, 'rows': rows});
  static Future<Map<String, dynamic>> syncTemuan(String token, Map<String, dynamic> row) => _postMap({'action': 'syncTemuanInspeksi', 'token': token, 'row': row});
  static Future<Map<String, dynamic>> getWoRow(String token) => _postMap({'action': 'getWoRow', 'token': token});
  static Future<Map<String, dynamic>> syncWoRow(String token, List<Map<String, dynamic>> rows) => _postMap({'action': 'syncWoRow', 'token': token, 'rows': rows});
  static Future<Map<String, dynamic>> getWoHarJar(String token) => _postMap({'action': 'getWoHarJar', 'token': token});
  static Future<Map<String, dynamic>> syncWoHarJar(String token, List<Map<String, dynamic>> rows) => _postMap({'action': 'syncWoHarJar', 'token': token, 'rows': rows});
  static Future<Map<String, dynamic>> getWoHarDu(String token) => _postMap({'action': 'getWoHarDu', 'token': token});
  static Future<Map<String, dynamic>> syncWoHarDu(String token, List<Map<String, dynamic>> rows) => _postMap({'action': 'syncWoHarDu', 'token': token, 'rows': rows});
  static Future<Map<String, dynamic>> getWoInsdu(String token) => _postMap({'action': 'getWoInsdu', 'token': token});
  static Future<Map<String, dynamic>> syncWoInsdu(String token, List<Map<String, dynamic>> rows) => _postMap({'action': 'syncWoInsdu', 'token': token, 'rows': rows});

  static Future<Map<String, dynamic>> logoutPerangkat({String token = ''}) async {
    final device = await DeviceSessionService.token();
    try {
      return await _postMap({'action': 'logoutPerangkat', 'deviceToken': device, 'token': token});
    } finally {
      await DeviceSessionService.clear();
    }
  }

  static Future<Map<String, dynamic>> login(String username, String password) => loginPerangkat(username, password);
  static Future<Map<String, dynamic>> cekSesi(String token) => cekPerangkat();
  static Future<Map<String, dynamic>> logout(String token) => logoutPerangkat(token: token);
}
