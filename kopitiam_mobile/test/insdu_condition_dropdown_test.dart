import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/wo_insdu.dart';
import 'package:kopitiam_mobile/screens/wo_insdu_form_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is DropdownButtonFormField<String> &&
      widget.decoration.labelText == label,
);

List<String?> options(WidgetTester tester, String label) {
  final button = find.descendant(
    of: field(label),
    matching: find.byType(DropdownButton<String>),
  );
  return tester
      .widget<DropdownButton<String>>(button)
      .items!
      .map((item) => item.value)
      .toList();
}

Future<void> buildUntilVisible(
  WidgetTester tester,
  Finder list,
  Finder target,
) async {
  for (var attempt = 0; attempt < 20 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('form Gardu memakai enam bagian dan dropdown kondisi tetap lengkap', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WoInsduFormScreen(
          existing: WoInsdu(
            kodeWo: 'INSDU-001',
            nomorGardu: 'GD-101',
            statusWo: WoInsdu.statusDalam,
          ),
          sesi: {'subTim': 'Inspeksi Gardu'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byType(ListView).first;
    expect(find.text('01'), findsOneWidget);
    expect(find.text('Identitas Gardu'), findsOneWidget);

    await buildUntilVisible(tester, list, find.text('Pengukuran WBP'));
    await buildUntilVisible(tester, list, find.text('Pengukuran LWBP'));

    await buildUntilVisible(tester, list, field('COVER FCO ATAS'));
    expect(options(tester, 'COVER FCO ATAS'), [
      'Lengkap',
      'Tidak Lengkap',
      'Rusak',
      'Tidak ada',
    ]);

    await buildUntilVisible(tester, list, field('JUMPERAN ATAS'));
    expect(options(tester, 'JUMPERAN ATAS'), [
      'A3C',
      'A3CS (Lengkap)',
      'A3CS (Tidak Lengkap)',
      'Protective Sleeve (Lengkap)',
      'Protective Sleeve (Tidak Lengkap)',
    ]);
  });
}
