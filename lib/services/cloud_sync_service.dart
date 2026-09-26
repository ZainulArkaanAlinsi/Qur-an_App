import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:quran_app_2025/features/session/data/session_store.dart';
import 'package:quran_app_2025/services/reading_session_store.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Items changed on the server after a cursor, plus the new cursor.
class RemotePage<T> {
  const RemotePage(this.items, this.cursorMs);
  final List<T> items;

  /// Largest server `syncedAt` seen, in milliseconds since epoch.
  final int cursorMs;
}

/// Server storage for one signed-in user. Implemented with Firestore in the
/// app and with an in-memory fake in tests.
abstract class SyncRemote {
  /// Upserts by session ID, so retries never duplicate a session.
  Future<void> pushSessions(String uid, List<ReadingSession> sessions);
  Future<RemotePage<ReadingSession>> pullSessions(String uid, int sinceMs);
  Future<void> pushBookmarks(String uid, List<BookmarkRecord> records);
  Future<RemotePage<BookmarkRecord>> pullBookmarks(String uid, int sinceMs);

  /// Dates (yyyy-mm-dd) of completed "Sesi hari ini". Only the date is ever
  /// sent: recordings and self-ratings never leave the phone
  /// (docs/design/v5-sesi-harian/SESI_HARIAN.md §5).
  Future<void> pushSessionDays(String uid, List<String> dates);
  Future<RemotePage<String>> pullSessionDays(String uid, int sinceMs);

  /// Deletes every document the user owns.
  Future<void> deleteAll(String uid);
}

enum SyncState { idle, syncing, done, failed }

/// Tracks server writes that have not settled yet.
///
/// A timed-out write is still queued by the SDK and sent on reconnect, so a
/// new upload must not be queued on top of it; otherwise every offline sync
/// pass would add another copy of the same outbox.
class PendingWrites {
  int _unsettled = 0;

  bool get hasPending => _unsettled > 0;

  /// Counts [write] until it completes or fails, and returns it unchanged.
  Future<T> track<T>(Future<T> write) {
    _unsettled++;
    return write.whenComplete(() => _unsettled--);
  }

  /// Throws while an earlier write is still waiting for the network.
  void ensureSettled() {
    if (hasPending) throw const WritesPendingException();
  }
}

class WritesPendingException implements Exception {
  const WritesPendingException();

  @override
  String toString() =>
      'Unggahan sebelumnya masih menunggu jaringan; dicoba lagi nanti.';
}

/// Two-way sync of reading sessions and bookmarks.
///
/// Reading works fully offline: closed sessions wait in the local outbox
/// (`syncStatus: local`) and are uploaded idempotently when a user is signed
/// in. Stats are never uploaded; every device derives them from sessions.
class CloudSyncService {
  CloudSyncService(this.remote);

  final SyncRemote remote;
  final state = ValueNotifier<SyncState>(SyncState.idle);
  final message = ValueNotifier<String?>(null);

  // Pulls overlap by this window: a write can commit with a server time
  // slightly before a cursor already read. Re-applying items is harmless.
  static const _cursorOverlapMs = 5 * 60 * 1000;
  static const _ownerKey = 'sync_owner_uid';
  static const _lastSuccessKey = 'sync_last_success_ms';

  Future<void>? _running;
  bool _again = false;

  Future<DateTime?> lastSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastSuccessKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  // The account the next pass must sync; null after sign-out or while an
  // account is being deleted. Passes always read the latest value, so a
  // queued pass never syncs a previous account.
  String? _target;
  bool _paused = false;

  /// Syncs [uid]. A call made while syncing retargets the queued pass to
  /// [uid] instead of running concurrently.
  Future<void> sync(String uid) {
    if (_paused) return Future<void>.value();
    _target = uid;
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    final run = _loop().whenComplete(() => _running = null);
    _running = run;
    return run;
  }

  /// Stops syncing any account (sign-out); a running pass aborts at its
  /// next step and nothing is queued.
  void cancel() {
    _target = null;
    _again = false;
  }

  Future<void> _loop() async {
    do {
      _again = false;
      final uid = _target;
      if (uid == null) break;
      await _syncOnce(uid);
    } while (_again);
  }

