import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/screens/settings_screen.dart';
import 'package:quran_app_2025/services/cloud_sync_service.dart';
import 'package:quran_app_2025/services/firebase_sync.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tidak pernah dipanggil: sinkron hanya jalan setelah masuk.
class _UnusedRemote implements SyncRemote {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _app(AppController controller) => MaterialApp(
  theme: SacredTheme.themeFor(controller.palette, Brightness.light),
  builder: (context, child) =>
      AppScope(controller: controller, child: child ?? const SizedBox()),
  home: const Scaffold(body: SafeArea(child: SettingsScreen())),
);

void main() {
  late AppController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferencesService.init();
    controller = AppController();
    await controller.load();
  });

  // Kartu akun ada di lembar bawah. Pesan gagal masuk dulu memakai SnackBar
  // milik halaman di belakang lembar, sehingga tertutup dan pengguna hanya
  // melihat jendela Google tertutup tanpa penjelasan (1.10.1 di Play,
  // 3 Oktober 2026).
  testWidgets('pesan gagal masuk tampil di dalam lembar akun', (tester) async {
    final service = AccountService.instance;
    service.available = true;
    service.sync = CloudSyncService(_UnusedRemote());
    addTearDown(() {
      service.available = false;
      service.sync = null;
    });

    await tester.pumpWidget(_app(controller));
    await tester.tap(find.text('Belum masuk'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);

    // Di tes, plugin Google tidak terpasang sehingga authenticate() melempar
    // galat yang bukan GoogleSignInException. Galat seperti ini dulu lolos
    // tanpa pesan sama sekali.
    await tester.tap(find.text('Masuk dengan Google'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Masuk dengan Google gagal. Coba lagi.'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
