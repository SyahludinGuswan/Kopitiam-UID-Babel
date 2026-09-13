import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/wo_insdu.dart';
import 'package:kopitiam_mobile/services/wo_insdu_repository.dart';

WoInsdu item(int? installed, int? used, {String status = WoInsdu.statusSelesai}) =>
    WoInsdu(kodeWo: 'WO-1', jurusanTerpasang: installed, jurusanTerpakai: used, statusWo: status);

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

  test('allows both values empty only for unfinished local drafts', () {
    expect(() => WoInsduRepository.validateJurusan(item(null, null, status: WoInsdu.statusDalam), requireComplete: false), returnsNormally);
    expect(() => WoInsduRepository.validateJurusan(item(null, null), requireComplete: true), throwsStateError);
  });
}
