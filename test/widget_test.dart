import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/screens/quran_library_screen.dart';

void main() {
  testWidgets('daftar Qur’an dapat dicari', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: QuranLibraryScreen()));
    expect(find.text('Al-Fatihah'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Yasin');
    await tester.pump();
    expect(find.text('Yasin'), findsOneWidget);
    expect(find.text('Al-Fatihah'), findsNothing);
  });
}