  void _ensureTarget(String uid) {
    if (_target != uid || _paused) throw const _SyncCancelled();
  }

  Future<void> _syncOnce(String uid) async {
    state.value = SyncState.syncing;
    message.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final store = ReadingSessionStore(prefs);
      _ensureTarget(uid);
      await _claimDevice(prefs, store, uid);
      await SharedPreferencesService.adoptLegacyBookmarks();

      // Sessions are append-only, so pushing before pulling cannot lose
      // anything; the session ID makes a retried upload a no-op.
      _ensureTarget(uid);
      final outbox = store.pendingUpload();
      if (outbox.isNotEmpty) {
        await remote.pushSessions(uid, outbox);
        await store.saveAll([
          for (final s in outbox) s.copyWith(syncStatus: 'synced'),
        ]);
      }

      // Bookmarks are pulled before pushing: a newer server copy replaces a
      // stale local edit (clearing its dirty flag) instead of being
      // overwritten by it. Security rules also reject older updates.
      _ensureTarget(uid);
      final bookmarksKey = 'sync_bookmarks_cursor_$uid';
      final bookmarks = await remote.pullBookmarks(
        uid,
        _since(prefs.getInt(bookmarksKey)),
      );
      for (final record in bookmarks.items) {
        await SharedPreferencesService.applyRemoteBookmark(record);
      }
      _ensureTarget(uid);
      await _pushBookmarks(uid);
      await _advance(prefs, bookmarksKey, bookmarks.cursorMs);

      _ensureTarget(uid);
      final sessionsKey = 'sync_sessions_cursor_$uid';
      final sessions = await remote.pullSessions(
        uid,
        _since(prefs.getInt(sessionsKey)),
      );
      _ensureTarget(uid);
      for (final s in sessions.items) {
        await SharedPreferencesService.ensureTargetSnapshot(s.localDate);
      }
      await store.saveAll([
        for (final s in sessions.items) s.copyWith(syncStatus: 'synced'),
      ]);
      await _advance(prefs, sessionsKey, sessions.cursorMs);

      _ensureTarget(uid);
      await _syncSessionDays(prefs, uid);

      await prefs.setInt(
        _lastSuccessKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      state.value = SyncState.done;
    } on _SyncCancelled {
      // Account changed or signed out mid-pass; not an error.
      state.value = SyncState.idle;
    } on Object catch (error) {
      // Local data is untouched on failure; the outbox retries next time.
      debugPrint('Sinkronisasi gagal: $error');
      message.value = 'Sinkronisasi gagal. Data tetap aman di perangkat.';
      state.value = SyncState.failed;
    }
  }

  /// Uploads dirty bookmarks. The batch is atomic, so if the server rejects
  /// one stale record (older than its copy, e.g. after clock skew and the
  /// server copy fell outside the pull window), every bookmark would stay
  /// stuck. On failure, re-pull all bookmarks so newer server copies replace
  /// stale local ones (clearing their dirty flag), then retry once.
  Future<void> _pushBookmarks(String uid) async {
    Future<void> push() async {
      final dirty = SharedPreferencesService.dirtyBookmarks();
      if (dirty.isEmpty) return;
      await remote.pushBookmarks(uid, dirty);
      for (final record in dirty) {
        await SharedPreferencesService.markBookmarkSynced(record);
      }
    }

    try {
      await push();
    } on _SyncCancelled {
      rethrow;
    } on Object catch (error) {
      debugPrint('Unggah bookmark ditolak, menyelaraskan ulang: $error');
      _ensureTarget(uid);
      final all = await remote.pullBookmarks(uid, 0);
      for (final record in all.items) {
        await SharedPreferencesService.applyRemoteBookmark(record);
      }
      _ensureTarget(uid);
      await push();
    }
  }

