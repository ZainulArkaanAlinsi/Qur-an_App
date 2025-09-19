import 'package:flutter/widgets.dart';
import 'package:quran_app_2025/screens/home_screen.dart';
import 'package:quran_app_2025/screens/surah_details_screen.dart';

class Routes {
  static const String initalRoute = HomeScreen.routeName;

  static final Map<String, Widget Function(BuildContext)> routes = {
    HomeScreen.routeName: (context) => HomeScreen(),
    // Tambahkan rute lain di sini jika diperlukan
    SurahDetailsScreen.routeName: (context) {
      final int surahNumber = ModalRoute.of(context)!.settings.arguments as int;
      return SurahDetailsScreen(surahNumber: surahNumber);
    },
  };
}
