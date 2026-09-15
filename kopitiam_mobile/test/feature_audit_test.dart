import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:kopitiam_mobile/models/temuan_inspeksi.dart';
import 'package:kopitiam_mobile/models/wo_insjar.dart';
import 'package:kopitiam_mobile/services/api_service.dart';
import 'package:kopitiam_mobile/services/photo_watermark_service.dart';
import 'package:kopitiam_mobile/services/temuan_repository.dart';

void main() {
  group('Audit: Model & Logika WO', () {
    test('fromRemote dengan data dummy server dipetakan utuh', () {
      final wo = WoInsjar.fromRemote({
        'No': '5', 'Kode WO': 'PLG-2026-001', 'Kode UIW': 'UIW001',
        'Kode UP3': 'UP3001', 'Kode ULP': 'PLG', 'ULP': 'ULP PLG',
        'Hari': 'Kamis', 'Tanggal': '28 Agustus 2026',
        'Penyulang': 'PENYULANG-1', 'Section Awal': 'A-01',
        'Section Akhir': 'A-02', 'Section': 'A-01-02',
        'Koordinat Awal': '-6.12, 106.10',
        'Koordinat Akhir': '-6.13, 106.11', 'Realisasi kmS': '2.45',
        'Waktu Mulai': '08:00', 'Waktu Selesai': '09:30',
        'Durasi Pekerjaan': '01:30:00', 'Status WO': 'Dalam Pengerjaan',
      });
      expect(wo.kodeWo, 'PLG-2026-001');
      expect(wo.kodeUlp, 'PLG');
      expect(wo.sectionAwal, 'A-01');
      expect(wo.realisasiKms, 2.45);
      expect(wo.statusWo, WoInsjar.statusDalam);
      expect(wo.isDirty, false);
    });

    test('normalisasiStatus menerima variasi status server', () {
      expect(WoInsjar.normalisasiStatus('SELESAI'), WoInsjar.statusSelesai);
      expect(WoInsjar.normalisasiStatus('berjalan'), WoInsjar.statusDalam);
      expect(WoInsjar.normalisasiStatus('Mulai Pengerjaan'), WoInsjar.statusMulai);
    });

    test('round-trip toMap <-> fromMap mempertahankan is_dirty & status', () {
      final wo = WoInsjar(kodeWo: 'PLG-2026-002', penyulang: 'PENYULANG-2', statusWo: WoInsjar.statusSelesai, isDirty: true);
      final back = WoInsjar.fromMap(wo.toMap());
      expect(back.kodeWo, wo.kodeWo);
      expect(back.statusWo, WoInsjar.statusSelesai);
      expect(back.isDirty, true);
      expect(back.toRemote()['Status WO'], WoInsjar.statusSelesai);
    });

    test('durasi, format tanggal, dan parse stamp round-trip', () {
      expect(WoInsjar.formatTanggal(DateTime(2026, 8, 1)), '01 Agustus 2026');
      expect(WoInsjar.hitungDurasi(DateTime(2026, 8, 1, 8), DateTime(2026, 8, 1, 9, 30)), '01:30:00');
      final stamp = WoInsjar.stampLengkap(DateTime(2026, 8, 29, 10, 11, 12));
      final parsed = WoInsjar.parseStamp(stamp);
      expect(parsed, isNotNull);
      expect(parsed!.day, 29);
      expect(parsed.hour, 10);
      expect(WoInsjar.hariIndonesia[parsed.weekday - 1], isNotEmpty);
    });
  });

  group('Audit: Model Temuan & Peta ke Backend', () {
    test('toRemote memuat semua kunci yang dibaca backend Apps Script', () {
      final item = TemuanInspeksi(kodeTemuan: 'PLG-2026-001.TO-001', kodeWo: 'PLG-2026-001', segmen: 'A-04/A-05', jenisObject: 'Jaringan', tier: 'Tier 1', temuan: 'Tebang Besar', jarak: 3.5, jenisPohon: 'Sengon', tinggiPohon: 10, prioritas: 'Mayor', koordinat: '-6.12, 106.34', fotoTemuan: 'a.jpg', fotoLingkungan: 'b.jpg');
      final remote = item.toRemote();
      expect(remote['Kode WO'], 'PLG-2026-001');
      expect(remote['Kode Temuan'], 'PLG-2026-001.TO-001');
      expect(remote['Temuan'], 'Tebang Besar');
      expect(remote['Segmen'], 'A-04/A-05');
      expect(remote['Koordinat Temuan'], '-6.12, 106.34');
      expect(remote['Prioritas'], 'Mayor');
      expect(remote['Jenis Object'], 'Jaringan');
      expect(remote['Tier'], 'Tier 1');
      expect(remote['Foto Lingkungan Sekitaran Tiang'], 'b.jpg');
    });

    test('round-trip dan fromRemote menormalkan kolom server', () {
      final source = TemuanInspeksi(kodeTemuan: 'PLG-2026-001.TO-002', kodeWo: 'PLG-2026-001', temuan: 'Kabel Geser', dirty: true);
      final back = TemuanInspeksi.fromMap(source.toMap());
      expect(back.kodeTemuan, source.kodeTemuan);
      expect(back.dirty, true);
      final serverRow = TemuanInspeksi.fromRemote({'Kode WO': 'PLG-2026-001', 'Kode Temuan': 'PLG-2026-001.TO-002', 'Temuan': 'Kabel Geser', 'Koordinat Temuan': '-6.12, 106.34', 'Prioritas': 'Sedang', 'Waktu Input': '29 Agustus 2026, 08:00:00'});
      expect(serverRow.dirty, false);
      expect(serverRow.prioritas, 'Sedang');
      expect(serverRow.koordinat, '-6.12, 106.34');
    });
  });

  group('Audit: Prioritas mengikuti formula IFS (data dummy master)', () {
    final repo = TemuanRepository();
    test('Pohon vegetasi: Minor (jarak>5 dan tinggi<9)', () => expect(repo.prioritas('Rabas / Pangkas', 6, 2.5, const []), 'Minor'));
    test('Pohon vegetasi: Sedang (jarak 2..6 dan tinggi>=9)', () => expect(repo.prioritas('Tebang Sedang', 4, 10, const []), 'Sedang'));
    test('Pohon vegetasi: Mayor (jarak<3 dan tinggi>=9)', () { expect(repo.prioritas('Tebang Besar', 2, 10, const []), 'Mayor'); expect(repo.prioritas('Rabas / Pangkas', 0.5, 9, const []), 'Mayor'); });
    test('Pohon vegetasi menutup celah kombinasi IFS (selalu ada prioritas)', () { expect(repo.prioritas('Rabas / Pangkas', 7, 12, const []), 'Minor'); expect(repo.prioritas('Tebang Sedang', 1, 5, const []), 'Mayor'); expect(repo.prioritas('Rabas / Pangkas', 3, 5, const []), 'Mayor'); expect(repo.prioritas('Tebang Besar', 7, 8, const []), 'Minor'); expect(repo.prioritas('Rabas/Pangkas', 4, 7, const []), 'Mayor'); expect(repo.prioritas('  tebang sedang  ', 6, 10, const []), 'Minor'); });
    test('Non-vegetasi: LOOKUP master via kolom Temuan maupun Nama Temuan', () { const master = [{'Temuan': 'Kabel Geser', 'Prioritas': 'Sedang'}, {'Nama Temuan': 'Pohon Tersangkut', 'Prioritas': 'Mayor'}, {'Nama Temuan': '', 'Prioritas': 'Minor'}]; expect(repo.prioritas('Kabel Geser', null, null, master), 'Sedang'); expect(repo.prioritas('Pohon Tersangkut', null, null, master), 'Mayor'); });
    test('Header master dengan varian nama kolom (normalisasi)', () { const master = [{' NAMA TEMUAN ': 'Baret Tiang', 'Prioritas ': 'Minor'}]; expect(repo.prioritas('Baret Tiang', null, null, master), 'Minor'); });
    test('jenisObject menyesuaikan Sub-Tim', () { expect(repo.jenisObject({'subTim': 'Inspeksi Jaringan'}), 'Jaringan'); expect(repo.jenisObject({'subTim': 'INSJAR'}), 'Jaringan'); expect(repo.jenisObject({'tim': 'Inspeksi Gardu'}), 'Gardu'); expect(repo.jenisObject({'subTim': 'Lain-lain'}), ''); });
  });

  group('Audit: Watermark menempel pada foto (render 2048px)', () {
    test('hasil render adalah JPEG 2048px dengan panel terpasang', () async {
      final image = img.Image(width: 2048, height: 1152);
      img.fill(image, color: img.ColorRgb8(246, 247, 249));
      final source = File(p.join(Directory.systemTemp.path, 'dummy_foto_temuan.jpg'));
      source.writeAsBytesSync(img.encodeJpg(image, quality: 90));
      final item = TemuanInspeksi(kodeTemuan: 'PLG-2026-001.TO-001', kodeWo: 'PLG-2026-001', temuan: 'Rabas / Pangkas', jenisObject: 'Jaringan', koordinat: '-6.12, 106.34', ulp: 'ULP PLG', penyulang: 'PENYULANG-1', section: 'A-01-02', segmen: 'A-04/A-05', hari: 'Jumat', tanggal: '29 Agustus 2026', waktuInput: '29 Agustus 2026, 08:00:12');
      final output = await PhotoWatermarkService.render(sourcePath: source.path, item: item, photoLabel: 'Foto Temuan');
      final outputFile = File(output);
      expect(outputFile.existsSync(), true);
      expect(outputFile.lengthSync(), greaterThan(1024));
      final decoded = img.decodeImage(outputFile.readAsBytesSync());
      expect(decoded, isNotNull);
      expect(decoded!.width, 2048);
      final panelPixel = decoded.getPixel(150, 800);
      expect(panelPixel.r + panelPixel.g + panelPixel.b, lessThan(220), reason: 'panel harus terpasang');
      final backgroundPixel = decoded.getPixel(50, 50);
      expect(backgroundPixel.r + backgroundPixel.g + backgroundPixel.b, greaterThan(680), reason: 'latar putih');
      source.deleteSync(); outputFile.deleteSync();
    });
  });

  group('Audit: Kontrak fitur aktif di kode sumber', () {
    test('ApiService merutekan semua action backend melalui helper yang sesuai', () {
      final source = File('lib/services/api_service.dart').readAsStringSync();
      expect(source, contains("'action': 'syncTemuanInspeksi'"));
      expect(source, contains("'action': 'getTemuanInspeksi'"));
      expect(source, contains("_syncRows('syncWoInsjar'"));
      expect(source, contains("'action': 'getMasterData'"));
      expect(source, contains("'action': 'logoutPerangkat'"));
      expect(source, contains("'action': 'loginPerangkat'"));
      expect(source, contains('SyncReceiptGuard.verify'));
    });

    test('baseUrl API menunjuk Apps Script https', () { final uri = Uri.parse(ApiService.baseUrl); expect(uri.scheme, 'https'); expect(uri.host, 'script.google.com'); expect(uri.path, contains('/macros/s/')); expect(uri.path, endsWith('/exec')); });
    test('sumber sinkron temuan mengirim payload + foto base64', () { final source = File('lib/services/temuan_repository.dart').readAsStringSync(); expect(source, contains('fotoTemuanBase64')); expect(source, contains('fotoLingkunganBase64')); expect(source, contains("'is_dirty': 0")); expect(source, contains('ApiService.syncTemuan(token, payload)')); });
    test('tidak ada implementasi fitur yang masih placeholder', () { final files = Directory('lib').listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.dart')); for (final file in files) { final content = file.readAsStringSync(); expect(content.contains('UnimplementedError') && content.contains('throw'), false, reason: '${file.path} masih punya stub UnimplementedError'); } });
  });
}
