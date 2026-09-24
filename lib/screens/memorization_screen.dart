import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass_surface.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/hafalan/domain/murajaah_schedule.dart';
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
  List<AyahMemorization> _due = dueForReview(
    SharedPreferencesService.allAyahMemorization(),
    DateTime.now(),
  );

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
    setState(() {
      _tracked = SharedPreferencesService.memorizationTracked();
      _due = dueForReview(
        SharedPreferencesService.allAyahMemorization(),
        DateTime.now(),
      );
    });
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
          const _GlossaryCard(),
          const SizedBox(height: 12),
          _MurajaahCard(due: _due),
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
                      'Ketuk Tambah surah. Juz Amma (An-Naba’ sampai '
                      'An-Nas) cocok untuk memulai.',
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

/// Menjelaskan tiga istilah yang dipakai layar ini, supaya orang yang baru
/// mulai menghafal tahu bedanya tanpa harus bertanya.
class _GlossaryCard extends StatelessWidget {
  const _GlossaryCard();

  static const _terms = [
    ('Ziyadah', 'Menambah hafalan baru.'),
    ('Murajaah', 'Mengulang yang sudah dihafal supaya tidak lupa.'),
    ('Tasmi’', 'Menyetorkan hafalan — ke guru, atau menguji diri sendiri.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (term, meaning) in _terms)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$term — ',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: meaning),
                  ],
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Ayat yang jatuh tempo diulang hari ini, beserta aturan jadwalnya ditulis
/// apa adanya — jadwalnya bisa dijelaskan, bukan angka yang muncul entah dari
/// mana.
class _MurajaahCard extends StatelessWidget {
  const _MurajaahCard({required this.due});

  final List<AyahMemorization> due;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_repeat_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Murajaah hari ini',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                due.isEmpty ? '—' : '${due.length} ayat',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            due.isEmpty
                ? 'Belum ada ayat yang dijadwalkan. Jadwal mulai berjalan '
                      'setelah kamu menandai hasil murajaah di layar latihan.'
                : 'Paling lama menunggu: ${due.first.verseKey}.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Jaraknya naik ${MurajaahSchedule.ladder.join(' → ')} hari saat '
            'lancar, tetap saat ragu, dan kembali ke 1 hari saat salah.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
