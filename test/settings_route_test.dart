import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/screens/profile_screen.dart';
import 'package:quran_app_2025/screens/settings_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Meniru susunan `main.dart`: AppScope dipasang lewat `builder`, sehingga
/// halaman yang dibuka dengan Navigator.push tetap menemukannya.
Widget _app(AppController controller, Widget home) => AnimatedBuilder(
  animation: controller,
  builder: (context, _) => MaterialApp(
    theme: SacredTheme.themeFor(controller.palette, Brightness.light),
    builder: (context, child) =>
        AppScope(controller: controller, child: child ?? const SizedBox()),
    home: home,
  ),
);

void main() {
  late AppController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
    controller = AppController();
    await controller.load();
  });

  testWidgets('Pengaturan dapat dibuka dari Profil tanpa error', (
    tester,
  ) async {
    await tester.pumpWidget(_app(controller, const ProfileScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Tema aplikasi'), findsOneWidget);
  });

  testWidgets(
    'mengganti palet dari halaman Pengaturan yang dibuka sebagai route '
    'tersimpan',
    (tester) async {
      await tester.pumpWidget(_app(controller, const ProfileScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pengaturan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppPalette.sepia.label));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(controller.palette, AppPalette.sepia);
      expect(SharedPreferencesService.getPalette(), AppPalette.sepia);
    },
  );
}
