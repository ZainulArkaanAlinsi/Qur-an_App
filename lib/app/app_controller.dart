import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

class AppController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  AppPalette _palette = AppPalette.sacred;
  AppPalette get palette => _palette;

  Future<void> load() async {
    _themeMode = SharedPreferencesService.getThemeMode();
    _palette = SharedPreferencesService.getPalette();
  }

  Future<void> setPalette(AppPalette palette) async {
    _palette = palette;
    notifyListeners();
    await SharedPreferencesService.setPalette(palette);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await SharedPreferencesService.setThemeMode(mode);
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope tidak ditemukan.');
    return scope!.notifier!;
  }
}
