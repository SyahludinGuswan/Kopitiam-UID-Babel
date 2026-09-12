import 'dart:convert';

/// Compare full dataset contents, ignoring only row and map-key order.
/// Duplicate rows, value types, and column names remain significant.
abstract final class MasterDataComparison {
  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  static String signature(List<Map<String, dynamic>> rows) {
    final encoded = rows.map((row) => jsonEncode(_canonical(row))).toList()
      ..sort();
    return jsonEncode(encoded);
  }

  static bool equal(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> remote,
  ) => signature(local) == signature(remote);

  static List<Map<String, dynamic>> validate(Object? value) {
    if (value is! List || value.any((row) => row is! Map)) {
      throw const FormatException('Dataset server tidak valid.');
    }
    return value.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }
}
