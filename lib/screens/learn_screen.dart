import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass_surface.dart';
import 'package:quran_app_2025/widgets/memorization_tile.dart';

/// Tab Belajar. Saat ini berisi hub Juz Amma yang memakai teks Al-Qur'an yang
/// sudah dibundel. Akademi Tajwid dan Belajar Membaca belum ditampilkan karena
/// materinya wajib melalui review guru terlebih dahulu
/// (docs/RELIGIOUS_CONTENT_GOVERNANCE.md).
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  /// Juz 30 dimulai dari An-Naba (78) sampai An-Nas (114).
  static const _juzAmmaStart = 78;
  static const _juzAmmaEnd = 114;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('Belajar', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Mulai dari Juz Amma: surah pendek yang paling sering dibaca.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        GlassSurface(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.auto_stories_outlined),
                    const SizedBox(width: 8),
                    Text(
                      'Juz Amma',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_juzAmmaEnd - _juzAmmaStart + 1} surah',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (var surah = _juzAmmaStart; surah <= _juzAmmaEnd; surah++)
                MemorizationTile(surah: surah),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _ComingSoonCard(
          icon: Icons.color_lens_outlined,
          title: 'Akademi Tajwid',
          body:
              'Materi hukum tajwid beserta contoh bacaan sedang disiapkan. '
              'Belum ditampilkan karena setiap materi harus diperiksa guru '
              'tajwid sebelum dirilis.',
        ),
        const SizedBox(height: 12),
        const _ComingSoonCard(
          icon: Icons.abc_rounded,
          title: 'Belajar Membaca Al-Qur’an',
          body:
              'Kurikulum dari pengenalan huruf hijaiyah sampai potongan ayat, '
              'dengan audio guru. Menunggu penyusunan materi dan review.',
        ),
      ],
    );
  }
}

/// Kartu yang jujur menyebut fitur belum tersedia, bukan tombol kosong.
class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('Belum tersedia'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(body, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
