import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/app_shell.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:quran_app_2025/services/reminder_service.dart';
import 'package:quran_app_2025/services/app_update_service.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferencesService.init();
  await ReminderService.instance.initialize();
  await QuranAudioService.instance.initSystemControls();
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
      title: 'Qur’an',
      debugShowCheckedModeBanner: false,
      theme: SacredTheme.light,
      darkTheme: SacredTheme.dark,
      themeMode: controller.themeMode,
      home: AppScope(controller: controller, child: const AppShell()),
    ),
  );
}
