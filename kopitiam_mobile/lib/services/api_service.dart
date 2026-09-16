import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'api_activity.dart';
import 'api_backoff.dart';
import 'device_session_service.dart';
import 'sync_failure_store.dart';
import 'sync_receipt.dart';
import 'sync_request_coordinator.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://script.google.com/macros/s/AKfycbxi45JX9sm_sgeLvXzI6KZsvJAlzaWhjtfT6p2W51vqwvp-TY7gAsXC9PA-Q_HZYp0o3Q/exec',
  );
  static const _redirectCodes = {301, 302, 303, 307, 308};
  static const _appsScriptHost = 'script.google.com';
  static const _contentHost = 'script.googleusercontent.com';
  static const int _maximumSyncRequestBytes = 12 * 1024 * 1024;
  static const _perWoRetryDelays = [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(seconds: 90),
  ];
  static final _jitter = Random.secure();
  static final _syncCoordinator = SyncRequestCoordinator();

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

  static Future<Map<String, dynamic>> _sendWithBackoff(Map<String, dynamic> payload) async {
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
  }

  static Future<Map<String, dynamic>> _postMap(Map<String, dynamic> payload) {
    final action = '${payload['action'] ?? ''}';
    return ApiActivity.track(action, () {
      if (action.startsWith('sync')) {
        return _syncCoordinator.run(() => _sendWithBackoff(payload));
      }
      return _sendWithBackoff(payload);
    });
  }

  static bool _retryableResponse(Map<String, dynamic> response) {
    const retryable = {
      'SERVER_BUSY',
      'SERVER_ERROR',
      'WO_COMMIT_FAILED',
      'HAR_COMMIT_FAILED',
      'SYNC_TRANSACTION_FAILED',
      'EVIDENCE_COMMIT_FAILED',
    };
    return retryable.contains('${response['kode'] ?? ''}');
  }

  static Future<Map<String, dynamic>> _syncRows(
    String action,
    String token,
    List<Map<String, dynamic>> sourceRows,
  ) async {
    final receipts = <dynamic>[];
    final accepted = <dynamic>[];
    final failures = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (final source in sourceRows) {
      final code = '${source['Kode WO'] ?? ''}'.trim();
      if (code.isEmpty) {
        failures.add({'kodeWo': '', 'status': 'manual-action-required', 'message': 'Kode WO kosong.'});
        continue;
      }
      final prior = await SyncFailureStore.read(action, code);
      if (prior != null && !prior.due(now)) {
        failures.add({
          'kodeWo': code,
          'status': prior.status,
          'nextAttemptAt': prior.nextAttemptAt?.toIso8601String(),
          'message': prior.error,
        });
        continue;
      }

      final rows = SyncReceiptGuard.prepare([source]);
      final envelope = {'action': action, 'token': token, 'rows': rows};
      final requestBytes = utf8.encode(jsonEncode(envelope)).length;
      if (requestBytes > _maximumSyncRequestBytes) {
        final state = await SyncFailureStore.recordFailure(
          action: action,
          kodeWo: code,
          error: 'Ukuran request $requestBytes byte melebihi batas aman 12 MiB.',
          now: DateTime.now(),
          retryable: false,
        );
        failures.add({'kodeWo': code, 'status': state.status, 'message': state.error});
        continue;
      }

      Map<String, dynamic>? response;
      Object? lastError;
      var retryable = true;
      for (var attempt = 0; attempt <= _perWoRetryDelays.length; attempt++) {
        try {
          response = await _postMap(envelope);
          if (SyncReceiptGuard.verify(response, rows)) break;
          lastError = response['message'] ?? response['kode'] ?? 'Receipt tidak valid.';
          retryable = _retryableResponse(response);
          if (!retryable) break;
        } catch (error) {
          lastError = error;
          retryable = true;
        }
        if (attempt < _perWoRetryDelays.length) {
          await Future<void>.delayed(_perWoRetryDelays[attempt]);
        }
      }

      if (response != null && SyncReceiptGuard.verify(response, rows)) {
        await SyncFailureStore.clear(action, code);
        final rowReceipts = response['receipts'];
        if (rowReceipts is List) receipts.addAll(rowReceipts);
        final rowAccepted = response['accepted'];
        if (rowAccepted is List) accepted.addAll(rowAccepted);
        continue;
      }

      final state = await SyncFailureStore.recordFailure(
        action: action,
        kodeWo: code,
        error: '$lastError',
        now: DateTime.now(),
        retryable: retryable,
      );
      failures.add({
        'kodeWo': code,
        'status': state.status,
        'nextAttemptAt': state.nextAttemptAt?.toIso8601String(),
        'message': state.error,
      });
    }

    if (failures.isNotEmpty) {
      return {
        'success': false,
        'kode': 'SYNC_PARTIAL',
        'message': '${receipts.length} WO berhasil; ${failures.length} WO tetap tersimpan untuk tindak lanjut.',
        'diproses': receipts.length,
        'accepted': accepted,
        'receipts': receipts,
        'failures': failures,
      };
    }
    return {
      'success': true,
      'diproses': receipts.length,
      'accepted': accepted,
      'receipts': receipts,
    };
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
  static Future<Map<String, dynamic>> syncWoInsjar(String token, List<Map<String, dynamic>> rows) => _syncRows('syncWoInsjar', token, rows);
  static Future<Map<String, dynamic>> syncTemuan(String token, Map<String, dynamic> row) => _postMap({'action': 'syncTemuanInspeksi', 'token': token, 'row': row});
  static Future<Map<String, dynamic>> getWoRow(String token) => _postMap({'action': 'getWoRow', 'token': token});
  static Future<Map<String, dynamic>> syncWoRow(String token, List<Map<String, dynamic>> rows) => _syncRows('syncWoRow', token, rows);
  static Future<Map<String, dynamic>> getWoHarJar(String token) => _postMap({'action': 'getWoHarJar', 'token': token});
  static Future<Map<String, dynamic>> syncWoHarJar(String token, List<Map<String, dynamic>> rows) => _syncRows('syncWoHarJar', token, rows);
  static Future<Map<String, dynamic>> getWoHarDu(String token) => _postMap({'action': 'getWoHarDu', 'token': token});
  static Future<Map<String, dynamic>> syncWoHarDu(String token, List<Map<String, dynamic>> rows) => _syncRows('syncWoHarDu', token, rows);
  static Future<Map<String, dynamic>> getWoInsdu(String token) => _postMap({'action': 'getWoInsdu', 'token': token});
  static Future<Map<String, dynamic>> syncWoInsdu(String token, List<Map<String, dynamic>> rows) => _syncRows('syncWoInsdu', token, rows);

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
