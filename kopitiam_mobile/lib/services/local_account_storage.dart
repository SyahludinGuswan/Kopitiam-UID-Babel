import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Menentukan root lokal hanya dari identitas akun yang telah diverifikasi.
/// Data global legacy sengaja tidak dirujuk karena pemiliknya tidak dapat
/// dibuktikan.
class LocalAccountStorage {
  LocalAccountStorage._();

  static final LocalAccountStorage instance = LocalAccountStorage._();
  static const _databasePrefix = 'kopitiam_account_';
  static const _accountsDirectory = 'kopitiam_accounts';

  String? _namespace;

  String? get activeNamespace => _namespace;

  static String namespaceForUsername(Object? username) {
    final normalized = '$username'.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw StateError(
        'Akun terverifikasi wajib dipilih sebelum membuka data lokal.',
      );
    }
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  String get namespace {
    final value = _namespace;
    if (value == null) {
      throw StateError(
        'Akun terverifikasi wajib dipilih sebelum membuka data lokal.',
      );
    }
    return value;
  }

  Future<void> activateForProfile(Map<String, dynamic> profile) =>
      activate(profile['username']);

  Future<void> activate(Object? username) async {
    _namespace = namespaceForUsername(username);
  }

  Future<void> clearActiveAccount() async {
    _namespace = null;
  }

  Future<Directory> documentsDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(root.path, _accountsDirectory, namespace),
    );
    await directory.create(recursive: true);
    return directory;
  }

  String get databaseName => '$_databasePrefix$namespace.db';

  Future<String> databasePath() async {
    final root = await getDatabasesPath();
    return p.join(root, databaseName);
  }
}
