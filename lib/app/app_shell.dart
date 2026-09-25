import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/distribution.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/screens/bookmark_screen.dart';
import 'package:quran_app_2025/screens/home_screen.dart';
import 'package:quran_app_2025/screens/learn_screen.dart';
import 'package:quran_app_2025/screens/memorization_screen.dart';
import 'package:quran_app_2025/screens/quran_library_screen.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/screens/settings_screen.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/auto_update_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:quran_app_2025/services/update_check_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quran_app_2025/widgets/audio_mini_player.dart';

const _tabs = [
  SacredTab(icon: SacredIcons.home, label: 'Beranda'),
  SacredTab(icon: SacredIcons.book, label: 'Qur’an'),
  SacredTab(icon: SacredIcons.cap, label: 'Belajar'),
  SacredTab(icon: SacredIcons.layers, label: 'Hafalan'),
  SacredTab(icon: SacredIcons.user, label: 'Saya'),
];

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  /// Tab pertama yang terbuka, mis. Belajar/Hafalan sesuai pilihan
  /// onboarding.
  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex.clamp(0, _tabs.length - 1);

  @override
  void initState() {
    super.initState();
    // Build Google Play diperbarui lewat Play (lib/app/distribution.dart).
    if (isGithubBuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _announceUpdate());
    }
  }

  /// Build GitHub Releases: pembaruan diperiksa dan diunduh sendiri
  /// (maksimal sekali sehari), lalu pemasang sistem dibuka. Android tetap
  /// meminta konfirmasi, dan izin "pasang aplikasi tak dikenal" hanya diminta
  /// sekali lewat tombol di bawah.
  Future<void> _announceUpdate() async {
    if (!mounted) return;
    final updater = AutoUpdateService(
      isSupported: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    );
    final outcome = await updater.run(
      enabled: SharedPreferencesService.getAutoUpdate(),
    );
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
              // Setelah izin diberikan, langsung pasang berkas yang sudah
              // diunduh; jangan menunggu pemeriksaan besok.
              onPressed: () async {
                final update = updater.lastUpdate;
                if (update == null) return;
                await updater.installAfterPermission(update);
              },
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
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final pages = [
      HomeScreen(
        onOpenQuran: () => setState(() => _index = 1),
        onOpenLearn: () => setState(() => _index = 2),
        onOpenHafalan: () => setState(() => _index = 3),
      ),
      const QuranLibraryScreen(),
      const LearnScreen(),
      const MemorizationScreen(),
      // Tab Saya: profil, progres, dan pengaturan (docs/design/v2/screens/
      // 12-saya.md). Progres lengkap dibuka dari baris di dalamnya.
      const SettingsScreen(),
    ];
    return Scaffold(
      backgroundColor: tokens.bg,
      // Tab bar mengambang di atas isi layar; tiap halaman menyisakan ruang
      // kosong di bawah daftarnya sendiri supaya tidak ada yang tertutup.
      // Satu BackdropGroup: tab bar dan mini player berbagi satu tangkapan
      // backdrop (LIQUID_GLASS.md §7).
      body: BackdropGroup(
        child: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: IndexedStack(index: _index, children: pages),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Jeda 8 di atas tab bar supaya dua kaca tidak saling
                  // menempel tepinya.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: AudioMiniPlayer(
                      onOpen: (surah, ayah) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ReaderScreen(surah: surah, initialVerse: ayah),
                        ),
                      ),
                    ),
                  ),
                  FloatingTabBar(
                    tabs: _tabs,
                    currentIndex: _index,
                    onSelected: (value) => setState(() => _index = value),
                  ),
                ],
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
