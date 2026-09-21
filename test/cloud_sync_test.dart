import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/services/cloud_sync_service.dart';
import 'package:quran_app_2025/services/reading_session_store.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for Firestore with a monotonic server clock.
class FakeRemote implements SyncRemote {
  final sessions = <String, Map<String, (ReadingSession, int)>>{};
  final bookmarks = <String, Map<String, (BookmarkRecord, int)>>{};
  int clock = 1000;
  int sessionPushes = 0;
  bool fail = false;

  void _check() {
    if (fail) throw StateError('offline');
  }

  @override
  Future<void> pushSessions(String uid, List<ReadingSession> items) async {
    _check();
    sessionPushes += items.length;
    for (final s in items) {
      (sessions[uid] ??= {})[s.id] = (s, ++clock);
    }
  }

  @override
  Future<RemotePage<ReadingSession>> pullSessions(String uid, int since) async {
    _check();
    final all = (sessions[uid] ?? {}).values.where((e) => e.$2 > since);
    return RemotePage([
      for (final e in all) e.$1,
    ], all.fold<int>(since, (m, e) => e.$2 > m ? e.$2 : m));
  }

  @override
  Future<void> pushBookmarks(String uid, List<BookmarkRecord> items) async {
    _check();
    for (final b in items) {
      (bookmarks[uid] ??= {})[b.id] = (b, ++clock);
    }
  }

  @override
  Future<RemotePage<BookmarkRecord>> pullBookmarks(
    String uid,
    int since,
  ) async {
    _check();
    final all = (bookmarks[uid] ?? {}).values.where((e) => e.$2 > since);
    return RemotePage([
      for (final e in all) e.$1,
    ], all.fold<int>(since, (m, e) => e.$2 > m ? e.$2 : m));
  }

  @override
  Future<void> deleteAll(String uid) async {
    _check();
    sessions.remove(uid);
    bookmarks.remove(uid);
  }
}

ReadingSession _session(
  String id, {
  String device = 'this-phone',
  String date = '2026-05-04',
  int seconds = 300,
  DateTime? start,
  String status = 'local',
}) {
  final begin = start ?? DateTime.utc(2026, 5, 4, 1);
  return ReadingSession(
    id: id,
    deviceId: device,
    startedAtUtc: begin,
    endedAtUtc: begin.add(Duration(seconds: seconds)),
    activeSeconds: seconds,
    timezone: 'Asia/Jakarta',
    localDate: date,
    syncStatus: status,
  );
}

