import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/reading_session_store.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

ReadingSession _session(String id, String date, int seconds, {String? verse}) =>
    ReadingSession(
      id: id,
      deviceId: 'device-a',
      startedAtUtc: DateTime.utc(2026, 5, 4, 1),
      endedAtUtc: null,
      activeSeconds: seconds,
      timezone: 'Asia/Jakarta',
      localDate: date,
      lastVerseKey: verse,
    );

Future<ReadingSessionStore> _fresh([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  await SharedPreferencesService.init();
  return ReadingSessionStore(await SharedPreferences.getInstance());
}

void main() {
  test('menyimpan sesi yang sama berulang tidak membuat menit dobel', () async {
    final store = await _fresh();
    final session = _session('s1', '2026-05-04', 120);
    await store.save(session);
    await store.save(session);
    await store.save(session.copyWith(activeSeconds: 180));
    expect(store.forDate('2026-05-04'), hasLength(1));
    expect(SharedPreferencesService.getReadingSeconds('2026-05-04'), 180);
  });

  test('total harian = total lama + jumlah sesi hari itu', () async {
    final store = await _fresh({'reading_seconds_2026-05-04': 200});
    await store.save(_session('s1', '2026-05-04', 60));
    await store.save(_session('s2', '2026-05-04', 40));
    await store.save(_session('s3', '2026-05-05', 90));
    expect(store.legacySeconds('2026-05-04'), 200);
    expect(SharedPreferencesService.getReadingSeconds('2026-05-04'), 300);
    expect(SharedPreferencesService.getReadingSeconds('2026-05-05'), 90);
  });

  test('migrasi menjaga riwayat lama dan hanya berjalan sekali', () async {
    final store = await _fresh({
      'reading_seconds_2026-05-01': 300,
      'reading_seconds_2026-05-02': 420,
    });
    await store.migrateLegacyTotals();
    await store.migrateLegacyTotals();
    await store.recompute('2026-05-01');
    await store.recompute('2026-05-02');
    final progress = ReadingProgressService.read(now: DateTime(2026, 5, 2, 20));
    expect(progress.currentStreak, 2);
    expect(progress.totalSeconds, 720);
  });

  test('recompute tidak menimpa total lama yang belum dimigrasi', () async {
    final store = await _fresh({'reading_seconds_2026-05-01': 300});
    await store.recompute('2026-05-01');
    expect(SharedPreferencesService.getReadingSeconds('2026-05-01'), 300);
  });

  test('sesi lintas tengah malam tercatat sebagai dua sesi', () async {
    final store = await _fresh();
    await store.save(_session('before', '2026-05-04', 60));
    await store.save(_session('after', '2026-05-05', 60));
    expect(store.forDate('2026-05-04').single.id, 'before');
    expect(store.forDate('2026-05-05').single.id, 'after');
    expect(store.all(), hasLength(2));
  });

  test('sesi tanpa waktu aktif tidak disimpan', () async {
    final store = await _fresh();
    await store.save(_session('empty', '2026-05-04', 0));
    expect(store.all(), isEmpty);
  });

  test('rekaman rusak dilewati tanpa menggagalkan pembacaan', () async {
    final store = await _fresh({
      'reading_session_2026-05-04_bad': '{bukan json',
    });
    await store.save(_session('good', '2026-05-04', 60, verse: '2:255'));
    final sessions = store.forDate('2026-05-04');
    expect(sessions.single.lastVerseKey, '2:255');
    expect(SharedPreferencesService.getReadingSeconds('2026-05-04'), 60);
  });

  test('sesi bolak-balik JSON tanpa kehilangan field', () {
    final original = _session(
      's1',
      '2026-05-04',
      75,
      verse: '1:7',
    ).copyWith(endedAtUtc: DateTime.utc(2026, 5, 4, 1, 2));
    final restored = ReadingSession.fromJson(original.toJson());
    expect(restored.toJson(), original.toJson());
    expect(restored.syncStatus, 'local');
    expect(restored.mode, 'reading');
  });

  test('ID perangkat stabil setelah dibuat', () async {
    final store = await _fresh();
    final first = await store.deviceId();
    expect(await store.deviceId(), first);
  });

  test('UUID versi 4 unik dan berformat benar', () {
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final ids = {for (var i = 0; i < 500; i++) newUuid()};
    expect(ids, hasLength(500));
    expect(ids.every(pattern.hasMatch), isTrue);
  });

  test('addSeconds mencatat sesi tertutup dengan zona waktu', () async {
    final store = await _fresh();
    await ReadingProgressService.addSeconds('2026-05-04', 90);
    final session = store.forDate('2026-05-04').single;
    expect(session.activeSeconds, 90);
    expect(session.endedAtUtc, isNotNull);
    expect(session.timezone, isNotEmpty);
    expect(session.syncStatus, 'local');
  });
}
