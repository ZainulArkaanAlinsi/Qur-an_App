import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/hafalan/domain/murajaah_schedule.dart';

void main() {
  final today = DateTime(2026, 9, 23);

  group('tangga jarak ulang', () {
    test('lancar menaiki satu anak tangga', () {
      var interval = MurajaahSchedule.firstInterval;
      final climbed = <int>[interval];
      for (var i = 0; i < 5; i++) {
        interval = MurajaahSchedule.nextInterval(
          interval,
          ReviewOutcome.lancar,
        );
        climbed.add(interval);
      }
      // Naik 1 → 3 → 7 → 14 → 30 lalu berhenti di puncak, tidak terus membesar.
      expect(climbed, [1, 3, 7, 14, 30, 30]);
    });

    test('ragu menahan jarak yang sama', () {
      expect(MurajaahSchedule.nextInterval(7, ReviewOutcome.ragu), 7);
      expect(MurajaahSchedule.nextInterval(30, ReviewOutcome.ragu), 30);
    });

    test('salah kembali ke jarak terpendek', () {
      for (final interval in MurajaahSchedule.ladder) {
        expect(
          MurajaahSchedule.nextInterval(interval, ReviewOutcome.salah),
          1,
          reason: 'dari $interval hari',
        );
      }
    });

    test('nilai di luar tangga ditarik ke anak tangga terdekat', () {
      // Data lama atau hasil suntingan tidak boleh menjatuhkan jadwalnya.
      expect(MurajaahSchedule.nextInterval(10, ReviewOutcome.lancar), 14);
      expect(MurajaahSchedule.nextInterval(0, ReviewOutcome.lancar), 3);
      expect(MurajaahSchedule.nextInterval(-5, ReviewOutcome.ragu), 1);
      expect(MurajaahSchedule.nextInterval(999, ReviewOutcome.lancar), 30);
    });

    test('tiap hasil punya penjelasan yang bisa dibaca pengguna', () {
      for (final outcome in ReviewOutcome.values) {
        expect(outcome.label, isNotEmpty);
        expect(outcome.effect, isNotEmpty);
      }
      expect(MurajaahSchedule.explain(1), 'Diulang besok.');
      expect(MurajaahSchedule.explain(7), 'Diulang sepekan lagi.');
      expect(MurajaahSchedule.explain(14), 'Diulang dua pekan lagi.');
      expect(MurajaahSchedule.explain(30), 'Diulang 30 hari lagi.');
    });
  });

  group('jatuh tempo', () {
    test('ayat baru dihafal diulang besok', () {
      final fresh = AyahMemorization.fresh(surah: 78, ayah: 1, today: today);
      expect(fresh.interval, 1);
      expect(fresh.dueOn, DateTime(2026, 9, 24));
      expect(fresh.isDue(today), isFalse);
      expect(fresh.isDue(DateTime(2026, 9, 24)), isTrue);
    });

    test('yang terlewat tetap terhitung jatuh tempo', () {
      final overdue = AyahMemorization(
        surah: 78,
        ayah: 2,
        interval: 3,
        dueOn: DateTime(2026, 9, 1),
      );
      expect(overdue.isDue(today), isTrue);
    });

    test('jam berapa pun hari itu tidak menggeser jatuh tempo', () {
      final fresh = AyahMemorization.fresh(surah: 1, ayah: 1, today: today);
      // Ditandai menjelang tengah malam; jatuh temponya tetap tanggal 24.
      final malam = AyahMemorization.fresh(
        surah: 1,
        ayah: 1,
        today: DateTime(2026, 9, 23, 23, 59),
      );
      expect(malam.dueOn, fresh.dueOn);
    });

    test('pergantian bulan dihitung benar', () {
      final akhirBulan = AyahMemorization(
        surah: 1,
        ayah: 1,
        interval: 7,
        dueOn: DateTime(2026, 9, 28),
      );
      final next = akhirBulan.reviewed(
        ReviewOutcome.lancar,
        DateTime(2026, 9, 28),
      );
      expect(next.interval, 14);
      expect(next.dueOn, DateTime(2026, 10, 12));
    });

    test('antrean menaruh yang paling lama terlewat di depan', () {
      final all = [
        AyahMemorization(
          surah: 78,
          ayah: 5,
          interval: 1,
          dueOn: DateTime(2026, 9, 23),
        ),
        AyahMemorization(
          surah: 114,
          ayah: 1,
          interval: 3,
          dueOn: DateTime(2026, 9, 20),
        ),
        AyahMemorization(
          surah: 1,
          ayah: 1,
          interval: 30,
          dueOn: DateTime(2026, 10, 1),
        ),
      ];
      final due = dueForReview(all, today);
      expect(due.map((item) => item.verseKey), ['114:1', '78:5']);
    });
  });

  group('penyimpanan', () {
    test('bolak-balik JSON mempertahankan jadwalnya', () {
      final item = AyahMemorization(
        surah: 78,
        ayah: 3,
        interval: 7,
        dueOn: DateTime(2026, 9, 30),
      );
      final json = item.toJson();
      expect(json, {'i': 7, 'd': '2026-09-30'});
      expect(AyahMemorization.fromJson(78, 3, json), item);
    });

    test('entri rusak dilewati, bukan ditebak jadwalnya', () {
      expect(AyahMemorization.fromJson(78, 3, {'d': '2026-09-30'}), isNull);
      expect(AyahMemorization.fromJson(78, 3, {'i': 7}), isNull);
      expect(
        AyahMemorization.fromJson(78, 3, {'i': 7, 'd': '30 September'}),
        isNull,
      );
      expect(
        AyahMemorization.fromJson(78, 3, {'i': 0, 'd': '2026-09-30'}),
        isNull,
      );
      expect(
        AyahMemorization.fromJson(78, 3, {'i': '7', 'd': '2026-09-30'}),
        isNull,
      );
    });

    test('tanggal ditulis dengan nol di depan', () {
      expect(AyahMemorization.formatDate(DateTime(2026, 1, 5)), '2026-01-05');
      expect(AyahMemorization.parseDate('2026-01-05'), DateTime(2026, 1, 5));
    });
  });
}
