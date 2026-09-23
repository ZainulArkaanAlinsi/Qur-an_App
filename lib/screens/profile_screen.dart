import 'package:flutter/material.dart';
import 'package:quran_app_2025/screens/bookmark_screen.dart';
import 'package:quran_app_2025/screens/progress_screen.dart';
import 'package:quran_app_2025/screens/settings_screen.dart';

/// Tab Profil: progres bacaan di atas, pintasan bookmark dan pengaturan di
/// bawahnya. Semua data tetap lokal kecuali pengguna menyalakan sinkronisasi.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(child: ProgressScreen()),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BookmarkScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.bookmarks_outlined),
                    label: const Text('Bookmark'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Pengaturan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
