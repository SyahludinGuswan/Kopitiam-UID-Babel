import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/wo_insdu.dart';
import 'package:kopitiam_mobile/services/wo_insdu_repository.dart';

WoInsdu item(
  int? installed,
  int? used, {
  String status = WoInsdu.statusSelesai,
  String wbp = '-3.019482,106.454827',
  String wbpTime = '13 September 2026, 16:00:00',
  String lwbp = '-3.019481,106.454828',
  String lwbpTime = '13 September 2026, 23:00:00',
}) => WoInsdu(
  kodeWo: 'WO-1',
  jurusanTerpasang: installed,
  jurusanTerpakai: used,
  statusWo: status,
  koordinatPenginputanWbp: wbp,
  waktuPenginputanWbp: wbpTime,
  koordinatPenginputanLwbp: lwbp,
  waktuPenginputanLwbp: lwbpTime,
);

void main() {
  test('accepts independent Jurusan values in range 1 to 4', () {
    expect(() => WoInsduRepository.validateContract(item(4, 3), requireComplete: true), returnsNormally);
    expect(() => WoInsduRepository.validateContract(item(1, 1), requireComplete: true), returnsNormally);
  });

  test('rejects values outside 1 to 4', () {
    for (final value in [0, 5]) {
      expect(() => WoInsduRepository.validateContract(item(value, 1), requireComplete: true), throwsStateError);
      expect(() => WoInsduRepository.validateContract(item(4, value), requireComplete: true), throwsStateError);
    }
  });

  test('rejects Jurusan Terpakai above Jurusan Terpasang', () {
    expect(() => WoInsduRepository.validateContract(item(2, 3), requireComplete: true), throwsStateError);
  });

  test('requires parseable WBP and LWBP coordinates and capture times', () {
    expect(() => WoInsduRepository.validateContract(item(2, 2), requireComplete: true), returnsNormally);
    expect(() => WoInsduRepository.validateContract(item(2, 2, wbp: ''), requireComplete: true), throwsStateError);
    expect(() => WoInsduRepository.validateContract(item(2, 2, lwbpTime: ''), requireComplete: true), throwsStateError);
  });

  test('rejects malformed, out-of-range, and Null Island coordinates', () {
    for (final value in ['abc', '1,2,3', '91,106', '-3,181', '0,0']) {
      expect(() => WoInsduRepository.validateContract(item(2, 2, wbp: value), requireComplete: true), throwsStateError);
    }
  });

  test('allows empty contract fields only for unfinished local drafts', () {
    final draft = item(null, null, status: WoInsdu.statusDalam, wbp: '', wbpTime: '', lwbp: '', lwbpTime: '');
    expect(() => WoInsduRepository.validateContract(draft, requireComplete: false), returnsNormally);
    expect(() => WoInsduRepository.validateContract(draft, requireComplete: true), throwsStateError);
  });
}
