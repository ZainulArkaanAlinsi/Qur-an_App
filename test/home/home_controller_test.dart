import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/home/application/home_controller.dart';
import 'package:quran_app_2025/features/home/domain/home_snapshot.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
  });

  group('kunci murajaah.selesai.<tanggal> (DATA §4)', () {
    test('menambah hitungan hari ini', () async {
      final today = DateTime(2026, 10, 2, 9);
      expect(SharedPreferencesService.getMurajaahDone(today), 0);
      await SharedPreferencesService.addMurajaahDone(today);
      await SharedPreferencesService.addMurajaahDone(today);
      expect(SharedPreferencesService.getMurajaahDone(today), 2);
      expect(
        SharedPreferencesService.getMurajaahDone(DateTime(2026, 10, 1)),
        0,
      );
    });

    test('kunci lebih tua dari 14 hari dibersihkan saat menulis', () async {
      SharedPreferences.setMockInitialValues({
        'murajaah.selesai.2026-09-17': 4, // 15 hari lalu → dihapus
        'murajaah.selesai.2026-09-18': 3, // 14 hari lalu → disimpan
        'murajaah.selesai.2026-10-01': 1,
        'palette': 'sepia',
      });
      await SharedPreferencesService.init();
      await SharedPreferencesService.addMurajaahDone(DateTime(2026, 10, 2));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('murajaah.selesai.2026-09-17'), isFalse);
      expect(prefs.getInt('murajaah.selesai.2026-09-18'), 3);
      expect(prefs.getInt('murajaah.selesai.2026-10-01'), 1);
      expect(prefs.getInt('murajaah.selesai.2026-10-02'), 1);
      expect(prefs.getString('palette'), 'sepia');
    });

    test('staleMurajaahKeys mengabaikan kunci lain dan tanggal rusak', () {
      expect(
        SharedPreferencesService.staleMurajaahKeys([
          'murajaah.selesai.2026-01-01',
          'murajaah.selesai.bukan-tanggal',
          'sesi.hari.2026-01-01',
        ], DateTime(2026, 10, 2)),
        ['murajaah.selesai.2026-01-01'],
      );
    });
  });

  test('kunci baru Beranda/Murottal tidak ikut sinkron cloud (DATA §4)', () {
    // Sinkron hanya memanggil metode bernama di SharedPreferencesService;
    // kunci lokal baru tidak boleh muncul di berkas sinkron.
    for (final path in [
      'lib/services/firebase_sync.dart',
      'lib/services/cloud_sync_service.dart',
    ]) {
      final source = File(path).readAsStringSync();
      for (final key in [
        'murajaah.selesai',
        'getMurajaahDone',
        'murottal.tampilan',
        'murottal.terjemahan',
      ]) {
        expect(source, isNot(contains(key)), reason: '$path memuat $key');
      }
      expect(source, isNot(contains('getKeys(')), reason: path);
    }
  });

  testWidgets('ganti tanggal saat aplikasi terbuka → snapshot dihitung ulang', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 2, 23, 59, 50);
    final controller = HomeController(
      clock: () => now,
      loadPrayer: (_) async => null,
      loadCurriculum: () => Future.error(StateError('tanpa kurikulum')),
      loadPages: () async => const [],
    );
    await controller.start();
    expect(controller.snapshot.now.day, 2);
    expect(controller.snapshot.prayerStatus, PrayerStatus.luring);

    var notified = 0;
    controller.addListener(() => notified++);
    // Timer ke 00:00:05 berikutnya: 15 detik dari 23:59:50.
    now = DateTime(2026, 10, 3, 0, 0, 6);
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(controller.snapshot.now.day, 3);
    expect(notified, greaterThan(0));
    // Timer tengah malam harus berhenti sebelum tes selesai.
    controller.dispose();
  });

  testWidgets('tanpa materi: sesi tidak tersedia; murajaah hari ini terbaca', (
    tester,
  ) async {
    final today = DateTime(2026, 10, 2, 9);
    await SharedPreferencesService.addMurajaahDone(today);
    final controller = HomeController(
      clock: () => today,
      loadPrayer: (_) async => null,
      loadCurriculum: () => Future.error(StateError('tanpa kurikulum')),
      loadPages: () async => const [],
    );
    await controller.start();
    expect(controller.snapshot.sessionAvailable, isFalse);
    expect(controller.snapshot.murajaahDoneToday, 1);
    expect(controller.snapshot.lastRead, isNull);
    controller.dispose();
  });
}
