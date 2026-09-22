import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/features/tajweed/presentation/debug_tajweed_preview_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Respons palsu Al-Fatihah (7 ayat) dengan teks sintetis; [broken] = ayat
/// yang markup tajwidnya sengaja rusak.
MockClient _client({Set<int> broken = const {}, int ayahCount = 7}) {
  return MockClient((request) async {
    final field = request.url.pathSegments.last;
    final verses = [
      for (var i = 1; i <= ayahCount; i++)
        {
          'verse_key': '1:$i',
          'text_$field': field == 'uthmani'
              ? 'polos $i'
              : broken.contains(i)
                  ? 'a$i</tajweed>b'
                  : 'a$i<tajweed class=ikhafa>b</tajweed><span class=end>$i</span>',
        },
    ];
    return http.Response.bytes(
      utf8.encode(jsonEncode({'verses': verses})),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

Future<void> _pump(WidgetTester tester, http.Client client) async {
  await tester.pumpWidget(MaterialApp(
    theme: SacredTheme.light,
    home: DebugTajweedPreviewScreen(client: client),
  ));
  // Aset terjemahan dimuat dengan I/O nyata, sedangkan spinner membuat
  // pumpAndSettle tidak pernah tenang: tunggu sampai spinner hilang.
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
  });

  testWidgets('menampilkan ayat bertajwid dan melaporkan markup rusak',
      (tester) async {
    await _pump(tester, _client(broken: {3}));

    expect(find.text('1:1'), findsOneWidget);
    expect(find.text('Ikhfa Haqiqi ×1'), findsWidgets);
    expect(find.textContaining('Markup ditolak: 1:3'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('polos 3'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('polos 3'), findsOneWidget);
    expect(
      find.text(
        'Warna tajwid tidak tersedia untuk ayat ini. '
        'Ditampilkan: QF text_uthmani (encoding berbeda).',
      ),
      findsOneWidget,
    );
  });

  testWidgets('switch mematikan warna tajwid', (tester) async {
    await _pump(tester, _client());
    expect(find.byType(ActionChip), findsWidgets);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNothing);
    expect(find.text('a1b'), findsOneWidget);
  });

  testWidgets('respons tidak cocok manifest ditolak dengan tombol coba lagi',
      (tester) async {
    await _pump(tester, _client(ayahCount: 6));

    expect(find.textContaining('tidak cocok manifest'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.text('1:1'), findsNothing);
  });
}
