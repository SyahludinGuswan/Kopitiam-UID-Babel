import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/services/master_data_comparison.dart';

void main() {
  test('ignores row order and column order', () {
    expect(MasterDataComparison.equal([
      {'No': 1, 'Temuan': 'A'}, {'No': 2, 'Temuan': 'B'},
    ], [
      {'Temuan': 'B', 'No': 2}, {'Temuan': 'A', 'No': 1},
    ]), isTrue);
  });
  test('detects edits even when row counts match', () {
    expect(MasterDataComparison.equal([
      {'Temuan': 'A', 'Prioritas': 'Minor'},
    ], [
      {'Temuan': 'A', 'Prioritas': 'Mayor'},
    ]), isFalse);
  });
  test('detects additions deletions duplicate counts and renamed columns', () {
    final rows = <Map<String, dynamic>>[{'Objek Inspeksi': 'Jaringan'}];
    expect(MasterDataComparison.equal(rows, [...rows, ...rows]), isFalse);
    expect(MasterDataComparison.equal(rows, []), isFalse);
    expect(MasterDataComparison.equal(rows, [{'Objek Inspkesi': 'Jaringan'}]), isFalse);
    expect(MasterDataComparison.equal([], []), isTrue);
  });
  test('rejects missing or malformed datasets rather than treating them as empty', () {
    expect(() => MasterDataComparison.validate(null), throwsFormatException);
    expect(() => MasterDataComparison.validate([1]), throwsFormatException);
    expect(MasterDataComparison.validate([]), isEmpty);
  });
}
