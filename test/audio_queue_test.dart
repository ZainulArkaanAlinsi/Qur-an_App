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
}
