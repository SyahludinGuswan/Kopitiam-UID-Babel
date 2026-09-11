import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/wo_insdu.dart';
import 'package:kopitiam_mobile/screens/wo_insdu_form_screen.dart';

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

void main() {
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

    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    expect(find.text('01'), findsOneWidget);
    expect(find.text('Identitas Gardu'), findsOneWidget);
    expect(find.text('Pengukuran WBP'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Pengukuran LWBP'), 350, scrollable: scrollable);
    expect(find.text('Pengukuran LWBP'), findsOneWidget);

    await tester.scrollUntilVisible(field('Cover FCO Atas'), 500, scrollable: scrollable);
    expect(options(tester, 'Cover FCO Atas'), [
      'Lengkap',
      'Tidak Lengkap',
      'Rusak',
      'Tidak ada',
    ]);

    await tester.scrollUntilVisible(field('Jumperan Atas'), 250, scrollable: scrollable);
    expect(options(tester, 'Jumperan Atas'), [
      'A3C',
      'A3CS (Lengkap)',
      'A3CS (Tidak Lengkap)',
      'Protective Sleeve (Lengkap)',
      'Protective Sleeve (Tidak Lengkap)',
    ]);
  });
}
