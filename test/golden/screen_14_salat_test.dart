import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/screens/prayer_screen.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

final _date = DateTime(2026, 9, 24);

PrayerDay _day(DateTime date, {bool fromCache = false}) => PrayerDay(
  gregorianDate: date,
  hijriDate: '12 Rabiulakhir 1448',
  hijriMonth: 'Rabiulakhir',
  prayers: const {
    'Subuh': '04:24',
    'Dzuhur': '11:45',
    'Ashar': '14:54',
    'Maghrib': '17:48',
    'Isya': '18:57',
  },
  sunrise: '05:42',
  sunset: '17:48',
  fromCache: fromCache,
);

Future<void> _prepare(WidgetTester tester) => tester.runAsync(() async {
  SharedPreferences.setMockInitialValues({
    'prayer_reminders': PrayerService.prayerNames,
  });
  await SharedPreferencesService.init();
});

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  for (final variant in GoldenVariant.all) {
    testWidgets('14 salat · ${variant.suffix}', (tester) async {
      await _prepare(tester);
      await pumpGolden(
        tester,
        PrayerScreen(
          loader: (date) async => _day(date ?? _date),
          clock: () => DateTime(2026, 9, 24, 9, 21),
          scheduler: (_, _, _, _) async => true,
        ),
        variant: variant,
      );
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('MENUJU DZUHUR'), findsOneWidget);
      expect(find.text('2 j 24 m'), findsOneWidget);
      expect(find.text('Terbenam 17:48'), findsOneWidget);
      // Nama waktu salat tidak boleh terpotong, termasuk "Maghrib".
      expectNotTruncated(tester, [
        ...PrayerService.prayerNames,
        'Salat',
        'Kiblat',
        'Ganti kota',
        'Pengingat tilawah',
      ]);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/14_salat_${variant.suffix}.png'),
      );
    });
  }

  group('perilaku', () {
    Future<void> open(
      WidgetTester tester, {
      required Future<PrayerDay> Function(DateTime? date) loader,
      DateTime? now,
      ReminderScheduler? scheduler,
    }) async {
      await _prepare(tester);
      await pumpGolden(
        tester,
        PrayerScreen(
          loader: loader,
          clock: () => now ?? DateTime(2026, 9, 24, 9, 21),
          scheduler: scheduler ?? (_, _, _, _) async => true,
        ),
      );
      await _settle(tester);
    }

    testWidgets('izin notifikasi ditolak: toggle kembali, ada penjelasan', (
      tester,
    ) async {
      await open(
        tester,
        loader: (date) async => _day(date ?? _date),
        scheduler: (_, _, _, _) async => false,
      );
      await tester.tap(find.bySemanticsLabel('Pengingat Subuh'));
      await _settle(tester);
      await tester.scrollUntilVisible(
        find.textContaining('Izin notifikasi belum diberikan'),
        200,
      );
      expect(find.textContaining('Izin notifikasi belum diberikan'), findsOne);
      expect(
        SharedPreferencesService.getPrayerReminders(),
        containsAll(PrayerService.prayerNames),
      );
    });

    testWidgets('mematikan satu pengingat tersimpan', (tester) async {
      await open(tester, loader: (date) async => _day(date ?? _date));
      await tester.tap(find.bySemanticsLabel('Pengingat Ashar'));
      await _settle(tester);
      expect(
        SharedPreferencesService.getPrayerReminders(),
        isNot(contains('Ashar')),
      );
    });

    testWidgets('gagal memuat: Ganti kota tetap ada, Coba lagi memuat ulang', (
      tester,
    ) async {
      var fail = true;
      await open(
        tester,
        loader: (date) async {
          if (fail) throw Exception('luring');
          return _day(date ?? _date);
        },
      );
      expect(find.textContaining('belum bisa dimuat'), findsOne);
      expect(find.text('Ganti kota'), findsOne);

      fail = false;
      await tester.tap(find.text('Coba lagi'));
      await _settle(tester);
      expect(find.text('MENUJU DZUHUR'), findsOne);
    });

    testWidgets('setelah Isya menghitung mundur ke Subuh besok', (
      tester,
    ) async {
      final asked = <DateTime?>[];
      await open(
        tester,
        now: DateTime(2026, 9, 24, 20),
        loader: (date) async {
          asked.add(date);
          return _day(date ?? _date);
        },
      );
      await _settle(tester);
      expect(asked, contains(DateTime(2026, 9, 25)));
      expect(find.text('MENUJU SUBUH BESOK'), findsOne);
      expect(find.text('8 j 24 m'), findsOne);
      // Malam: tidak ada baris hari ini yang disorot sebagai berikutnya.
      expect(find.text('berikutnya'), findsNothing);
    });

    testWidgets('jadwal dari simpanan diberi tahu', (tester) async {
      await open(
        tester,
        loader: (date) async => _day(date ?? _date, fromCache: true),
      );
      expect(find.textContaining('Sedang luring'), findsOne);
    });

    testWidgets('Ganti kota: Simpan nonaktif bila kosong', (tester) async {
      await open(tester, loader: (date) async => _day(date ?? _date));
      await tester.tap(find.text('Ganti kota'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      await tester.tap(find.text('Simpan'), warnIfMissed: false);
      await tester.pumpAndSettle();
      // Lembar masih terbuka dan kota tidak berubah.
      expect(find.text('Lokasi jadwal salat'), findsOne);
      expect(SharedPreferencesService.getPrayerCity(), 'Jakarta');

      await tester.enterText(find.byType(TextField).first, 'Bandung');
      await tester.pump();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(SharedPreferencesService.getPrayerCity(), 'Bandung');
      expect(find.text('Bandung'), findsOne);
    });
  });
}
