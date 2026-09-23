import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass_surface.dart';
import 'package:quran_app_2025/screens/bookmark_screen.dart';
import 'package:quran_app_2025/screens/home_screen.dart';
import 'package:quran_app_2025/screens/learn_screen.dart';
import 'package:quran_app_2025/screens/memorization_screen.dart';
import 'package:quran_app_2025/screens/profile_screen.dart';
import 'package:quran_app_2025/screens/qibla_screen.dart';
import 'package:quran_app_2025/screens/quran_library_screen.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/auto_update_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:quran_app_2025/services/update_check_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quran_app_2025/widgets/audio_mini_player.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceUpdate());
  }

  /// APK diedarkan di luar Play Store. Pembaruan diperiksa dan diunduh sendiri
  /// (maksimal sekali sehari), lalu pemasang sistem dibuka. Android tetap
  /// meminta konfirmasi, dan izin "pasang aplikasi tak dikenal" hanya diminta
  /// sekali lewat tombol di bawah.
  Future<void> _announceUpdate() async {
    if (!mounted) return;
    final outcome = await AutoUpdateService(
      isSupported: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    ).run(enabled: SharedPreferencesService.getAutoUpdate());
    if (!mounted) return;
    switch (outcome) {
      case AutoUpdateOutcome.nothingToDo:
      case AutoUpdateOutcome.installerOpened:
        return;
      case AutoUpdateOutcome.needsInstallPermission:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: const Text('Pembaruan siap dipasang.'),
            action: SnackBarAction(
              label: 'Izinkan',
              onPressed: () => const ApkInstaller().openPermissionSettings(),
            ),
          ),
        );
      case AutoUpdateOutcome.failed:
        final update = await UpdateCheckService.check();
        if (update == null || !mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: Text('Versi ${update.version} tersedia.'),
            action: SnackBarAction(
              label: 'Unduh',
              onPressed: () =>
                  launchUrl(update.url, mode: LaunchMode.externalApplication),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onOpenQuran: () => setState(() => _index = 1),
        onOpenQibla: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const QiblaScreen())),
      ),
      const QuranLibraryScreen(),
      const LearnScreen(),
      const MemorizationScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AudioMiniPlayer(
              onOpen: (surah, ayah) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ReaderScreen(surah: surah, initialVerse: ayah),
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: QuranAudioService.instance.queue,
              builder: (context, queue, _) =>
                  SizedBox(height: queue == null ? 0 : 8),
            ),
            GlassSurface(
              borderRadius: BorderRadius.circular(26),
              // Five labels must fit one row; cap scaling so none is clipped.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: _index,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Beranda',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.menu_book_outlined),
                      selectedIcon: Icon(Icons.menu_book_rounded),
                      label: 'Baca',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.school_outlined),
                      selectedIcon: Icon(Icons.school_rounded),
                      label: 'Belajar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.psychology_outlined),
                      selectedIcon: Icon(Icons.psychology_rounded),
                      label: 'Hafalan',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: 'Profil',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openBookmarks(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => const BookmarkScreen()));
