import 'package:flutter/material.dart';
import 'package:quran_app_2025/screens/home_screen.dart';
import 'package:quran_app_2025/screens/surah_details_screen.dart';
import 'package:quran_app_2025/screens/search_screen.dart';
import 'package:quran_app_2025/screens/bookmark_screen.dart';
import 'package:quran_app_2025/screens/settings_screen.dart';

class Routes {
  static const String initialRoute = '/';
  static const String surahDetails = '/surah_details';
  static const String search = '/search';
  static const String bookmarks = '/bookmarks';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> get routes {
    return {
      initialRoute: (context) => const HomeScreen(),
      surahDetails: (context) {
        final args = ModalRoute.of(context)!.settings.arguments;
        final surahNumber = args is int ? args : 1;
        return SurahDetailsScreen(surahNumber: surahNumber);
      },
      search: (context) => const SearchScreen(),
      bookmarks: (context) => const BookmarkScreen(),
      settings: (context) => const SettingsScreen(),
    };
  }

  static Future<void> navigateToSurahDetails(
    BuildContext context,
    int surahNumber,
  ) async {
    await Navigator.of(context).pushNamed(surahDetails, arguments: surahNumber);
  }
}
