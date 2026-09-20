import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static SharedPreferences? _prefs;

  static Future<void> init() async =>
      _prefs ??= await SharedPreferences.getInstance();
  static bool isBookmarked(int surahNumber, int verseNumber) =>
      _prefs?.getBool('bookmark_${surahNumber}_$verseNumber') ?? false;
  static Future<void> saveBookmark(int surahNumber, int verseNumber) async {
    await _prefs?.setBool('bookmark_${surahNumber}_$verseNumber', true);
  }

  static Future<void> removeBookmark(int surahNumber, int verseNumber) async {
    await _prefs?.remove('bookmark_${surahNumber}_$verseNumber');
  }

  static List<String> getBookmarks() =>
      (_prefs?.getKeys() ?? <String>{})
          .where(
            (key) =>
                key.startsWith('bookmark_') && _prefs?.getBool(key) == true,
          )
          .toList()
        ..sort();
  static double getArabicFontSize() =>
      _prefs?.getDouble('arabic_font_size') ?? 28;
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

  static Future<void> setDailyTargetSeconds(int seconds) async {
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
}
