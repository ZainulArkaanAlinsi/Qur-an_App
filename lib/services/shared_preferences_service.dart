import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Bookmark methods
  static Future<void> saveBookmark(int surahNumber, int verseNumber) async {
    final key = 'bookmark_${surahNumber}_$verseNumber';
    await _prefs?.setBool(key, true);
  }

  static Future<void> removeBookmark(int surahNumber, int verseNumber) async {
    final key = 'bookmark_${surahNumber}_$verseNumber';
    await _prefs?.remove(key);
  }

  static bool isBookmarked(int surahNumber, int verseNumber) {
    final key = 'bookmark_${surahNumber}_$verseNumber';
    return _prefs?.getBool(key) ?? false;
  }

  static List<Map<String, int>> getBookmarks() {
    final keys =
        _prefs
            ?.getKeys()
            .where((key) => key.startsWith('bookmark_'))
            .toList() ??
        [];
    final bookmarks = <Map<String, int>>[];

    for (final key in keys) {
      final parts = key.split('_');
      if (parts.length == 3) {
        bookmarks.add({
          'surah': int.parse(parts[1]),
          'verse': int.parse(parts[2]),
        });
      }
    }

    return bookmarks;
  }

  // Last read methods
  static Future<void> saveLastRead(int surahNumber, int verseNumber) async {
    await _prefs?.setInt('last_read_surah', surahNumber);
    await _prefs?.setInt('last_read_verse', verseNumber);
  }

  static Map<String, int> getLastRead() {
    return {
      'surah': _prefs?.getInt('last_read_surah') ?? 1,
      'verse': _prefs?.getInt('last_read_verse') ?? 1,
    };
  }

  // Theme methods
  static Future<void> setDarkMode(bool isDark) async {
    await _prefs?.setBool('dark_mode', isDark);
  }

  static bool getDarkMode() {
    return _prefs?.getBool('dark_mode') ?? false;
  }

  // Font size methods
  static Future<void> setArabicFontSize(double size) async {
    await _prefs?.setDouble('arabic_font_size', size);
  }

  static double getArabicFontSize() {
    return _prefs?.getDouble('arabic_font_size') ?? 24.0;
  }

  static Future<void> setTranslationFontSize(double size) async {
    await _prefs?.setDouble('translation_font_size', size);
  }

  static double getTranslationFontSize() {
    return _prefs?.getDouble('translation_font_size') ?? 16.0;
  }
}
