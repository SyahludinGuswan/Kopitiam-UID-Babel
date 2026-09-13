import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/wo_insdu.dart';
import 'package:kopitiam_mobile/services/wo_insdu_repository.dart';

WoInsdu item(int? installed, int? used, {String status = WoInsdu.statusSelesai, String wbpTime = '13 September 2026, 16:00:00', String lwbpTime = '13 September 2026, 23:00:00'}) => WoInsdu(
  kodeWo: 'WO-1', jurusanTerpasang: installed, jurusanTerpakai: used, statusWo: status,
  koordinatPenginputanWbp: '-3.019482,106.454827', waktuPenginputanWbp: wbpTime,
  koordinatPenginputanLwbp: '-3.019481,106.454828', waktuPenginputanLwbp: lwbpTime,
);

void main() {
  test('accepts independent Jurusan values in range 1 to 4', () {
    expect(() => WoInsduRepository.validateJurusan(item(4, 3), requireComplete: true), returnsNormally);
    expect(() => WoInsduRepository.validateJurusan(item(1, 1), requireComplete: true), returnsNormally);
  });

  test('rejects values outside 1 to 4', () {
    for (final value in [0, 5]) {
      expect(() => WoInsduRepository.validateJurusan(item(value, 1), requireComplete: true), throwsStateError);
      expect(() => WoInsduRepository.validateJurusan(item(4, value), requireComplete: true), throwsStateError);
    }
  });

  test('rejects Jurusan Terpakai above Jurusan Terpasang', () {
    expect(() => WoInsduRepository.validateJurusan(item(2, 3), requireComplete: true), throwsStateError);
  });

  test('capture timestamps use canonical Indonesian format', () {
    expect(() => WoInsduRepository.validateCoordinates(item(2, 1), requireComplete: true), returnsNormally);
    for (final invalid in ['2026-09-13T16:00:00', '13 Sep 2026, 16:00:00', '32 September 2026, 16:00:00', '13 September 2026, 24:00:00']) {
      expect(() => WoInsduRepository.validateCoordinates(item(2, 1, wbpTime: invalid), requireComplete: true), throwsStateError);
    }
  });

  test('allows empty capture only for unfinished local drafts', () {
    final draft = WoInsdu(kodeWo: 'WO-1', statusWo: WoInsdu.statusDalam);
    expect(() => WoInsduRepository.validateContract(draft, requireComplete: false), returnsNormally);
    expect(() => WoInsduRepository.validateContract(draft, requireComplete: true), throwsStateError);
  });
}
