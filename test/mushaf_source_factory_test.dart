// Pemilihan sumber tata letak mushaf (docs/decisions.md, 15 Nov 2026).
//
// Jaminan utama: tanpa alamat BFF, perilaku rilis TIDAK berubah (mode mushaf
// tetap tertutup). Mode itu hanya hidup bila build diberi `BFF_BASE_URL`.
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/core/bff/bff_client.dart';
import 'package:quran_app_2025/features/mushaf/data/bff_mushaf_source.dart';
import 'package:quran_app_2025/features/mushaf/data/mushaf_source_factory.dart';
import 'package:quran_app_2025/features/mushaf/data/qf_debug_mushaf_source.dart';

void main() {
  test('build ini dibuat tanpa BFF_BASE_URL, jadi bawaannya tertutup', () {
    // Tes dijalankan tanpa --dart-define; inilah keadaan rilis hari ini.
    expect(isBffConfigured, isFalse);
    expect(mushafModesAvailable(debugLayout: false), isFalse);
    expect(createMushafSource(debugLayout: false), isNull);
  });

  test('tanpa BFF dan bukan debug: mode mati dan tanpa sumber', () {
    expect(
      mushafModesAvailable(debugLayout: false, bffConfigured: false),
      isFalse,
    );
    expect(
      createMushafSource(debugLayout: false, bffConfigured: false),
      isNull,
    );
  });

  test('BFF dikonfigurasi: mode hidup di rilis lewat BffMushafSource', () {
    expect(
      mushafModesAvailable(debugLayout: false, bffConfigured: true),
      isTrue,
    );
    final source = createMushafSource(debugLayout: false, bffConfigured: true);
    addTearDown(() => source?.dispose());
    expect(source, isA<BffMushafSource>());
  });

  test('tanpa BFF, build debug memakai sumber langsung api.quran.com', () {
    expect(
      mushafModesAvailable(debugLayout: true, bffConfigured: false),
      isTrue,
    );
    final source = createMushafSource(debugLayout: true, bffConfigured: false);
    addTearDown(() => source?.dispose());
    expect(source, isA<QfDebugMushafSource>());
  });

  test('BFF didahulukan atas sumber debug', () {
    final source = createMushafSource(debugLayout: true, bffConfigured: true);
    addTearDown(() => source?.dispose());
    expect(source, isA<BffMushafSource>());
  });
}