Future<ReadingSessionStore> _fresh([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  await SharedPreferencesService.init();
  return ReadingSessionStore(await SharedPreferences.getInstance());
}

void main() {
  test('sesi tamu terunggah sekali lalu ditandai tersinkron', () async {
    final store = await _fresh();
    final remote = FakeRemote();
    final sync = CloudSyncService(remote);
    await store.save(_session('a'));

    await sync.sync('user-1');
    expect(remote.sessions['user-1']!.keys, ['a']);
    expect(store.forDate('2026-05-04').single.syncStatus, 'synced');
    expect(sync.state.value, SyncState.done);

    await sync.sync('user-1');
    expect(remote.sessionPushes, 1, reason: 'outbox kosong setelah sukses');
  });

  test('sesi terbuka tidak diunggah sebelum ditutup', () async {
    final store = await _fresh();
    final remote = FakeRemote();
    final open = ReadingSession(
      id: 'open',
      deviceId: 'this-phone',
      startedAtUtc: DateTime.utc(2026, 5, 4, 1),
      endedAtUtc: null,
      activeSeconds: 60,
      timezone: 'Asia/Jakarta',
      localDate: '2026-05-04',
    );
    await store.save(open);
    await CloudSyncService(remote).sync('user-1');
    expect(remote.sessions['user-1'], isNull);
  });

  test('sesi dari HP lain digabung tanpa menit dobel', () async {
    final store = await _fresh();
    final remote = FakeRemote();
    final sync = CloudSyncService(remote);
    await store.save(_session('mine', seconds: 300));
    // Another phone read 300s, 120s of it at the same time as this phone.
    await remote.pushSessions('user-1', [
      _session(
        'theirs',
        device: 'tablet',
        seconds: 300,
        start: DateTime.utc(2026, 5, 4, 1, 3),
        status: 'synced',
      ),
    ]);

    await sync.sync('user-1');
    expect(store.forDate('2026-05-04'), hasLength(2));
    expect(SharedPreferencesService.getReadingSeconds('2026-05-04'), 480);
  });

  test('gagal jaringan: data lokal utuh dan outbox dicoba lagi', () async {
    final store = await _fresh();
    final remote = FakeRemote()..fail = true;
    final sync = CloudSyncService(remote);
    await store.save(_session('a'));

    await sync.sync('user-1');
    expect(sync.state.value, SyncState.failed);
    expect(sync.message.value, isNotNull);
    expect(store.pendingUpload().single.id, 'a');

    remote.fail = false;
    await sync.sync('user-1');
    expect(remote.sessions['user-1']!.keys, ['a']);
    expect(store.pendingUpload(), isEmpty);
  });

  test('bookmark lokal terunggah; versi server lebih baru menang', () async {
    await _fresh();
    final remote = FakeRemote();
    final sync = CloudSyncService(remote);
    await SharedPreferencesService.saveBookmark(2, 255);

    await sync.sync('user-1');
    expect(remote.bookmarks['user-1']!.keys, ['2_255']);
    expect(SharedPreferencesService.dirtyBookmarks(), isEmpty);

    final future = DateTime.now().millisecondsSinceEpoch + 60000;
    await remote.pushBookmarks('user-1', [
      BookmarkRecord(
        surah: 2,
        ayah: 255,
        collection: 'Hafalan',
        deleted: false,
        updatedAtMs: future,
      ),
      BookmarkRecord(
        surah: 1,
        ayah: 1,
        collection: 'Umum',
        deleted: false,
        updatedAtMs: future,
      ),
    ]);
    await sync.sync('user-1');
    expect(SharedPreferencesService.getBookmarkCollection(2, 255), 'Hafalan');
    expect(SharedPreferencesService.isBookmarked(1, 1), isTrue);
  });

  test('tombstone mencegah bookmark lama hidup kembali', () async {
    await _fresh();
    final remote = FakeRemote();
    final sync = CloudSyncService(remote);
    // An old copy on the server from another phone.
    await remote.pushBookmarks('user-1', [
      const BookmarkRecord(
        surah: 2,
        ayah: 255,
        collection: 'Umum',
        deleted: false,
        updatedAtMs: 1,
      ),
    ]);
    await SharedPreferencesService.saveBookmark(2, 255);
    await SharedPreferencesService.removeBookmark(2, 255);

    await sync.sync('user-1');
    expect(SharedPreferencesService.isBookmarked(2, 255), isFalse);
    expect(remote.bookmarks['user-1']!['2_255']!.$1.deleted, isTrue);
  });

  test('bookmark lama (sebelum fitur sync) ikut terunggah', () async {
    await _fresh({'bookmark_18_10': true});
    final remote = FakeRemote();
    await CloudSyncService(remote).sync('user-1');
    expect(remote.bookmarks['user-1']!.keys, ['18_10']);
  });

  test('ganti akun tidak mencampur data antar akun', () async {
    final store = await _fresh();
    final remote = FakeRemote();
    final sync = CloudSyncService(remote);
    await store.save(_session('a-session'));
    await SharedPreferencesService.saveBookmark(2, 255);
    await sync.sync('user-a');

    await store.save(_session('offline-later', date: '2026-05-05'));
    await sync.sync('user-b');

    final ids = store.all().map((s) => s.id).toSet();
    expect(ids, isNot(contains('a-session')));
    expect(ids, contains('offline-later'));
    expect(SharedPreferencesService.isBookmarked(2, 255), isFalse);
    expect(remote.sessions['user-b']!.keys, ['offline-later']);
    expect(remote.sessions['user-a']!.keys, ['a-session']);
  });

  test('hapus data cloud: server kosong, data lokal tetap ada', () async {
    final store = await _fresh();
    final remote = FakeRemote();
    final sync = CloudSyncService(remote);
    await store.save(_session('a'));
    await sync.sync('user-1');

    await sync.deleteCloudData('user-1');
    expect(remote.sessions['user-1'], isNull);
    expect(store.forDate('2026-05-04').single.syncStatus, 'local');
    expect(SharedPreferencesService.getReadingSeconds('2026-05-04'), 300);
  });

  group('mergedActiveSeconds', () {
    test('satu perangkat selalu dijumlah penuh', () {
      expect(
        mergedActiveSeconds([
          _session('1', seconds: 120),
          _session('2', seconds: 180),
        ]),
        300,
      );
    });

    test('dua perangkat bersamaan tidak dihitung dua kali', () {
      expect(
        mergedActiveSeconds([
          _session('1', device: 'a', seconds: 300),
          _session('2', device: 'b', seconds: 300),
        ]),
        300,
      );
    });

    test('dua perangkat di waktu berbeda dijumlah', () {
      expect(
        mergedActiveSeconds([
          _session('1', device: 'a', seconds: 300),
          _session(
            '2',
            device: 'b',
            seconds: 200,
            start: DateTime.utc(2026, 5, 4, 5),
          ),
        ]),
        500,
      );
    });
  });
}
