import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/screens/settings_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Meniru susunan `main.dart`: AppScope dipasang lewat `builder`, sehingga
/// halaman yang dibuka dengan Navigator.push tetap menemukannya.
///
/// Versi 1.2.0 sempat memasang AppScope di dalam `home`, dan setiap halaman
/// yang di-push gagal menemukannya. Tes ini menjaga itu tidak terulang.
Widget _app(AppController controller) => AnimatedBuilder(
  animation: controller,
  builder: (context, _) => MaterialApp(
    theme: SacredTheme.themeFor(controller.palette, Brightness.light),
    builder: (context, child) =>
        AppScope(controller: controller, child: child ?? const SizedBox()),
    home: const _Host(),
  ),
);

/// Mewakili halaman mana pun yang membuka Pengaturan lewat Navigator.push.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            // Pengaturan adalah daftar tanpa Scaffold sendiri, jadi route-nya
            // yang menyediakan Material dan AppBar.
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Pengaturan')),
              body: const SafeArea(child: SettingsScreen()),
            ),
          ),
        ),
        child: const Text('Buka Pengaturan'),
      ),
    ),
  );
}

void main() {
  late AppController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
    controller = AppController();
    await controller.load();
  });

  testWidgets('Pengaturan yang dibuka sebagai route menemukan AppScope', (
    tester,
  ) async {
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buka Pengaturan'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsScreen), findsOneWidget);
    // Judul kelompok pada mockup ditulis kapital.
    expect(find.text('TAMPILAN'), findsOneWidget);
  });

  testWidgets('mengganti palet dari route Pengaturan tersimpan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka Pengaturan'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(AppPalette.sepia.label));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.palette, AppPalette.sepia);
    expect(SharedPreferencesService.getPalette(), AppPalette.sepia);
  });
}
