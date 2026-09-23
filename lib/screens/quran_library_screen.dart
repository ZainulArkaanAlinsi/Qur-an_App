import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/page_repository.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/screens/bookmark_screen.dart';
import 'package:quran_app_2025/screens/quran_search_screen.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

enum _Browse { surah, juz, halaman }

/// Ruang di bawah daftar supaya tab bar mengambang tidak menutupi baris
/// terakhir; tingginya sama dengan scrim di mockup.
const _bottomInset = 150.0;

/// Istilah yang dipakai mockup untuk tempat turunnya surah.
String _revelationLabel(String value) =>
    value == 'Makkah' ? 'Makkiyah' : 'Madaniyah';

/// Layar Qur'an, mengikuti `docs/design/ios-redesign/html/Quran.html`.
class QuranLibraryScreen extends StatefulWidget {
  const QuranLibraryScreen({super.key});

  @override
  State<QuranLibraryScreen> createState() => _QuranLibraryScreenState();
}

class _QuranLibraryScreenState extends State<QuranLibraryScreen> {
  final _search = TextEditingController();
  String _query = '';
  String _revelation = 'Semua';
  _Browse _browse = _Browse.surah;
  late Future<List<JuzBoundary>> _juz = JuzRepository.load();
  late Future<List<PageBoundary>> _pages = PageRepository.load();
  final Future<List<String>> _names = SuraNamesRepository.load();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
    return FutureBuilder<List<String>>(
      future: _names,
      builder: (context, namesSnapshot) {
        final names = namesSnapshot.data ?? const <String>[];
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: _bottomInset),
          children: [
            _Header(
              onBookmark: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const BookmarkScreen()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  _SearchField(
                    controller: _search,
                    revelation: _revelation,
                    onChanged: (value) => setState(() => _query = value.trim()),
                    onClear: () => setState(() {
                      _query = '';
                      _search.clear();
                    }),
                    onRevelation: (value) =>
                        setState(() => _revelation = value),
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
            if (_browse == _Browse.surah) ..._surahSection(names, tokens),
            if (_browse == _Browse.juz) _juzSection(names),
            if (_browse == _Browse.halaman) _pageSection(),
          ],
        );
      },
    );
  }

  List<Widget> _surahSection(List<String> names, SacredTokens tokens) {
    final results = _results;
    // Riwayat hanya masuk akal pada daftar penuh; sembunyikan saat mencari.
    final recents = _query.isEmpty && _revelation == 'Semua'
        ? SharedPreferencesService.getRecentSurahs()
        : const <int>[];
    return [
      if (recents.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'TERAKHIR DIBACA',
                  style: SacredText.eyebrow.copyWith(color: tokens.sec),
                ),
              ),
              if (recents.length > 2)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showAllRecents(recents, names),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Text(
                      'Lihat semua',
                      style: SacredText.linkLabel.copyWith(
                        color: tokens.primaryText,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          // Tinggi ikut skala teks; kalau dipatok, isi kartunya meluber.
          height: MediaQuery.textScalerOf(context).scale(78).clamp(78.0, 190.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _RecentCard(
              surah: surahCatalog[recents[index] - 1],
              arabicName: _arabicName(names, recents[index]),
              onTap: () => _open(
                surahCatalog[recents[index] - 1],
                verse: SharedPreferencesService.getLastReadVerse(
                  recents[index],
                ),
              ),
            ),
          ),
        ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: results.isEmpty
            ? _EmptySearch(
                query: _query,
                onSuggestion: (name) => setState(() {
                  _query = name;
                  _search.text = name;
                  _revelation = 'Semua';
                }),
                onOpenVerseSearch: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const QuranSearchScreen(),
                  ),
                ),
              )
            : _GroupedCard(
                children: [
                  for (final surah in results)
                    _SurahRow(
                      number: surah.number,
                      title: surah.displayName,
                      meta:
                          '${_revelationLabel(surah.revelation)} · '
                          '${surah.ayahCount} ayat',
                      arabicName: _arabicName(names, surah.number),
                      onTap: () => _open(surah),
                    ),
                ],
              ),
      ),
    ];
  }

  Widget _juzSection(List<String> names) => FutureBuilder<List<JuzBoundary>>(
    future: _juz,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(
          label: 'Muat ulang daftar Juz',
          onRetry: () => setState(() => _juz = JuzRepository.load()),
        );
      }
      if (!snapshot.hasData) return const _Loading();
      final juz = snapshot.data!;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: _GroupedCard(
          children: [
            for (final boundary in juz)
              _SurahRow(
                number: boundary.number,
                title: 'Juz ${boundary.number}',
                meta:
                    'Mulai ${surahCatalog[boundary.surah - 1].displayName}, '
                    'ayat ${boundary.verse}',
                arabicName: _arabicName(names, boundary.surah),
                onTap: () => _open(
                  surahCatalog[boundary.surah - 1],
                  verse: boundary.verse,
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _pageSection() => FutureBuilder<List<PageBoundary>>(
    future: _pages,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _LoadError(
          label: 'Muat ulang daftar halaman',
          onRetry: () => setState(() => _pages = PageRepository.load()),
        );
      }
      if (!snapshot.hasData) return const _Loading();
      final pages = snapshot.data!;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 92,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
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
        ),
      );
    },
  );

  static String? _arabicName(List<String> names, int surah) =>
      surah <= names.length ? names[surah - 1] : null;

  Future<void> _showAllRecents(List<int> recents, List<String> names) async {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: tokens.surf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                'TERAKHIR DIBACA',
                style: SacredText.eyebrow.copyWith(color: tokens.sec),
              ),
            ),
            _GroupedCard(
              children: [
                for (final number in recents)
                  _SurahRow(
                    number: number,
                    title: surahCatalog[number - 1].displayName,
                    meta:
                        'Ayat '
                        '${SharedPreferencesService.getLastReadVerse(number)} '
                        'dari ${surahCatalog[number - 1].ayahCount}',
                    arabicName: _arabicName(names, number),
                    onTap: () {
                      Navigator.of(context).pop();
                      _open(
                        surahCatalog[number - 1],
                        verse: SharedPreferencesService.getLastReadVerse(
                          number,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBookmark});

  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Al-Qur’an',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.screenTitle.copyWith(color: tokens.ink),
                ),
                Text(
                  '114 surah · 30 juz · 604 halaman',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.screenSubtitle.copyWith(color: tokens.sec),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SacredCircleButton(
            tooltip: 'Bookmark',
            onTap: onBookmark,
            child: LineIcon(
              SacredIcons.bookmark,
              color: tokens.ink,
              size: 20,
              strokeWidth: SacredIcons.strokeBookmark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kolom cari. Penyaring tempat turun surah ikut di sini supaya layarnya
/// tetap sebersih mockup tanpa menghilangkan penyaring yang sudah ada.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.revelation,
    required this.onChanged,
    required this.onClear,
    required this.onRevelation,
  });

  final TextEditingController controller;
  final String revelation;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onRevelation;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: tokens.fill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          LineIcon(
            SacredIcons.search,
            color: tokens.sec,
            size: 18,
            strokeWidth: SacredIcons.strokeAction,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: SacredText.searchInput.copyWith(color: tokens.ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintText: 'Surah, ayat, atau terjemahan',
                hintStyle: SacredText.searchInput.copyWith(color: tokens.sec),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Hapus pencarian',
              onPressed: onClear,
              icon: Icon(Icons.close_rounded, size: 18, color: tokens.sec),
            ),
          PopupMenuButton<String>(
            tooltip: 'Saring tempat turun',
            initialValue: revelation,
            onSelected: onRevelation,
            itemBuilder: (context) => [
              for (final option in ['Semua', 'Makkah', 'Madinah'])
                PopupMenuItem(
                  value: option,
                  child: Text(
                    option == 'Semua' ? 'Semua' : _revelationLabel(option),
                  ),
                ),
            ],
            icon: LineIcon(
              SacredIcons.sliders,
              color: revelation == 'Semua' ? tokens.sec : tokens.primaryText,
              size: 18,
              strokeWidth: SacredIcons.strokeNav,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu tunggal berisi baris-baris dengan garis rambut di antaranya, seperti
/// daftar bergaya iOS di mockup.
class _GroupedCard extends StatelessWidget {
  const _GroupedCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.sep),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F00281C),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({
    required this.number,
    required this.title,
    required this.meta,
    required this.arabicName,
    required this.onTap,
  });

  final int number;
  final String title;
  final String meta;
  final String? arabicName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      label: '$title, $meta',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Row(
              children: [
                RosetteBadge(
                  label: '$number',
                  size: 34,
                  outlined: true,
                  textColor: tokens.ink,
                  textStyle: SacredText.rosetteNumber,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: tokens.sep, width: .5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SacredText.listName.copyWith(
                                  color: tokens.ink,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SacredText.listMeta.copyWith(
                                  color: tokens.sec,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (arabicName != null) ...[
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              arabicName!,
                              textDirection: TextDirection.rtl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: SacredText.quran,
                                fontSize: 22,
                                height: 40 / 22,
                                color: tokens.primaryText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.surah,
    required this.arabicName,
    required this.onTap,
  });

  final SurahMeta surah;
  final String? arabicName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final verse = SharedPreferencesService.getLastReadVerse(surah.number);
    final fraction = (verse / surah.ayahCount).clamp(0.0, 1.0);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: tokens.surf,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: tokens.sep),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F00281C),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 58,
              child: ClipPath(
                clipper: const MihrabClipper(radius: 10),
                child: ColoredBox(
                  color: tokens.art,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GeometricPattern(
                          tile: 18,
                          opacity: .28,
                          color: tokens.artInk,
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, .45),
                        child: Text(
                          arabicName ?? '',
                          textDirection: TextDirection.rtl,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: SacredText.quran,
                            fontSize: 12,
                            color: tokens.artInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SacredText.recentName.copyWith(color: tokens.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ayat $verse dari ${surah.ayahCount}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SacredText.recentMeta.copyWith(color: tokens.sec),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 4,
                      backgroundColor: tokens.surf2,
                      valueColor: AlwaysStoppedAnimation(tokens.gold),
                    ),
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
    return Semantics(
      button: true,
      label: 'Halaman ${page.number}, ${surah.displayName}',
      child: ExcludeSemantics(
        child: InkWell(
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
                  style: SacredText.listName.copyWith(color: tokens.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  surah.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: SacredText.dayLetter.copyWith(color: tokens.sec),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    // Teks diam, bukan indikator berputar: pemuatannya dari aset bawaan dan
    // selesai seketika, sementara animasi tanpa akhir membuat layar ini tidak
    // pernah "tenang" saat diuji.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Text(
        'Memuat daftar…',
        style: SacredText.cardNote.copyWith(color: tokens.sec),
      ),
    );
  }
}

/// Keadaan pencarian kosong: menjelaskan cakupan pencarian, menawarkan
/// beberapa surah yang sering dibuka, dan menyebut sumber datanya.
class _EmptySearch extends StatelessWidget {
  const _EmptySearch({
    required this.query,
    required this.onSuggestion,
    required this.onOpenVerseSearch,
  });

  final String query;
  final ValueChanged<String> onSuggestion;
  final VoidCallback onOpenVerseSearch;

  /// Saran diambil dari katalog, bukan daftar nama yang diketik ulang.
  static const _suggested = [1, 18, 36, 55, 67];

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 120,
            child: ClipPath(
              clipper: const MihrabClipper(radius: 16),
              child: ColoredBox(
                color: tokens.goldSoft,
                child: Align(
                  alignment: const Alignment(0, .15),
                  child: LineIcon(
                    SacredIcons.search,
                    color: tokens.goldText,
                    size: 34,
                    strokeWidth: SacredIcons.strokeNav,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            query.isEmpty
                ? 'Tidak ada surah yang cocok'
                : 'Tidak ada hasil untuk “$query”',
            textAlign: TextAlign.center,
            style: SacredText.cardTitle.copyWith(color: tokens.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'Kolom ini mencari nama dan nomor surah. Untuk mencari kata di '
            'dalam ayat, gunakan pencarian ayat.',
            textAlign: TextAlign.center,
            style: SacredText.body.copyWith(color: tokens.sec),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final number in _suggested)
                _SuggestionChip(
                  label: surahCatalog[number - 1].displayName,
                  onTap: () =>
                      onSuggestion(surahCatalog[number - 1].displayName),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenVerseSearch,
            icon: LineIcon(
              SacredIcons.search,
              color: tokens.primaryText,
              size: 18,
              strokeWidth: SacredIcons.strokeAction,
            ),
            label: const Text('Cari kata di dalam ayat'),
          ),
          const SizedBox(height: 16),
          Text(
            'Sumber: Tanzil Uthmani 1.0.2 · id.indonesian',
            textAlign: TextAlign.center,
            style: SacredText.cardNote.copyWith(color: tokens.sec),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: tokens.surf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tokens.sep),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F00281C),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: SacredText.chipLabel.copyWith(color: tokens.ink),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(label),
      ),
    ),
  );
}
