import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/app_shell.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:quran_app_2025/services/reminder_service.dart';
import 'package:quran_app_2025/services/app_update_service.dart';
import 'package:quran_app_2025/services/firebase_sync.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferencesService.init();
  try {
    await ReminderService.instance.initialize().timeout(
      const Duration(seconds: 10),
    );
  } on Object catch (error) {
    // Reminders are optional; reading must still start.
    debugPrint('Pengingat tidak aktif: $error');
  }
  await QuranAudioService.instance.initSystemControls();
  // Optional cloud sync; the app works fully offline if this fails.
  await AccountService.instance.init();
  final controller = AppController();
  await controller.load();
  runApp(QuranApp(controller: controller));
  unawaited(AppUpdateService.checkOnLaunch());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      title: 'Ruang Tilawah',
      debugShowCheckedModeBanner: false,
      theme: SacredTheme.themeFor(controller.palette, Brightness.light),
      darkTheme: SacredTheme.themeFor(controller.palette, Brightness.dark),
      themeMode: controller.themeMode,
      home: AppScope(controller: controller, child: const AppShell()),
    ),
  );
}
