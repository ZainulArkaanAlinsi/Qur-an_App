/// Penyimpanan lokal Sesi hari ini (docs/design/v5-sesi-harian/SESI_HARIAN.md §5).
///
/// Semuanya tinggal di HP. Yang boleh ikut sinkron cloud hanya tanggal sesi
/// selesai ([SessionStore.completedDates]); rekaman dan penilaian diri tidak
/// pernah keluar dari sini.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran_app_2025/features/session/domain/session_plan.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Naik setiap kali keadaan sesi berubah, supaya kartu Beranda dan istiqamah
/// ikut menyegarkan diri.
final sessionRevision = ValueNotifier<int>(0);

/// Satu penilaian diri "mirip/beda" untuk satu ayat.
@immutable
class RatingEntry {
  const RatingEntry({
    required this.date,
    required this.verseKey,
    required this.rating,
  });

  final String date;
  final String verseKey;
  final SelfRating rating;

  Map<String, dynamic> toJson() => {'d': date, 'v': verseKey, 'r': rating.name};

  static RatingEntry? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final date = json['d'];
    final verse = json['v'];
    final rating = SelfRating.fromName(json['r']);
    if (date is! String || verse is! String || rating == null) return null;
    return RatingEntry(date: date, verseKey: verse, rating: rating);
  }
}

class SessionStore {
  SessionStore(this._prefs, {Future<Directory> Function()? documents})
    : _documents = documents ?? getApplicationDocumentsDirectory;

  /// Penyimpanan aplikasi, atau null sebelum `SharedPreferencesService.init`.
  static SessionStore? get app {
    final prefs = SharedPreferencesService.instance;
    return prefs == null ? null : SessionStore(prefs);
  }

  final SharedPreferences _prefs;
  final Future<Directory> Function() _documents;

  static const dayPrefix = 'sesi.hari.';
  static const verseHistoryKey = 'sesi.riwayatAyat';
  static const ratingsKey = 'sesi.nilaiDiri';

  /// Nama berkas rekaman yang disematkan (tidak ikut dibersihkan otomatis).
  static const pinnedKey = 'sesi.rekamanSemat';

  static const verseHistoryLimit = 60;
  static const ratingDays = 90;
  static const recordingDays = 30;
  static const recordingsFolder = 'rekaman_sesi';

  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _dateKey = RegExp(r'^sesi\.hari\.(\d{4}-\d{2}-\d{2})$');
  static final _recordingName = RegExp(
    r'^(\d{1,3})_(\d{1,3})_(\d{4}-\d{2}-\d{2})\.m4a$',
  );

  // ---------------------------------------------------------------- sesi

  /// Sesi tanggal [date], atau null bila belum ada atau rusak.
  DailySession? day(String date) {
    final raw = _prefs.getString('$dayPrefix$date');
    if (raw == null) return null;
    try {
      final session = DailySession.fromJson(jsonDecode(raw));
      return session?.date == date ? session : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> saveDay(DailySession session) async {
    await _prefs.setString(
      '$dayPrefix${session.date}',
      jsonEncode(session.toJson()),
    );
    sessionRevision.value++;
  }

  /// Tanggal sesi yang sudah selesai. Hanya ini yang dihitung istiqamah dan
  /// yang boleh ikut sinkron cloud.
  Set<String> completedDates() => completedDatesIn(_prefs);

  /// [completedDates] dari [prefs] langsung, untuk pemanggil sinkron
  /// (mis. perhitungan istiqamah).
  static Set<String> completedDatesIn(SharedPreferences? prefs) {
    if (prefs == null) return const {};
    final dates = <String>{};
    for (final key in prefs.getKeys()) {
      final match = _dateKey.firstMatch(key);
      if (match == null) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && decoded['selesai'] == true) {
          dates.add(match[1]!);
        }
      } on FormatException {
        continue;
      }
    }
    return dates;
  }

  /// Banyaknya sesi selesai; dipakai memutar huruf dan tanda hari ini.
  int completedCount() => completedDates().length;

  /// Menandai [dates] selesai dari sinkron cloud. Hanya tanggal yang belum
  /// punya sesi selesai di HP ini yang ditambah; isi sesi lokal tidak ditimpa.
  Future<void> addCompletedDates(Iterable<String> dates) async {
    var changed = false;
    for (final date in dates) {
      if (!_date.hasMatch(date)) continue;
      final local = day(date);
      if (local?.completed ?? false) continue;
      final session =
          local?.copyWith(step: SessionStep.done, completed: true) ??
          DailySession(date: date, step: SessionStep.done, completed: true);
      await _prefs.setString('$dayPrefix$date', jsonEncode(session.toJson()));
      changed = true;
    }
    if (changed) sessionRevision.value++;
  }

