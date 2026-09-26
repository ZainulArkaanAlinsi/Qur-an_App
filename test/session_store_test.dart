import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/features/session/data/session_store.dart';
import 'package:quran_app_2025/features/session/domain/session_plan.dart';
import 'package:quran_app_2025/features/session/domain/verse_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan lokal Sesi hari ini (docs/design/v5-sesi-harian/SESI_HARIAN.md §5).
void main() {
  late Directory documents;
  late SessionStore store;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    documents = Directory.systemTemp.createTempSync('sesi_');
    store = SessionStore(prefs, documents: () async => documents);
  });

  tearDown(() {
    if (documents.existsSync()) documents.deleteSync(recursive: true);
  });

  group('sesi.hari.<tanggal>', () {
    test('simpan, muat, dan kunci sesuai §5', () async {
      const session = DailySession(
        date: '2026-09-26',
        step: SessionStep.findInVerse,
        lessonId: 'tanwin',
        verse: VerseChoice(surah: 112, ayah: 1, words: [4]),
      );
      await store.saveDay(session);
      expect(prefs.getString('sesi.hari.2026-09-26'), isNotNull);
      expect(store.day('2026-09-26')?.toJson(), session.toJson());
      expect(store.day('2026-09-25'), isNull);
    });

    test('entri rusak dianggap tidak ada', () async {
      await prefs.setString('sesi.hari.2026-09-26', '{rusak');
      expect(store.day('2026-09-26'), isNull);
      await prefs.setString(
        'sesi.hari.2026-09-26',
        '{"tanggal":"2026-09-20","langkah":"done","selesai":true}',
      );
      expect(store.day('2026-09-26'), isNull);
    });

    test('tanggal selesai hanya dari sesi yang selesai', () async {
      await store.saveDay(
        const DailySession(date: '2026-09-24', step: SessionStep.done),
      );
      await store.saveDay(
        const DailySession(
          date: '2026-09-25',
          step: SessionStep.done,
          completed: true,
        ),
      );
      await prefs.setString('sesi.hari.2026-09-23', 'bukan json');
      expect(store.completedDates(), {'2026-09-25'});
      expect(store.completedCount(), 1);
      expect(SessionStore.completedDatesIn(prefs), {'2026-09-25'});
      expect(SessionStore.completedDatesIn(null), isEmpty);
    });

    test('tanggal dari cloud tidak menimpa sesi lokal', () async {
      await store.saveDay(
        const DailySession(
          date: '2026-09-25',
          step: SessionStep.listenRepeat,
          lessonId: 'tanwin',
        ),
      );
      await store.addCompletedDates(['2026-09-24', '2026-09-25', 'x']);
      expect(store.completedDates(), {'2026-09-24', '2026-09-25'});
      expect(store.day('2026-09-25')?.lessonId, 'tanwin');
    });
  });

  test('sesi.riwayatAyat: 60 terakhir, tanpa ganda', () async {
    for (var i = 1; i <= 70; i++) {
      await store.rememberVerse('78:$i');
    }
    await store.rememberVerse('78:20');
    final history = store.verseHistory();
    expect(history, hasLength(SessionStore.verseHistoryLimit));
    expect(history.last, '78:20');
    expect(history.where((key) => key == '78:20'), hasLength(1));
    expect(history.first, '78:11');
  });

  test('sesi.nilaiDiri: 90 hari, satu per ayat per hari', () async {
    await store.addRating(
      const RatingEntry(
        date: '2026-06-01',
        verseKey: '112:1',
        rating: SelfRating.beda,
      ),
    );
    await store.addRating(
      const RatingEntry(
        date: '2026-09-25',
        verseKey: '112:1',
        rating: SelfRating.beda,
      ),
    );
    await store.addRating(
      const RatingEntry(
        date: '2026-09-25',
        verseKey: '112:1',
        rating: SelfRating.mirip,
      ),
    );
    await store.addRating(
      const RatingEntry(
        date: '2026-09-26',
        verseKey: '113:1',
        rating: SelfRating.mirip,
      ),
    );
    final ratings = store.ratings();
    expect(
      [for (final item in ratings) '${item.date} ${item.rating.name}'],
      ['2026-09-25 mirip', '2026-09-26 mirip'],
    );
  });

  group('rekaman', () {
    Future<File> write(String name) async {
      final directory = await store.recordingsDirectory();
      return File('${directory.path}${Platform.pathSeparator}$name')
        ..writeAsBytesSync([1, 2, 3]);
    }

    test(
      'berkas <documents>/rekaman_sesi/<surah>_<ayah>_<tanggal>.m4a',
      () async {
        final file = await store.recordingFile(112, 1, '2026-09-26');
        expect(
          file.path,
          '${documents.path}${Platform.pathSeparator}rekaman_sesi'
          '${Platform.pathSeparator}112_1_2026-09-26.m4a',
        );
      },
    );

    test('lebih dari 30 hari dihapus, kecuali disematkan', () async {
      final old = await write('112_1_2026-08-01.m4a');
      final edge = await write('112_2_2026-08-27.m4a');
      final pinned = await write('113_1_2026-07-01.m4a');
      final fresh = await write('114_1_2026-09-25.m4a');
      final other = await write('catatan.txt');
      await store.setPinned('113_1_2026-07-01.m4a', true);

      final removed = await store.cleanRecordings(today: '2026-09-26');
      expect(removed, 1);
      expect(old.existsSync(), isFalse);
      expect(edge.existsSync(), isTrue); // tepat 30 hari
      expect(pinned.existsSync(), isTrue);
      expect(fresh.existsSync(), isTrue);
      expect(other.existsSync(), isTrue);
      expect(
        [
          for (final file in await store.recordings())
            SessionStore.fileName(file),
        ],
        [
          '114_1_2026-09-25.m4a',
          '112_2_2026-08-27.m4a',
          '113_1_2026-07-01.m4a',
        ],
      );
    });

    test('hapus satu dan hapus semua', () async {
      final one = await write('112_1_2026-09-26.m4a');
      await write('113_1_2026-09-26.m4a');
      await store.setPinned('112_1_2026-09-26.m4a', true);
      await store.deleteRecording(one);
      expect(one.existsSync(), isFalse);
      expect(store.pinned(), isEmpty);

      await store.setPinned('113_1_2026-09-26.m4a', true);
      await store.deleteAllRecordings();
      expect(await store.recordings(), isEmpty);
      expect(prefs.getStringList(SessionStore.pinnedKey), isNull);
    });
  });
}
