import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopitiam_mobile/models/wo_insdu.dart';
import 'package:kopitiam_mobile/screens/wo_insdu_form_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('pengukuran Gardu memakai koma dan desain lokasi final', (tester) async {
    await tester.pumpWidget(const MaterialApp(home:WoInsduFormScreen(existing:WoInsdu(kodeWo:'INSDU-001',nomorGardu:'GD-101',statusWo:WoInsdu.statusDalam,bebanUtamaRWbp:12.5,koordinatPenginputanWbp:'-2.1234567,106.1234567',waktuPenginputanWbp:'11/09/2026 18:42:16',jarakGarduPetugasWbp:8.4),sesi:{'subTim':'Inspeksi Gardu'})));
    await tester.pumpAndSettle();
    final firstField=find.byWidgetPredicate((widget)=>widget is TextField&&widget.decoration?.labelText=='FASA R').first;
    expect(find.text('12,5'),findsOneWidget);
    expect(find.text('Lokasi Penginputan WBP'),findsOneWidget);
    expect(find.byIcon(Icons.gps_fixed_rounded),findsWidgets);
    expect(find.byIcon(Icons.access_time_rounded),findsWidgets);
    await tester.enterText(firstField,'12.5'); await tester.pump(); expect(find.text('Gunakan (,) sebagai pemisah'),findsOneWidget);
    await tester.enterText(firstField,'12,5'); await tester.pump(); expect(find.text('Gunakan (,) sebagai pemisah'),findsNothing);
  });
}
