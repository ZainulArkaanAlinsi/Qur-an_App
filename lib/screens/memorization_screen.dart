import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass_surface.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/memorization_status.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:quran_app_2025/widgets/memorization_tile.dart';

/// Tab Hafalan: daftar surah yang sedang dihafal beserta statusnya. Catatan
/// pribadi saja — tidak ada penilaian bacaan otomatis.
class MemorizationScreen extends StatefulWidget {
  const MemorizationScreen({super.key});

  @override
  State<MemorizationScreen> createState() => _MemorizationScreenState();
}

class _MemorizationScreenState extends State<MemorizationScreen> {
  List<int> _tracked = SharedPreferencesService.memorizationTracked();

  @override
  void initState() {
    super.initState();
    // Status juga dapat diubah dari tab Belajar, yang tetap hidup di
    // IndexedStack, jadi daftar ini ikut diperbarui.
    memorizationRevision.addListener(_refresh);
  }

  @override
  void dispose() {
    memorizationRevision.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _tracked = SharedPreferencesService.memorizationTracked());
  }

  Future<void> _addSurah() async {
    final surah = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListView.builder(
            itemCount: surahCatalog.length,
            itemBuilder: (context, index) {
              final meta = surahCatalog[index];
              return ListTile(
                leading: Text('${meta.number}'),
                title: Text(meta.displayName),
                subtitle: Text('${meta.ayahCount} ayat'),
                onTap: () => Navigator.pop(context, meta.number),
              );
            },
          ),
        ),
      ),
    );
    if (surah == null) return;
    await SharedPreferencesService.setMemorizationStatus(
      surah,
      MemorizationStatus.learning,
    );
    if (mounted) _refresh();
  }

  int _countOf(MemorizationStatus status) => _tracked
      .where(
        (surah) =>
            SharedPreferencesService.getMemorizationStatus(surah) == status,
      )
      .length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          Text('Hafalan', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Tandai sendiri surah yang sedang dihafal, sudah hafal, atau perlu '
            'murajaah. Ketuk chip status untuk mengubahnya.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          GlassSurface(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                for (final status in [
                  MemorizationStatus.learning,
                  MemorizationStatus.memorized,
                  MemorizationStatus.needsReview,
                ])
                  Expanded(
                    child: Column(
                      children: [
                        Icon(status.icon, color: theme.colorScheme.primary),
                        const SizedBox(height: 6),
                        Text(
                          '${_countOf(status)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          status.label,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_tracked.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.bookmark_add_outlined, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada surah yang ditandai.',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tambahkan surah, atau mulai dari Juz Amma di tab '
                      'Belajar.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          else
            GlassSurface(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Column(
                children: [
                  for (final surah in _tracked)
                    MemorizationTile(
                      key: ValueKey(surah),
                      surah: surah,
                      onChanged: _refresh,
                    ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSurah,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah surah'),
      ),
    );
  }
}