  /// Completed "Sesi hari ini" dates, both ways. A failure here (e.g. rules
  /// not deployed yet) never fails the rest of the sync: the dates stay on
  /// the phone and are retried on the next pass.
  Future<void> _syncSessionDays(SharedPreferences prefs, String uid) async {
    final days = SessionStore(prefs);
    final cursorKey = 'sync_session_days_cursor_$uid';
    final sentKey = 'sync_session_days_sent_$uid';
    try {
      final pulled = await remote.pullSessionDays(
        uid,
        _since(prefs.getInt(cursorKey)),
      );
      _ensureTarget(uid);
      await days.addCompletedDates(pulled.items);
      final sent = {...?prefs.getStringList(sentKey), ...pulled.items};
      final unsent = days.completedDates().difference(sent).toList()..sort();
      if (unsent.isNotEmpty) {
        await remote.pushSessionDays(uid, unsent);
        sent.addAll(unsent);
      }
      await prefs.setStringList(sentKey, sent.toList()..sort());
      await _advance(prefs, cursorKey, pulled.cursorMs);
    } on _SyncCancelled {
      rethrow;
    } on Object catch (error) {
      debugPrint('Tanggal sesi harian belum tersinkron: $error');
    }
  }

  static int _since(int? cursor) =>
      cursor == null ? 0 : (cursor - _cursorOverlapMs).clamp(0, cursor);

  static Future<void> _advance(
    SharedPreferences prefs,
    String key,
    int cursor,
  ) async {
    if (cursor > (prefs.getInt(key) ?? 0)) await prefs.setInt(key, cursor);
  }

  /// Local guest data is claimed by the first account that signs in. If a
  /// different account signs in later, the previous account's cloud data is
  /// removed from this device first so accounts never mix.
  Future<void> _claimDevice(
    SharedPreferences prefs,
    ReadingSessionStore store,
    String uid,
  ) async {
    final owner = prefs.getString(_ownerKey);
    if (owner == uid) return;
    if (owner != null) {
      await store.removeSynced();
      await SharedPreferencesService.clearSyncedBookmarks();
      await SessionStore(prefs).removeImported();
      await prefs.remove('sync_sessions_cursor_$owner');
      await prefs.remove('sync_bookmarks_cursor_$owner');
      await prefs.remove('sync_session_days_cursor_$owner');
      await prefs.remove('sync_session_days_sent_$owner');
    }
    await prefs.setString(_ownerKey, uid);
  }

  /// Phase 1 of account deletion: pauses all syncing (so nothing is
  /// re-uploaded meanwhile) and deletes the user's cloud documents.
  /// Call [finishAccountDeletion] once the account itself is deleted, or
  /// [resume] if that fails.
  Future<void> deleteCloudData(String uid) async {
    _paused = true;
    cancel();
    await _running;
    await remote.deleteAll(uid);
  }

  /// Phase 2, only after the account is gone: local data stays on the device
  /// and becomes local-only again, ready for a future account.
  Future<void> finishAccountDeletion(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sync_sessions_cursor_$uid');
      await prefs.remove('sync_bookmarks_cursor_$uid');
      await prefs.remove('sync_session_days_cursor_$uid');
      await prefs.remove('sync_session_days_sent_$uid');
      await prefs.remove(_ownerKey);
      await prefs.remove(_lastSuccessKey);
      final store = ReadingSessionStore(prefs);
      await store.saveAll([
        for (final s in store.all())
          if (s.syncStatus == 'synced') s.copyWith(syncStatus: 'local'),
      ]);
    } finally {
      // The account is already gone; never leave sync disabled for the next
      // account because local cleanup failed.
      _paused = false;
    }
  }

  /// Aborted deletion (the account still exists): marks local data unsent
  /// again so the next sync restores the cloud copy, then resumes syncing.
  Future<void> restoreAfterFailedDeletion(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sync_sessions_cursor_$uid');
    await prefs.remove('sync_bookmarks_cursor_$uid');
    await prefs.remove('sync_session_days_cursor_$uid');
    await prefs.remove('sync_session_days_sent_$uid');
    final store = ReadingSessionStore(prefs);
    await store.saveAll([
      for (final s in store.all())
        if (s.syncStatus == 'synced') s.copyWith(syncStatus: 'local'),
    ]);
    await SharedPreferencesService.markAllBookmarksDirty();
    _paused = false;
  }
}

class _SyncCancelled implements Exception {
  const _SyncCancelled();
}
