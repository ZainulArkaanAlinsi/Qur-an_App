import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Bookmark methods
  static bool isBookmarked(int surahNumber, int verseNumber) {
    return _prefs?.getBool('bookmark_${surahNumber}_$verseNumber') ?? false;
  }

  static Future<void> saveBookmark(int surahNumber, int verseNumber) async {
    await _prefs?.setBool('bookmark_${surahNumber}_$verseNumber', true);
  }

  static Future<void> removeBookmark(int surahNumber, int verseNumber) async {
    await _prefs?.remove('bookmark_${surahNumber}_$verseNumber');
  }

  // Font size methods
  static double getArabicFontSize() {
    return _prefs?.getDouble('arabic_font_size') ?? 24.0;
  }

  static double getTranslationFontSize() {
    return _prefs?.getDouble('translation_font_size') ?? 16.0;
  }

  static Future<void> setArabicFontSize(double size) async {
    await _prefs?.setDouble('arabic_font_size', size);
  }

  static Future<void> setTranslationFontSize(double size) async {
    await _prefs?.setDouble('translation_font_size', size);
  }
}
