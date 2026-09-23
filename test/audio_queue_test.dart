import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

void main() {
  test('antrean berurutan berjalan sampai akhir surah', () {
    final queue = AudioQueue.from(1, 3);
    expect(queue.firstAyah, 3);
    expect(queue.lastAyah, 7);
    expect(queue.length, 5);
    expect(queue.keyAt(0), '1:3');
    expect(queue.keyAt(4), '1:7');
  });

  test('antrean rentang memetakan indeks player ke verseKey', () {
    final queue = AudioQueue.from(2, 255, toAyah: 257);
    expect(queue.length, 3);
    expect(
      [for (var i = 0; i < queue.length; i++) queue.keyAt(i)],
      ['2:255', '2:256', '2:257'],
    );
  });

  test('indeks di luar playlist tidak menghasilkan ayat palsu', () {
    final queue = AudioQueue.from(114, 5);
    expect(queue.ayahAt(-1), 5);
    expect(queue.ayahAt(9), 6);
  });

  test('rentang tidak valid ditolak', () {
    expect(() => AudioQueue.from(1, 0), throwsRangeError);
    expect(() => AudioQueue.from(1, 8), throwsRangeError);
    expect(() => AudioQueue.from(1, 5, toAyah: 4), throwsRangeError);
    expect(() => AudioQueue.from(1, 5, toAyah: 8), throwsRangeError);
  });

  test('URL audio memakai nomor global ayat', () {
    expect(
      QuranAudioService.urlFor(2, 255).toString(),
      'https://cdn.islamic.network/quran/audio/128/ar.alafasy/262.mp3',
    );
  });

  group('jumlah pengulangan rentang', () {
    // Bug lama: berapa pun angkanya selalu jadi LoopMode.all, jadi 3×, 5×,
    // 10×, dan "tanpa batas" berperilaku sama — tidak pernah berhenti.
    test('3×, 5×, dan 10× menghasilkan target yang berbeda', () {
      final targets = [
        for (final count in [3, 5, 10])
          RangePlan.of(length: 5, repeatCount: count).passTarget,
      ];
      expect(targets, [3, 5, 10]);
      for (final count in [3, 5, 10]) {
        expect(
          RangePlan.of(length: 5, repeatCount: count).mode,
          AudioRepeat.range,
          reason: 'pengulangan $count×',
        );
      }
    });

    test('tanpa batas tidak punya target', () {
      final plan = RangePlan.of(length: 5, repeatCount: null);
      expect(plan.passTarget, isNull);
      expect(plan.mode, AudioRepeat.range);
    });

    // Bug lama: 1× keluar dari mode rentang lalu memuat ulang sampai ayat
    // terakhir surah, padahal tombolnya menjanjikan "Putar ayat 3–7".
    test('1× tidak mengulang dan tidak melewati rentangnya', () {
      final plan = RangePlan.of(length: 5, repeatCount: 1);
      expect(plan.mode, AudioRepeat.off);
      expect(plan.copies, 1);
      expect(plan.passTarget, 1);
      expect(plan.items(5), 5);
    });

    test('rentang satu ayat digandakan karena indeksnya tidak berpindah', () {
      final plan = RangePlan.of(length: 1, repeatCount: 4);
      expect(plan.copies, 4);
      expect(plan.mode, AudioRepeat.off);
      expect(plan.items(1), 4);
    });

    test('angka tidak masuk akal diperlakukan sebagai sekali jalan', () {
      for (final count in [0, -3]) {
        final plan = RangePlan.of(length: 5, repeatCount: count);
        expect(plan.passTarget, 1, reason: 'pengulangan $count');
        expect(plan.mode, AudioRepeat.off);
      }
    });

    test('rentang panjang tetap satu salinan, jadi tidak membengkak', () {
      // Al-Baqarah penuh, diulang 10×: 2.860 berkas kalau digandakan.
      final plan = RangePlan.of(length: 286, repeatCount: 10);
      expect(plan.copies, 1);
      expect(plan.items(286), 286);
      expect(plan.passTarget, 10);
    });
  });
}
