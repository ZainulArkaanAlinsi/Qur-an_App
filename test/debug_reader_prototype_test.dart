import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/features/mushaf/data/qf_debug_mushaf_source.dart';
import 'package:quran_app_2025/features/mushaf/presentation/debug_reader_prototype_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Semua kata fixture dikelompokkan per ayat dalam format respons by_page.
/// Sumber menyaring berdasarkan `page_number`, jadi respons yang sama aman
/// dipakai untuk setiap nomor halaman.
final String _byPageBody = () {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/qf_mushaf_v2_pages_sample.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final verses = <String, List<Map<String, Object>>>{};
  for (final row in (fixture['words'] as List).cast<List>()) {
    verses.putIfAbsent(row[3] as String, () => []).add({
      'id': row[0] as int,
      'page_number': row[1] as int,
      'line_number': row[2] as int,
      'position': row[4] as int,
      'char_type_name': row[5] as String,
      'code_v2': row[6] as String,
    });
  }
  return jsonEncode({
    'verses': [
      for (final MapEntry(:key, :value) in verses.entries)
        {'verse_key': key, 'words': value},
    ],
  });
}();

http.Response _json(Object body) => http.Response.bytes(
  utf8.encode(body is String ? body : jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json'},
);

QfDebugMushafSource _source() => QfDebugMushafSource(
  client: MockClient((request) async {
    final path = request.url.path;
    if (path.contains('/verses/by_page/')) return _json(_byPageBody);
    if (path.endsWith('/chapters')) {
      return _json({
        'chapters': [
          {'id': 1, 'name_arabic': 'الفاتحة'},
          {'id': 2, 'name_arabic': 'البقرة'},
        ],
      });
    }
    if (path.endsWith('.ttf')) return http.Response('font', 200);
    final field = path.split('/').last;
    if (path.contains('/quran/verses/')) {
      return _json({
        'verses': [
          for (var i = 1; i <= 7; i++)
            {
              'verse_key': '1:$i',
              'text_$field': field == 'uthmani'
                  ? 'polos $i'
                  : 'a<tajweed class=ghunnah>b</tajweed>'
                        '<span class=end>$i</span>',
            },
        ],
      });
    }
    return http.Response('not found', 404);
  }),
  // Glyph QCF tidak perlu digambar dengan benar di tes widget.
  registerFont: (_, _) async {},
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pump();
}

Future<List<Object?>> _pump(
  WidgetTester tester, {
  int page = 1,
  ReaderLayout layout = ReaderLayout.single,
  Size size = const Size(430, 900),
}) async {
  final orientations = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientations.add(call.arguments);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: SacredTheme.light,
      home: DebugReaderPrototypeScreen(
        source: _source(),
        initialPage: page,
        initialLayout: layout,
      ),
    ),
  );
  await _settle(tester);
  return orientations;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
  });

  testWidgets('satu halaman: judul surah, header kecil, toolbar ayat', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('سُورَةُ الفاتحة'), findsOneWidget);
    // Label Juz tidak diuji di sini: rootBundle meng-cache future aset dari
    // zona fake-async tes sebelumnya sehingga urutan tes memengaruhinya.
    expect(
      find.textContaining(RegExp(r'^Al-Fatihah · .*Hal\. 1$')),
      findsOneWidget,
    );

    // Ketuk salah satu kata ayat 1:2 (kata pertama baris ke-2 teks).
    final words = find.descendant(
      of: find.byType(InteractiveViewer),
      matching: find.byType(GestureDetector),
    );
    await tester.tap(words.at(6), warnIfMissed: false);
    await tester.pump();
    expect(find.textContaining('Al-Fatihah · Ayat'), findsOneWidget);

    await tester.tap(find.byTooltip('Simpan bookmark'));
    await tester.pump();
    expect(find.byTooltip('Hapus bookmark'), findsOneWidget);
    expect(SharedPreferencesService.getBookmarks(), isNotEmpty);

    await tester.tap(find.byTooltip('Tutup'));
    await tester.pump();
    expect(find.textContaining('Al-Fatihah · Ayat'), findsNothing);
  });

  testWidgets('halaman dengan data layout tidak konsisten tidak ditebak', (
    tester,
  ) async {
    await _pump(tester, page: 589);

    expect(find.textContaining('tidak konsisten'), findsOneWidget);
    expect(find.textContaining('84:21'), findsOneWidget);
    expect(find.text('Coba lagi'), findsNothing);
  });

  testWidgets(
    'dua halaman: ganjil di kanan, landscape dipulihkan saat keluar',
    (tester) async {
      final orientations = await _pump(
        tester,
        layout: ReaderLayout.spread,
        size: const Size(1280, 720),
      );

      expect(orientations.single, [
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
      final right = tester.getCenter(find.textContaining('Hal. 1'));
      final left = tester.getCenter(find.textContaining('Hal. 2'));
      expect(right.dx, greaterThan(left.dx));

      await tester.pumpWidget(const SizedBox());
      expect(orientations.last, isEmpty);
    },
  );

  testWidgets('layar sempit menawarkan satu halaman, bukan teks kekecilan', (
    tester,
  ) async {
    final orientations = await _pump(
      tester,
      layout: ReaderLayout.spread,
      size: const Size(400, 800),
    );

    expect(find.text('Pakai satu halaman'), findsOneWidget);
    await tester.tap(find.text('Pakai satu halaman'));
    await _settle(tester);

    expect(orientations.last, isEmpty);
    // Label Juz tidak diuji di sini: rootBundle meng-cache future aset dari
    // zona fake-async tes sebelumnya sehingga urutan tes memengaruhinya.
    expect(
      find.textContaining(RegExp(r'^Al-Fatihah · .*Hal\. 1$')),
      findsOneWidget,
    );
  });

  testWidgets(
    'mode card: ayat halaman yang sama dengan tajwid dan terjemahan',
    (tester) async {
      await _pump(tester, layout: ReaderLayout.card);

      expect(find.text('1:1'), findsOneWidget);
      expect(find.text('Ghunnah ×1'), findsWidgets);
      expect(find.textContaining('edisi Quran Foundation'), findsOneWidget);
    },
  );
}
