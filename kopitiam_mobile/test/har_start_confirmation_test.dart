import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/wo_har_du.dart';
import 'package:kopitiam_mobile/models/wo_har_jar.dart';
import 'package:kopitiam_mobile/widgets/wo_har_du_card.dart';
import 'package:kopitiam_mobile/widgets/wo_har_jar_card.dart';

void main() {
  testWidgets('Har Jar tidak mulai sebelum verifikasi disetujui', (tester) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WoHarJarCard(
            wo: const WoHarJar(
              kodeWo: 'HARJAR-001',
              penyulang: 'Tangit',
              section: 'GH Toboali',
              segmen: 'SP 23',
              statusWo: WoHarJar.statusMenunggu,
            ),
            onKerjakan: () => starts++,
            onLanjut: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Kerjakan'));
    await tester.pumpAndSettle();
    expect(starts, 0, reason: 'Membuka popup tidak boleh memulai WO.');
    expect(find.text('Mulai pekerjaan Har Jar?'), findsOneWidget);

    await tester.tap(find.text('Tidak'));
    await tester.pumpAndSettle();
    expect(starts, 0, reason: 'Menolak verifikasi harus mempertahankan WO.');

    await tester.tap(find.text('Kerjakan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, mulai'));
    await tester.pumpAndSettle();
    expect(starts, 1, reason: 'WO hanya mulai setelah konfirmasi eksplisit.');
  });

  testWidgets('Har Du tidak mulai sebelum verifikasi disetujui', (tester) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WoHarDuCard(
            wo: const WoHarDu(
              kodeWo: 'HARDU-001',
              nomorGardu: 'TB-042',
              penyulang: 'Tangit',
              section: 'ACR SP AMD',
              statusWo: WoHarDu.statusMenunggu,
            ),
            onKerjakan: () => starts++,
            onLanjut: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Kerjakan'));
    await tester.pumpAndSettle();
    expect(starts, 0, reason: 'Membuka popup tidak boleh memulai WO.');
    expect(find.text('Mulai pekerjaan Har Du?'), findsOneWidget);

    await tester.tap(find.text('Tidak'));
    await tester.pumpAndSettle();
    expect(starts, 0, reason: 'Menolak verifikasi harus mempertahankan WO.');

    await tester.tap(find.text('Kerjakan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, mulai'));
    await tester.pumpAndSettle();
    expect(starts, 1, reason: 'WO hanya mulai setelah konfirmasi eksplisit.');
  });
}
