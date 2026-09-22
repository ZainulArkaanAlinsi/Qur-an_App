import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass_surface.dart';
import 'package:quran_app_2025/screens/bookmark_screen.dart';
import 'package:quran_app_2025/screens/home_screen.dart';
import 'package:quran_app_2025/screens/progress_screen.dart';
import 'package:quran_app_2025/screens/qibla_screen.dart';
import 'package:quran_app_2025/screens/quran_library_screen.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/screens/settings_screen.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
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

  /// APKs are installed outside Play, so tell users when a newer build is
  /// published on GitHub Releases (checked at most once a day).
  Future<void> _announceUpdate() async {
    final update = await UpdateCheckService.checkDaily();
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
      const ProgressScreen(),
      const SettingsScreen(),
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
              // Four labels must fit one row; cap scaling so none is clipped.
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
                      label: 'Qur’an',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights_rounded),
                      label: 'Progres',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.tune_outlined),
                      selectedIcon: Icon(Icons.tune_rounded),
                      label: 'Pengaturan',
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
