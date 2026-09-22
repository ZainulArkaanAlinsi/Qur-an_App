import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';

class SharedPreferencesService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool isBookmarked(int surahNumber, int verseNumber) =>
      _prefs?.getBool('bookmark_${surahNumber}_$verseNumber') ?? false;
  static Future<void> saveBookmark(int surahNumber, int verseNumber) async {
    await _prefs?.setBool('bookmark_${surahNumber}_$verseNumber', true);
    await _prefs?.setString(
      'bookmark_collection_${surahNumber}_$verseNumber',
      'Umum',
    );
    await _touchBookmark(surahNumber, verseNumber, deleted: false);
  }

  static Future<void> removeBookmark(int surahNumber, int verseNumber) async {
    await _prefs?.remove('bookmark_${surahNumber}_$verseNumber');
    await _prefs?.remove('bookmark_collection_${surahNumber}_$verseNumber');
    // Keep a tombstone so an older copy from another device cannot
    // resurrect the bookmark during sync.
    await _touchBookmark(surahNumber, verseNumber, deleted: true);
  }

  static String getBookmarkCollection(int surahNumber, int verseNumber) =>
      _prefs?.getString('bookmark_collection_${surahNumber}_$verseNumber') ??
      'Umum';

  static Future<void> setBookmarkCollection(
    int surahNumber,
    int verseNumber,
    String collection,
  ) async {
    await _prefs?.setString(
      'bookmark_collection_${surahNumber}_$verseNumber',
      collection.trim().isEmpty ? 'Umum' : collection.trim(),
    );
    await _touchBookmark(surahNumber, verseNumber, deleted: false);
  }

  static Future<void> _touchBookmark(
    int surah,
    int ayah, {
    required bool deleted,
  }) async {
    // Always newer than the version this device last saw, even if its clock
    // runs behind another device's; otherwise the server (last write wins)
    // would reject the edit forever.
    final previous = _prefs?.getInt('bookmark_updated_${surah}_$ayah') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _prefs?.setInt(
      'bookmark_updated_${surah}_$ayah',
      now > previous ? now : previous + 1,
    );
    await _prefs?.setBool('bookmark_deleted_${surah}_$ayah', deleted);
    await _prefs?.setBool('bookmark_dirty_${surah}_$ayah', true);
  }

  static BookmarkRecord _bookmarkRecord(int surah, int ayah) => BookmarkRecord(
    surah: surah,
    ayah: ayah,
    collection: getBookmarkCollection(surah, ayah),
    deleted: _prefs?.getBool('bookmark_deleted_${surah}_$ayah') ?? false,
    updatedAtMs: _prefs?.getInt('bookmark_updated_${surah}_$ayah') ?? 0,
  );

  /// Bookmarks changed locally since their last successful upload.
  static List<BookmarkRecord> dirtyBookmarks() {
    final pattern = RegExp(r'^bookmark_dirty_(\d+)_(\d+)$');
    final records = <BookmarkRecord>[];
    for (final key in _prefs?.getKeys() ?? const <String>{}) {
      final match = pattern.firstMatch(key);
      if (match == null || _prefs?.getBool(key) != true) continue;
      records.add(_bookmarkRecord(int.parse(match[1]!), int.parse(match[2]!)));
    }
    return records;
  }

  /// Clears the dirty flag unless the bookmark changed again meanwhile.
  static Future<void> markBookmarkSynced(BookmarkRecord record) async {
    final current = _bookmarkRecord(record.surah, record.ayah);
    if (current.updatedAtMs == record.updatedAtMs) {
      await _prefs?.remove('bookmark_dirty_${record.surah}_${record.ayah}');
    }
  }

  /// Applies a bookmark from the cloud when it is newer than the local copy
  /// (last write wins); returns whether anything changed.
  static Future<bool> applyRemoteBookmark(BookmarkRecord remote) async {
    if (!_validBookmarkKey('bookmark_${remote.surah}_${remote.ayah}')) {
      return false;
    }
    final local = _bookmarkRecord(remote.surah, remote.ayah);
    if (remote.updatedAtMs <= local.updatedAtMs) return false;
    final base = '${remote.surah}_${remote.ayah}';
    if (remote.deleted) {
      await _prefs?.remove('bookmark_$base');
      await _prefs?.remove('bookmark_collection_$base');
    } else {
      await _prefs?.setBool('bookmark_$base', true);
      await _prefs?.setString('bookmark_collection_$base', remote.collection);
    }
    await _prefs?.setInt('bookmark_updated_$base', remote.updatedAtMs);
    await _prefs?.setBool('bookmark_deleted_$base', remote.deleted);
    await _prefs?.remove('bookmark_dirty_$base');
    return true;
  }

  /// Removes bookmarks already confirmed by the cloud (not dirty), with
  /// their metadata; used when a different account signs in so one
  /// account's bookmarks never leak into another.
  static Future<void> clearSyncedBookmarks() async {
    final pattern = RegExp(r'^bookmark_updated_(\d+)_(\d+)$');
    for (final key in (_prefs?.getKeys() ?? const <String>{}).toList()) {
      final match = pattern.firstMatch(key);
      if (match == null) continue;
      final base = '${match[1]}_${match[2]}';
      if (_prefs?.getBool('bookmark_dirty_$base') == true) continue;
      for (final prefix in const [
        'bookmark_',
        'bookmark_collection_',
        'bookmark_updated_',
        'bookmark_deleted_',
      ]) {
        await _prefs?.remove('$prefix$base');
      }
    }
  }

  /// Queues every bookmark record (including tombstones) for upload again,
  /// keeping its timestamp; used to restore a cloud copy.
  static Future<void> markAllBookmarksDirty() async {
    final pattern = RegExp(r'^bookmark_updated_(\d+)_(\d+)$');
    for (final key in (_prefs?.getKeys() ?? const <String>{}).toList()) {
      final match = pattern.firstMatch(key);
      if (match == null) continue;
      await _prefs?.setBool('bookmark_dirty_${match[1]}_${match[2]}', true);
    }
  }

  /// Marks bookmarks saved before sync metadata existed so the first sync
  /// uploads them; runs once.
  static Future<void> adoptLegacyBookmarks() async {
    if (_prefs?.getBool('bookmark_sync_adopted_v1') == true) return;
    for (final key in getBookmarks()) {
      final parts = key.split('_');
      final surah = int.parse(parts[1]);
      final ayah = int.parse(parts[2]);
      if (_prefs?.containsKey('bookmark_updated_${surah}_$ayah') != true) {
        await _touchBookmark(surah, ayah, deleted: false);
      }
    }
    await _prefs?.setBool('bookmark_sync_adopted_v1', true);
  }

  static List<String> getBookmarks() =>
      (_prefs?.getKeys() ?? <String>{})
          .where((key) => _validBookmarkKey(key) && _prefs?.get(key) == true)
          .toList()
        ..sort();
  static bool _validBookmarkKey(String key) {
    final match = RegExp(r'^bookmark_(\d+)_(\d+)$').firstMatch(key);
    if (match == null) return false;
    final surah = int.tryParse(match[1]!) ?? 0;
    final verse = int.tryParse(match[2]!) ?? 0;
    return surah >= 1 &&
        surah <= 114 &&
        verse >= 1 &&
        verse <= surahCatalog[surah - 1].ayahCount;
  }

  static double getArabicFontSize() {
    final value = _prefs?.getDouble('arabic_font_size') ?? 28;
    return value.isFinite ? value.clamp(22, 42).toDouble() : 28;
  }

  static double getTranslationFontSize() =>
      _prefs?.getDouble('translation_font_size') ?? 16;
  static Future<void> setArabicFontSize(double size) async {
    await _prefs?.setDouble('arabic_font_size', size);
  }

  static Future<void> setTranslationFontSize(double size) async {
    await _prefs?.setDouble('translation_font_size', size);
  }

  static int? getLastReadSurah() => _prefs?.getInt('last_read_surah');
  static Future<void> setLastReadSurah(int value) async {
    await _prefs?.setInt('last_read_surah', value);
  }

  static int getLastReadVerse(int surah) =>
      (_prefs?.getInt('last_read_verse_$surah') ?? 1)
          .clamp(1, surahCatalog[surah - 1].ayahCount)
          .toInt();

  static Future<void> setLastReadVerse(int surah, int verse) async {
    await _prefs?.setInt('last_read_verse_$surah', verse);
    await setLastReadSurah(surah);
  }

  static ThemeMode getThemeMode() {
    switch (_prefs?.getString('theme_mode')) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs?.setString('theme_mode', mode.name);
  }

  static int getDailyTargetSeconds() =>
      _prefs?.getInt('daily_target_seconds') ?? 300;

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static int getTargetForDate(String date) {
    final snapshot = _prefs?.getInt('reading_target_$date');
    if (snapshot != null) return snapshot;
    final effective = _prefs?.getString('target_effective_date');
    return effective != null && date.compareTo(effective) < 0
        ? (_prefs?.getInt('previous_daily_target') ?? 300)
        : getDailyTargetSeconds();
  }

  static Future<void> ensureTargetSnapshot(String date) async {
    if (_prefs?.containsKey('reading_target_$date') != true) {
      await _prefs?.setInt('reading_target_$date', getTargetForDate(date));
    }
  }

  static Future<void> setDailyTargetSeconds(
    int seconds, {
    DateTime? now,
  }) async {
    if (![300, 600, 900, 1800].contains(seconds)) {
      throw ArgumentError.value(seconds);
    }
    final today = now ?? DateTime.now();
    for (final date in {...getReadingDates(), _dateKey(today)}) {
      await ensureTargetSnapshot(date);
    }
    await _prefs?.setInt(
      'previous_daily_target',
      getTargetForDate(_dateKey(today)),
    );
    await _prefs?.setString(
      'target_effective_date',
      _dateKey(DateTime(today.year, today.month, today.day + 1)),
    );
    await _prefs?.setInt('daily_target_seconds', seconds);
  }

  static int getReadingSeconds(String localDate) =>
      _prefs?.getInt('reading_seconds_$localDate') ?? 0;

  static Future<void> setReadingSeconds(String localDate, int seconds) async {
    await _prefs?.setInt('reading_seconds_$localDate', seconds);
  }

  static List<String> getReadingDates() =>
      (_prefs?.getKeys() ?? <String>{})
          .where((key) => key.startsWith('reading_seconds_'))
          .map((key) => key.substring('reading_seconds_'.length))
          .toList()
        ..sort();

  static String getPrayerCity() =>
      _prefs?.getString('prayer_city') ?? 'Jakarta';
  static String getPrayerCountry() =>
      _prefs?.getString('prayer_country') ?? 'Indonesia';
  static Future<void> setPrayerPlace(String city, String country) async {
    await _prefs?.setString('prayer_city', city.trim());
    await _prefs?.setString('prayer_country', country.trim());
  }

  static Set<String> getPrayerReminders() =>
      (_prefs?.getStringList('prayer_reminders') ?? const <String>[]).toSet();
  static Future<void> setPrayerReminders(Set<String> names) async =>
      _prefs?.setStringList('prayer_reminders', names.toList()..sort());

  static int? getQuranReminderMinutes() =>
      _prefs?.getInt('quran_reminder_minutes');
  static Future<void> setQuranReminderMinutes(int? minutes) async {
    if (minutes == null) {
      await _prefs?.remove('quran_reminder_minutes');
    } else {
      await _prefs?.setInt('quran_reminder_minutes', minutes);
    }
  }

  static Set<int> getCompletedSurahs() =>
      (_prefs?.getStringList('completed_surahs') ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .where((value) => value >= 1 && value <= 114)
          .toSet();

  static Future<void> setSurahCompleted(int surah, bool completed) async {
    final values = getCompletedSurahs();
    if (completed) {
      values.add(surah);
    } else {
      values.remove(surah);
    }
    await _prefs?.setStringList(
      'completed_surahs',
      values.map((value) => '$value').toList()..sort(),
    );
  }
}

/// Sync view of one bookmark, including deletions (tombstones).
@immutable
class BookmarkRecord {
  const BookmarkRecord({
    required this.surah,
    required this.ayah,
    required this.collection,
    required this.deleted,
    required this.updatedAtMs,
  });

  final int surah;
  final int ayah;
  final String collection;
  final bool deleted;

  /// Client clock time of the last change, in milliseconds since epoch.
  final int updatedAtMs;

  /// Stable document ID, e.g. `2_255`.
  String get id => '${surah}_$ayah';
}
