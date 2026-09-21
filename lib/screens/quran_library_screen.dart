import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/screens/quran_search_screen.dart';

class QuranLibraryScreen extends StatefulWidget {
  const QuranLibraryScreen({super.key});

  @override
  State<QuranLibraryScreen> createState() => _QuranLibraryScreenState();
}

class _QuranLibraryScreenState extends State<QuranLibraryScreen> {
  String _query = '';
  String _revelation = 'Semua';
  late Future<List<JuzBoundary>> _juz;

  @override
  void initState() {
    super.initState();
    _juz = JuzRepository.load();
  }

  @override
  Widget build(BuildContext context) {
    final results = surahCatalog
        .where((surah) {
          final query = _query.toLowerCase();
          return surah.displayName.toLowerCase().contains(query) ||
              surah.number.toString() == query;
        })
        .where(
          (surah) => _revelation == 'Semua' || surah.revelation == _revelation,
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Al-Qur’an',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.7,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: SacredTheme.gold.withValues(alpha: .25),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'OFFLINE',
                      style: TextStyle(
                        color: SacredTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QuranSearchScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.manage_search_rounded),
                    tooltip: 'Cari ayat Arab',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '114 surah siap dibaca tanpa koneksi internet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextField(
                onChanged: (value) => setState(() => _query = value.trim()),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau nomor surah',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(() => _query = ''),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Hapus pencarian',
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: ['Semua', 'Makkah', 'Madinah']
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item),
                        selected: _revelation == item,
                        onSelected: (_) => setState(() => _revelation = item),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Surah'),
                icon: Icon(Icons.menu_book_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('Juz'),
                icon: Icon(Icons.auto_stories_outlined),
              ),
            ],
            selected: {_showJuz},
            onSelectionChanged: (value) =>
                setState(() => _showJuz = value.first),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _showJuz ? _buildJuzList() : _buildSurahList(results)),
      ],
    );
  }

  bool _showJuz = false;

  Widget _buildSurahList(List<SurahMeta> results) => results.isEmpty
      ? const _EmptySearch()
      : ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _SurahRow(surah: results[index]),
        );

  Widget _buildJuzList() => FutureBuilder<List<JuzBoundary>>(
    future: _juz,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return _JuzError(
          onRetry: () => setState(() => _juz = JuzRepository.load()),
        );
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final juz = snapshot.data!;
      return ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        itemCount: juz.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _JuzRow(boundary: juz[index]),
      );
    },
  );
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 44,
            color: Theme.of(context).hintColor,
          ),
          const SizedBox(height: 12),
          const Text(
            'Surah tidak ditemukan',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Coba gunakan nama atau nomor surah.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({required this.surah});
  final SurahMeta surah;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ReaderScreen(surah: surah))),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SacredTheme.gold.withValues(alpha: .27),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${surah.number}',
                style: const TextStyle(
                  color: SacredTheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${surah.revelation} · ${surah.ayahCount} ayat',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _JuzRow extends StatelessWidget {
  const _JuzRow({required this.boundary});
  final JuzBoundary boundary;

  @override
  Widget build(BuildContext context) {
    final surah = surahCatalog[boundary.surah - 1];
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ReaderScreen(surah: surah, initialVerse: boundary.verse),
          ),
        ),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SacredTheme.primary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${boundary.number}',
                  style: const TextStyle(
                    color: SacredTheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Juz ${boundary.number}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mulai ${surah.displayName}, ayat ${boundary.verse}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _JuzError extends StatelessWidget {
  const _JuzError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Muat ulang daftar Juz'),
    ),
  );
}