  // --------------------------------------------------------- riwayat ayat

  /// Ayat yang sudah dipakai sesi, urut lama → baru, paling banyak 60.
  List<String> verseHistory() =>
      List.unmodifiable(_prefs.getStringList(verseHistoryKey) ?? const []);

  Future<void> rememberVerse(String verseKey) async {
    final list = [...verseHistory()]
      ..remove(verseKey)
      ..add(verseKey);
    final start = list.length > verseHistoryLimit
        ? list.length - verseHistoryLimit
        : 0;
    await _prefs.setStringList(verseHistoryKey, list.sublist(start));
  }

  // ---------------------------------------------------------- nilai diri

  List<RatingEntry> ratings() {
    final raw = _prefs.getString(ratingsKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final item in decoded) ?RatingEntry.fromJson(item)];
    } on FormatException {
      return const [];
    }
  }

  /// Menyimpan penilaian diri dan membuang yang lebih tua dari 90 hari.
  /// Penilaian ulang untuk ayat dan tanggal yang sama menggantikan yang lama.
  Future<void> addRating(RatingEntry entry) async {
    final today = dayNumber(entry.date);
    final kept = [
      for (final item in ratings())
        if (today - dayNumber(item.date) < ratingDays &&
            !(item.date == entry.date && item.verseKey == entry.verseKey))
          item,
      entry,
    ];
    await _prefs.setString(
      ratingsKey,
      jsonEncode([for (final item in kept) item.toJson()]),
    );
  }

  // ------------------------------------------------------------- rekaman

  Future<Directory> recordingsDirectory() async {
    final root = await _documents();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}$recordingsFolder',
    );
    // Operasi berkas di sini kecil dan jarang; versi sinkron menjaga urutan
    // tulis-hapus tetap pasti.
    if (!directory.existsSync()) directory.createSync(recursive: true);
    return directory;
  }

  static String recordingName(int surah, int ayah, String date) =>
      '${surah}_${ayah}_$date.m4a';

  Future<File> recordingFile(int surah, int ayah, String date) async {
    final directory = await recordingsDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}'
      '${recordingName(surah, ayah, date)}',
    );
  }

  Set<String> pinned() => (_prefs.getStringList(pinnedKey) ?? const []).toSet();

  Future<void> setPinned(String fileName, bool pin) async {
    final current = pinned();
    if (pin ? !current.add(fileName) : !current.remove(fileName)) return;
    await _prefs.setStringList(pinnedKey, current.toList()..sort());
  }

  /// Rekaman sesi yang ada, terbaru dulu.
  Future<List<File>> recordings() async {
    final directory = await recordingsDirectory();
    final files = [
      for (final entity in directory.listSync())
        if (entity is File && _recordingName.hasMatch(fileName(entity))) entity,
    ];
    int byDate(File a, File b) => _recordingName
        .firstMatch(fileName(b))![3]!
        .compareTo(_recordingName.firstMatch(fileName(a))![3]!);
    return files..sort(byDate);
  }

  /// Menghapus rekaman yang lebih tua dari 30 hari, kecuali yang disematkan.
  /// Umurnya dihitung dari tanggal di nama berkas. Mengembalikan jumlah
  /// berkas yang dihapus.
  Future<int> cleanRecordings({required String today}) async {
    final keep = pinned();
    final now = dayNumber(today);
    var removed = 0;
    for (final file in await recordings()) {
      final name = fileName(file);
      final date = _recordingName.firstMatch(name)![3]!;
      if (keep.contains(name) || now - dayNumber(date) <= recordingDays) {
        continue;
      }
      try {
        file.deleteSync();
        removed++;
      } on FileSystemException {
        continue;
      }
    }
    return removed;
  }

  Future<void> deleteRecording(File file) async {
    if (file.existsSync()) file.deleteSync();
    await setPinned(fileName(file), false);
  }

  /// Menghapus semua rekaman sesi beserta tanda sematnya.
  Future<void> deleteAllRecordings() async {
    for (final file in await recordings()) {
      try {
        file.deleteSync();
      } on FileSystemException {
        continue;
      }
    }
    await _prefs.remove(pinnedKey);
  }

  static String fileName(File file) => file.uri.pathSegments.last;
}
