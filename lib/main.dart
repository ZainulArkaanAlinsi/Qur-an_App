import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/app_entry.dart';
import 'package:quran_app_2025/app/distribution.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:quran_app_2025/services/reminder_service.dart';
import 'package:quran_app_2025/services/app_update_service.dart';
import 'package:quran_app_2025/services/firebase_sync.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Preferensi dan tema dibutuhkan frame pertama (tema, status onboarding).
  await SharedPreferencesService.init();
  final controller = AppController();
  await controller.load();
  _registerFontLicenses();
  // Layanan lain disiapkan sambil splash animasi berjalan; splash menunggu
  // paling lama 2,5 detik lalu lanjut (docs/design/v3/DESIGN.md §4b).
  final ready = _startServices();
  runApp(QuranApp(controller: controller, ready: ready));
  // Build Play diperbarui lewat Play; build GitHub punya pengunduhnya sendiri.
  if (!isGithubBuild) unawaited(AppUpdateService.checkOnLaunch());
}

/// Pengingat, kontrol murottal sistem, dan sinkronisasi cloud. Masing-masing
/// opsional: kegagalannya tidak boleh menghentikan aplikasi.
Future<void> _startServices() async {
  // Tiap layanan dijaga sendiri: gagalnya satu tidak melewatkan yang lain.
  try {
    await ReminderService.instance.initialize().timeout(
      const Duration(seconds: 10),
    );
  } on Object catch (error) {
    debugPrint('Pengingat tidak aktif: $error');
  }
  try {
    await QuranAudioService.instance.initSystemControls();
  } on Object catch (error) {
    debugPrint('Kontrol murottal sistem tidak aktif: $error');
  }
  try {
    await AccountService.instance.init();
  } on Object catch (error) {
    debugPrint('Sinkronisasi cloud tidak aktif: $error');
  }
}

/// Font yang dibundel berlisensi SIL OFL 1.1; teks lisensinya wajib ikut
/// dan tampil di halaman lisensi aplikasi (docs/design/v3/LISENSI_ASET.md §2).
void _registerFontLicenses() {
  const fonts = {
    'Plus Jakarta Sans': 'OFL-PlusJakartaSans.txt',
    'EB Garamond': 'OFL-EBGaramond.txt',
    'Amiri': 'OFL-Amiri.txt',
    'Amiri Quran': 'OFL-AmiriQuran.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: family, value: file) in fonts.entries) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key, required this.controller, required this.ready});
  final AppController controller;
  final Future<void> ready;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      title: 'MyQuran',
      debugShowCheckedModeBanner: false,
      theme: SacredTheme.themeFor(controller.palette, Brightness.light),
      darkTheme: SacredTheme.themeFor(controller.palette, Brightness.dark),
      themeMode: controller.themeMode,
      // AppScope harus berada di atas Navigator, bukan di dalam `home`:
      // halaman yang dibuka lewat Navigator.push adalah route lain dan tidak
      // akan menemukannya bila dipasang di dalam home.
      builder: (context, child) =>
          AppScope(controller: controller, child: child ?? const SizedBox()),
      home: AppEntry(ready: ready),
    ),
  );
}
