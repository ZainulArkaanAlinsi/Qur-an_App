import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/widgets/theme_preview.dart';
import 'package:quran_app_2025/screens/settings_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(AppController controller) => AnimatedBuilder(
  animation: controller,
  builder: (context, _) => MaterialApp(
    theme: SacredTheme.themeFor(controller.palette, Brightness.light),
    builder: (context, child) =>
        AppScope(controller: controller, child: child ?? const SizedBox()),
    home: const Scaffold(body: SettingsScreen()),
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

  testWidgets('tema dipilih lewat pratinjau, tanpa kehilangan satu opsi pun', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(controller));
    await tester.pump();

    // Tiga mode dan tiga palet tetap tersedia setelah diganti pratinjau.
    expect(find.byType(ThemePreviewTile), findsNWidgets(6));
    for (final label in ['Otomatis', 'Terang', 'Gelap']) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    for (final palette in AppPalette.values) {
      expect(find.bySemanticsLabel(palette.label), findsOneWidget);
    }

    await tester.tap(find.bySemanticsLabel('Gelap'));
    await tester.pump();
    expect(controller.themeMode, ThemeMode.dark);

    await tester.tap(find.bySemanticsLabel(AppPalette.sepia.label));
    await tester.pump();
    expect(controller.palette, AppPalette.sepia);
  });
}
