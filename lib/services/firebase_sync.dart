import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:quran_app_2025/firebase_options.dart';
import 'package:quran_app_2025/services/cloud_sync_service.dart';
import 'package:quran_app_2025/services/reading_session_store.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Firestore layout (security rules in `firestore.rules`):
/// `users/{uid}/sessions/{sessionId}` and `users/{uid}/bookmarks/{s_a}`.
class FirestoreSyncRemote implements SyncRemote {
  FirestoreSyncRemote(this._db);

  final FirebaseFirestore _db;
  static const _pageSize = 400;

  // On mobile, commit() completes only after the server acknowledges, so
  // offline it would wait forever and block every later sync. Bounding it
  // turns "offline" into a normal failed sync; queued writes are still sent
  // by the SDK later, and retries are idempotent (document ID = record ID).
  static const _timeout = Duration(seconds: 30);

  // Reads must come from the server: a cache fallback would make an offline
  // sync look successful and would let deleteAll remove only cached docs.
  static const _fromServer = GetOptions(source: Source.server);

  static Future<T> _bounded<T>(Future<T> future) => future.timeout(_timeout);

  CollectionReference<Map<String, dynamic>> _col(String uid, String name) =>
      _db.collection('users').doc(uid).collection(name);

  Future<void> _writeAll(
    String uid,
    String collection,
    Iterable<MapEntry<String, Map<String, dynamic>>> docs,
  ) async {
    var batch = _db.batch();
    var count = 0;
    for (final doc in docs) {
      batch.set(_col(uid, collection).doc(doc.key), {
        ...doc.value,
        'syncedAt': FieldValue.serverTimestamp(),
      });
      if (++count == _pageSize) {
        await _bounded(batch.commit());
        batch = _db.batch();
        count = 0;
      }
    }
    if (count > 0) await _bounded(batch.commit());
  }

  Future<RemotePage<T>> _pull<T>(
    String uid,
    String collection,
    int sinceMs,
    T Function(Map<String, dynamic>) decode,
  ) async {
    final items = <T>[];
    var cursor = sinceMs;
    DocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      var query = _col(uid, collection)
          .where(
            'syncedAt',
            isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(sinceMs),
          )
          .orderBy('syncedAt')
          .limit(_pageSize);
      if (last != null) query = query.startAfterDocument(last);
      final page = await _bounded(query.get(_fromServer));
      for (final doc in page.docs) {
        final data = doc.data();
        final syncedAt = data['syncedAt'];
        if (syncedAt is Timestamp) {
          final ms = syncedAt.millisecondsSinceEpoch;
          if (ms > cursor) cursor = ms;
        }
        try {
          items.add(decode(data));
        } on Object catch (error) {
          // Skip a malformed document rather than blocking all sync.
          debugPrint('Dokumen sync dilewati (${doc.id}): $error');
        }
      }
      if (page.docs.length < _pageSize) break;
      last = page.docs.last;
    }
    return RemotePage(items, cursor);
  }

  @override
  Future<void> pushSessions(String uid, List<ReadingSession> sessions) =>
      _writeAll(uid, 'sessions', [
        for (final s in sessions)
          MapEntry(s.id, {
            'id': s.id,
            'deviceId': s.deviceId,
            'startedAt': Timestamp.fromDate(s.startedAtUtc),
            'endedAt': Timestamp.fromDate(s.endedAtUtc!),
            'activeSeconds': s.activeSeconds,
            'timezone': s.timezone,
            'localDate': s.localDate,
            'mode': s.mode,
            'lastVerseKey': s.lastVerseKey,
          }),
      ]);

  @override
  Future<RemotePage<ReadingSession>> pullSessions(String uid, int sinceMs) =>
      _pull(
        uid,
        'sessions',
        sinceMs,
        (d) => ReadingSession(
          id: d['id'] as String,
          deviceId: d['deviceId'] as String,
          startedAtUtc: (d['startedAt'] as Timestamp).toDate().toUtc(),
          endedAtUtc: (d['endedAt'] as Timestamp).toDate().toUtc(),
          activeSeconds: d['activeSeconds'] as int,
          timezone: d['timezone'] as String,
          localDate: d['localDate'] as String,
          mode: d['mode'] as String? ?? 'reading',
          lastVerseKey: d['lastVerseKey'] as String?,
          syncStatus: 'synced',
        ),
      );

  @override
  Future<void> pushBookmarks(String uid, List<BookmarkRecord> records) =>
      _writeAll(uid, 'bookmarks', [
        for (final r in records)
          MapEntry(r.id, {
            'surah': r.surah,
            'ayah': r.ayah,
            'collection': r.collection,
            'deleted': r.deleted,
            'updatedAtMs': r.updatedAtMs,
          }),
      ]);

  @override
  Future<RemotePage<BookmarkRecord>> pullBookmarks(String uid, int sinceMs) =>
      _pull(
        uid,
        'bookmarks',
        sinceMs,
        (d) => BookmarkRecord(
          surah: d['surah'] as int,
          ayah: d['ayah'] as int,
          collection: d['collection'] as String,
          deleted: d['deleted'] as bool,
          updatedAtMs: d['updatedAtMs'] as int,
        ),
      );

  @override
  Future<void> deleteAll(String uid) async {
    for (final name in const ['sessions', 'bookmarks']) {
      while (true) {
        final page = await _bounded(
          _col(uid, name).limit(_pageSize).get(_fromServer),
        );
        if (page.docs.isEmpty) break;
        final batch = _db.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await _bounded(batch.commit());
      }
    }
  }
}

