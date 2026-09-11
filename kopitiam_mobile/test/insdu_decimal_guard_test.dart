import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/wo_insdu.dart';
import 'package:kopitiam_mobile/screens/wo_insdu_form_screen.dart';

void main() {
  testWidgets('pengukuran Gardu memakai koma dan koordinat tampil ringkas', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WoInsduFormScreen(
          existing: WoInsdu(
            kodeWo: 'INSDU-001',
            nomorGardu: 'GD-101',
            statusWo: WoInsdu.statusDalam,
            bebanUtamaRWbp: 12.5,
            koordinatPenginputanWbp: '-2.1234567,106.1234567',
            jarakGarduPetugasWbp: 8.4,
          ),
          sesi: {'subTim': 'Inspeksi Gardu'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'R (A)',
    ).first;
    expect(find.text('12,5'), findsOneWidget);
    expect(find.text('Koordinat Pengisian'), findsWidgets);
    expect(find.byIcon(Icons.gps_fixed_rounded), findsWidgets);

    await tester.enterText(firstField, '12.5');
    await tester.pump();
    expect(find.text('Gunakan (,) sebagai pemisah'), findsOneWidget);

    await tester.enterText(firstField, '12,5');
    await tester.pump();
    expect(find.text('Gunakan (,) sebagai pemisah'), findsNothing);
  });
}
