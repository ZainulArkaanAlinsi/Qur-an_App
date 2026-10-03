import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/murottal/application/player_view_model.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

void main() {
  group('PlayerView.of', () {
    test('null bila tidak diputar atau ayat di luar antrean', () {
      final queue = AudioQueue.from(1, 1);
      expect(PlayerView.of(null, '1:1'), isNull);
      expect(PlayerView.of(queue, null), isNull);
      expect(PlayerView.of(queue, '2:1'), isNull);
      expect(PlayerView.of(queue, '1:8'), isNull);
      expect(PlayerView.of(queue, 'rusak'), isNull);
    });

    test('indeks dihitung dari ayat pertama antrean', () {
      final view = PlayerView.of(AudioQueue.from(2, 255, toAyah: 257), '2:256');
      expect(view!.index, 1);
      expect(view.ayah, 256);
      expect(view.total, 3);
      expect(view.isFirst, isFalse);
      expect(view.isLast, isFalse);
    });
  });

  group('label ayat (DATA.md §5.2)', () {
    for (final (queue, key, label) in [
      (AudioQueue.from(1, 1), '1:5', 'Ayat 5 dari 7'),
      (AudioQueue.from(1, 1), '1:1', 'Ayat 1 dari 7'),
      (AudioQueue.from(18, 1, toAyah: 10), '18:3', 'Ayat 3 dari 10'),
      (AudioQueue.from(2, 255, toAyah: 257), '2:256', 'Ayat 256 · 2 dari 3'),
      (AudioQueue.from(67, 12), '67:12', 'Ayat 12 · 1 dari 19'),
    ]) {
      test('$key → $label', () {
        expect(PlayerView.of(queue, key)!.label, label);
      });
    }

    test('pill rentang', () {
      expect(PlayerView.of(AudioQueue.from(1, 1), '1:1')!.rangeLabel, '1–7');
    });
  });

  group('segmen ↔ kontinu', () {
    test('40 ayat masih segmen, 41 kontinu', () {
      final forty = PlayerView.of(AudioQueue.from(2, 1, toAyah: 40), '2:1')!;
      final fortyOne = PlayerView.of(AudioQueue.from(2, 1, toAyah: 41), '2:1')!;
      expect(forty.segmentMode, isTrue);
      expect(fortyOne.segmentMode, isFalse);
    });

    test('isi tidak pernah > 1 dan tidak negatif', () {
      final segment = PlayerView.of(AudioQueue.from(1, 1), '1:7')!;
      expect(segment.fill(1.4), 1);
      expect(segment.fill(-.2), 0);
      expect(segment.fill(.25), .25);

      final long = PlayerView.of(AudioQueue.from(2, 1), '2:286')!;
      expect(long.segmentMode, isFalse);
      expect(long.fill(2), 1);
      expect(long.fill(0), closeTo(285 / 286, 1e-9));
      expect(PlayerView.continuousFill(0, 0, .5), 0);
    });
  });

  group('teks waktu', () {
    test('posisi / durasi', () {
      expect(
        PlayerView.timeLabel(
          const Duration(milliseconds: 1400),
          const Duration(seconds: 6),
        ),
        '0:01 / 0:06',
      );
      expect(
        PlayerView.timeLabel(
          const Duration(seconds: 75),
          const Duration(minutes: 2, seconds: 3),
        ),
        '1:15 / 2:03',
      );
    });

    test('durasi belum diketahui; posisi tidak melewati durasi', () {
      expect(PlayerView.timeLabel(Duration.zero, null), '0:00 / –:––');
      expect(
        PlayerView.timeLabel(
          const Duration(seconds: 9),
          const Duration(seconds: 6),
        ),
        '0:06 / 0:06',
      );
      expect(PlayerView.fractionOf(const Duration(seconds: 3), null), 0);
      expect(
        PlayerView.fractionOf(
          const Duration(seconds: 9),
          const Duration(seconds: 6),
        ),
        1,
      );
    });

    test('jam timer', () {
      expect(PlayerView.clockOfDay(DateTime(2026, 10, 2, 9, 5)), '09:05');
    });
  });

  group('tombol', () {
    test('kecepatan: 0.75 → 1 → 1.25 → 1.5 → 0.75', () {
      expect(PlayerView.nextSpeed(.75), 1);
      expect(PlayerView.nextSpeed(1), 1.25);
      expect(PlayerView.nextSpeed(1.25), 1.5);
      expect(PlayerView.nextSpeed(1.5), .75);
      expect(PlayerView.speedLabel(1), '1×');
      expect(PlayerView.speedLabel(1.25), '1.25×');
      expect(PlayerView.speedLabel(1.5), '1.5×');
      expect(PlayerView.speedLabel(.75), '0.75×');
    });

    test('ulang: mati → ayat → rentang (bila ada) → mati', () {
      expect(
        PlayerView.nextRepeat(AudioRepeat.off, hasRange: true),
        AudioRepeat.verse,
      );
      expect(
        PlayerView.nextRepeat(AudioRepeat.verse, hasRange: true),
        AudioRepeat.range,
      );
      expect(
        PlayerView.nextRepeat(AudioRepeat.verse, hasRange: false),
        AudioRepeat.off,
      );
      expect(
        PlayerView.nextRepeat(AudioRepeat.range, hasRange: true),
        AudioRepeat.off,
      );
    });
  });
}