/// Signed-in account as shown in the UI.
@immutable
class SyncAccount {
  const SyncAccount({required this.uid, this.email, this.name});
  final String uid;
  final String? email;
  final String? name;
}

/// Google sign-in, Firebase Auth and automatic sync. Everything here is
/// optional: when Firebase is unavailable, [available] stays false and the
/// app keeps working offline.
class AccountService with WidgetsBindingObserver {
  AccountService._();
  static final instance = AccountService._();

  final account = ValueNotifier<SyncAccount?>(null);
  final busy = ValueNotifier<bool>(false);
  bool available = false;
  CloudSyncService? sync;

  static const _minInterval = Duration(minutes: 1);
  DateTime? _lastAutoSync;

  /// Initialises Firebase; failure only disables sync.
  Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      sync = CloudSyncService(FirestoreSyncRemote(FirebaseFirestore.instance));
      await GoogleSignIn.instance.initialize();
      available = true;
    } on Object catch (error) {
      debugPrint('Sinkronisasi cloud tidak aktif: $error');
      return;
    }
    FirebaseAuth.instance.authStateChanges().listen((user) {
      account.value = user == null
          ? null
          : SyncAccount(
              uid: user.uid,
              email: user.email,
              name: user.displayName,
            );
      if (user != null) unawaited(syncNow());
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncSoon());
  }

  /// Syncs unless one ran within the last minute (used on app resume).
  Future<void> syncSoon() async {
    final last = _lastAutoSync;
    if (last != null && DateTime.now().difference(last) < _minInterval) {
      return;
    }
    await syncNow();
  }

  Future<void> syncNow() async {
    final uid = account.value?.uid;
    final service = sync;
    if (uid == null || service == null) return;
    _lastAutoSync = DateTime.now();
    await service.sync(uid);
  }

  /// Returns an error message for the UI, or null on success/cancel.
  Future<String?> signInWithGoogle() async {
    if (!available) return 'Sinkronisasi belum tersedia di perangkat ini.';
    busy.value = true;
    try {
      final google = await GoogleSignIn.instance.authenticate();
      final idToken = google.authentication.idToken;
      if (idToken == null) return 'Google tidak mengirim token masuk.';
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return null;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      debugPrint('Google Sign-In gagal: $error');
      return 'Masuk dengan Google gagal. Coba lagi.';
    } on FirebaseAuthException catch (error) {
      debugPrint('Firebase Auth gagal: ${error.code}');
      return 'Masuk gagal (${error.code}).';
    } finally {
      busy.value = false;
    }
  }

  /// Signs out; data already on this device stays available offline.
  Future<void> signOut() async {
    // Stop any queued pass so later guest changes never reach this account.
    sync?.cancel();
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn.instance.signOut();
  }

  /// Deletes cloud data and the Firebase account. Returns an error message,
  /// or null on success.
  ///
  /// The user confirms with Google first, so `user.delete()` cannot fail with
  /// `requires-recent-login` after the cloud data is already gone. If it
  /// still fails, local data is queued again so the cloud copy is restored.
  Future<String?> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    final service = sync;
    if (user == null || service == null) return 'Belum masuk.';
    busy.value = true;
    var deletionStarted = false;
    var accountDeleted = false;
    try {
      final google = await GoogleSignIn.instance.authenticate();
      final idToken = google.authentication.idToken;
      if (idToken == null) return 'Google tidak mengirim token masuk.';
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      deletionStarted = true;
      await service.deleteCloudData(user.uid);
      await user.delete();
      accountDeleted = true;
      await service.finishAccountDeletion(user.uid);
      await GoogleSignIn.instance.signOut();
      return null;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return 'Penghapusan dibatalkan.';
      }
      return 'Konfirmasi Google gagal. Akun tidak dihapus.';
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-mismatch') {
        return 'Pilih akun Google yang sama dengan akun yang sedang masuk.';
      }
      return 'Akun gagal dihapus (${error.code}).';
    } on Object catch (error) {
      debugPrint('Hapus akun gagal: $error');
      return 'Akun gagal dihapus. Periksa koneksi internet.';
    } finally {
      // Cloud data may be partly deleted while the account still exists:
      // requeue local data so the next sync restores it, and resume sync.
      if (deletionStarted && !accountDeleted) {
        await service.restoreAfterFailedDeletion(user.uid);
      }
      busy.value = false;
    }
  }
}
