import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/page_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

enum _Browse { surah, juz, halaman }

/// Ruang di bawah daftar supaya tab bar mengambang tidak menutupi baris
/// terakhir.
const _bottomInset = 132.0;

class QuranLibraryScreen extends StatefulWidget {
  const QuranLibraryScreen({super.key});

  @override
  State<QuranLibraryScreen> createState() => _QuranLibraryScreenState();
}

class _QuranLibraryScreenState extends State<QuranLibraryScreen> {
  String _query = '';
  String _revelation = 'Semua';
  _Browse _browse = _Browse.surah;
  late Future<List<JuzBoundary>> _juz = JuzRepository.load();
  late Future<List<PageBoundary>> _pages = PageRepository.load();

  List<SurahMeta> get _results {
    final query = _query.toLowerCase();
    return surahCatalog
        .where(
          (surah) =>
              surah.displayName.toLowerCase().contains(query) ||
              surah.number.toString() == query,
        )
        .where(
          (surah) => _revelation == 'Semua' || surah.revelation == _revelation,
        )
        .toList();
  }

  void _open(SurahMeta surah, {int? verse}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ReaderScreen(surah: surah, initialVerse: verse ?? 1),
          ),
        )
        .then((_) {
          if (mounted) setState(() {});
        });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LargeTitle(
          'Qur’an',
          subtitle: '114 surah · 30 juz · 604 halaman, semuanya luring',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value.trim()),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau nomor surah',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: tokens.fill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(() => _query = ''),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Hapus pencarian',
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedPill<_Browse>(
                segments: const {
                  _Browse.surah: 'Surah',
                  _Browse.juz: 'Juz',
                  _Browse.halaman: 'Halaman',
                },
                value: _browse,
                onChanged: (value) => setState(() => _browse = value),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_browse) {
            _Browse.surah => _surahList(),
            _Browse.juz => _juzList(),
            _Browse.halaman => _pageList(),
          },
        ),
      ],
    );
  }

  Widget _surahList() {
    final results = _results;
    // Riwayat hanya masuk akal pada daftar penuh; sembunyikan saat mencari.
    final recents = _query.isEmpty && _revelation == 'Semua'
        ? SharedPreferencesService.getRecentSurahs()
        : const <int>[];
    if (results.isEmpty) return const _EmptySearch();
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, _bottomInset),
      itemCount: results.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return recents.isEmpty
              ? const SizedBox.shrink()
              : _RecentStrip(surahs: recents, onOpen: _open);
        }
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: _RevelationFilter(
              value: _revelation,
              onChanged: (value) => setState(() => _revelation = value),
            ),
          );
        }
        final surah = results[index - 2];
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: _Row(
            badge: '${surah.number}',
            title: surah.displayName,
            subtitle: '${surah.revelation} · ${surah.ayahCount} ayat',
            onTap: () => _open(surah),
          ),
        );
      },
    );
  }

  Widget _juzList() => FutureBuilder<List<JuzBoundary>>(
    future: _juz,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(
          label: 'Muat ulang daftar Juz',
          onRetry: () => setState(() => _juz = JuzRepository.load()),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final juz = snapshot.data!;
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, _bottomInset),
        itemCount: juz.length,
        itemBuilder: (context, index) {
          final boundary = juz[index];
          final surah = surahCatalog[boundary.surah - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Row(
              badge: '${boundary.number}',
              title: 'Juz ${boundary.number}',
              subtitle: 'Mulai ${surah.displayName}, ayat ${boundary.verse}',
              onTap: () => _open(surah, verse: boundary.verse),
            ),
          );
        },
      );
    },
  );

  Widget _pageList() => FutureBuilder<List<PageBoundary>>(
    future: _pages,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(
          label: 'Muat ulang daftar halaman',
          onRetry: () => setState(() => _pages = PageRepository.load()),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final pages = snapshot.data!;
      return GridView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, _bottomInset),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 92,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.25,
        ),
        itemCount: pages.length,
        itemBuilder: (context, index) {
          final page = pages[index];
          final surah = surahCatalog[page.surah - 1];
          return _PageTile(
            page: page,
            surah: surah,
            onTap: () => _open(surah, verse: page.verse),
          );
        },
      );
    },
  );
}

class _RevelationFilter extends StatelessWidget {
  const _RevelationFilter({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: ['Semua', 'Makkah', 'Madinah']
        .map(
          (item) => ChoiceChip(
            label: Text(item),
            selected: value == item,
            onSelected: (_) => onChanged(item),
          ),
        )
        .toList(),
  );
}

/// Kartu kecil surah yang terakhir dibaca, lengkap dengan posisi ayatnya.
class _RecentStrip extends StatelessWidget {
  const _RecentStrip({required this.surahs, required this.onOpen});

  final List<int> surahs;
  final void Function(SurahMeta surah, {int? verse}) onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'TERAKHIR DIBACA',
            style: SacredText.eyebrow.copyWith(color: tokens.sec),
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: surahs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final surah = surahCatalog[surahs[index] - 1];
              final verse = SharedPreferencesService.getLastReadVerse(
                surah.number,
              );
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onOpen(surah, verse: verse),
                child: Container(
                  width: 162,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.surf,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: tokens.sep),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        surah.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SacredText.headline.copyWith(
                          color: tokens.ink,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Ayat $verse dari ${surah.ayahCount}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SacredText.footnote.copyWith(color: tokens.sec),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String badge;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        decoration: BoxDecoration(
          color: tokens.surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tokens.sep),
        ),
        child: Row(
          children: [
            RosetteBadge(label: badge, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SacredText.headline.copyWith(color: tokens.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: SacredText.footnote.copyWith(color: tokens.sec),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: tokens.sec),
          ],
        ),
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.page,
    required this.surah,
    required this.onTap,
  });

  final PageBoundary page;
  final SurahMeta surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tokens.surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.sep),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${page.number}',
              style: SacredText.headline.copyWith(color: tokens.ink),
            ),
            const SizedBox(height: 2),
            Text(
              surah.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: SacredText.footnote.copyWith(
                color: tokens.sec,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 0, 36, _bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 44, color: tokens.sec),
            const SizedBox(height: 12),
            Text(
              'Surah tidak ditemukan',
              style: SacredText.headline.copyWith(color: tokens.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Coba nama atau nomor surah.',
              textAlign: TextAlign.center,
              style: SacredText.footnote.copyWith(color: tokens.sec),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.label, required this.onRetry});

  final String label;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.only(bottom: _bottomInset),
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(label),
      ),
    ),
  );
}
