import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/features/mushaf/data/qf_debug_mushaf_source.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_layout.dart';
import 'package:quran_app_2025/features/mushaf/presentation/mushaf_page_canvas.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_verse_panel.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

enum ReaderLayout {
  card('Card', Icons.view_agenda_outlined),
  single('1 Halaman', Icons.description_outlined),
  spread('2 Halaman', Icons.menu_book_outlined);

  const ReaderLayout(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Lebar minimum satu halaman pada mode dua halaman; di bawahnya teks terlalu
/// kecil dan pengguna ditawari mode satu halaman.
const _minSpreadPageWidth = 230.0;

/// Prototipe tiga layout baca (Fase 0), KHUSUS build debug. Data dari
/// api.quran.com dan font QCF dari CDN Quran Foundation, bukan jalur produksi.
class DebugReaderPrototypeScreen extends StatefulWidget {
  const DebugReaderPrototypeScreen({
    super.key,
    this.source,
    this.initialPage = 1,
    this.initialLayout = ReaderLayout.single,
    this.initialEdition = MushafEdition.standard,
  });

  final QfDebugMushafSource? source;
  final int initialPage;
  final ReaderLayout initialLayout;
  final MushafEdition initialEdition;

  @override
  State<DebugReaderPrototypeScreen> createState() =>
      _DebugReaderPrototypeScreenState();
}

class _DebugReaderPrototypeScreenState
    extends State<DebugReaderPrototypeScreen> {
  late final QfDebugMushafSource _source =
      widget.source ?? QfDebugMushafSource();
  late ReaderLayout _layout = widget.initialLayout;
  late MushafEdition _edition = widget.initialEdition;
  late int _page = widget.initialPage.clamp(1, mushafPageCount);
  late PageController _controller = PageController(
    initialPage: _indexFor(_page),
  );
  String? _selected;
  bool _chrome = true;
  List<JuzBoundary> _juz = const [];

  @override
  void initState() {
    super.initState();
    if (_layout == ReaderLayout.spread) _lockLandscape();
    JuzRepository.load().then((juz) {
      if (mounted) setState(() => _juz = juz);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    if (_layout == ReaderLayout.spread) _restoreOrientation();
    _controller.dispose();
    if (widget.source == null) _source.dispose();
    super.dispose();
  }

  void _lockLandscape() => SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

  void _restoreOrientation() => SystemChrome.setPreferredOrientations(const []);

  int _indexFor(int page) =>
      _layout == ReaderLayout.spread ? (page - 1) ~/ 2 : page - 1;

  int get _itemCount => _layout == ReaderLayout.spread
      ? (mushafPageCount + 1) ~/ 2
      : mushafPageCount;

  void _setLayout(ReaderLayout layout) {
    if (layout == _layout) return;
    if (layout == ReaderLayout.spread) {
      _lockLandscape();
    } else if (_layout == ReaderLayout.spread) {
      _restoreOrientation();
    }
    final old = _controller;
    setState(() {
      _layout = layout;
      _selected = null;
      _chrome = true;
      _controller = PageController(initialPage: _indexFor(_page));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _onPageChanged(int index) => setState(() {
        _page = _layout == ReaderLayout.spread ? index * 2 + 1 : index + 1;
        _selected = null;
      });

  void _onVerseTap(String key) =>
      setState(() => _selected = _selected == key ? null : key);

  int? _juzOf(String verseKey) {
    final parts = verseKey.split(':').map(int.parse).toList();
    int? juz;
    for (final boundary in _juz) {
      if (boundary.surah < parts[0] ||
          (boundary.surah == parts[0] && boundary.verse <= parts[1])) {
        juz = boundary.number;
      }
    }
    return juz;
  }

  @override
  Widget build(BuildContext context) {
    final mushaf = _layout != ReaderLayout.card;
    return Scaffold(
      appBar: _chrome
          ? AppBar(
              title: const Text('Prototipe baca (debug)'),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: _Controls(
                  layout: _layout,
                  edition: _edition,
                  onLayout: _setLayout,
                  onEdition: (edition) => setState(() => _edition = edition),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              // Ketuk area kosong (bukan kata) untuk layar penuh.
              onTap: mushaf ? () => setState(() => _chrome = !_chrome) : null,
              child: PageView.builder(
                key: ValueKey(_layout),
                controller: _controller,
                // Mushaf Arab: halaman berikutnya datang dari kiri.
                reverse: true,
                itemCount: _itemCount,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) => switch (_layout) {
                  ReaderLayout.card => _CardPage(
                      source: _source,
                      page: index + 1,
                    ),
                  ReaderLayout.single => _MushafPageItem(
                      source: _source,
                      page: index + 1,
                      edition: _edition,
                      selectedVerse: _selected,
                      onVerseTap: _onVerseTap,
                      juzOf: _juzOf,
                      zoomable: true,
                    ),
                  ReaderLayout.spread => _Spread(
                      source: _source,
                      rightPage: index * 2 + 1,
                      edition: _edition,
                      selectedVerse: _selected,
                      onVerseTap: _onVerseTap,
                      juzOf: _juzOf,
                      onUseSinglePage: () => _setLayout(ReaderLayout.single),
                    ),
                },
              ),
            ),
            if (mushaf && _selected != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _VerseToolbar(
                  verseKey: _selected!,
                  onClose: () => setState(() => _selected = null),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.layout,
    required this.edition,
    required this.onLayout,
    required this.onEdition,
  });

  final ReaderLayout layout;
  final MushafEdition edition;
  final ValueChanged<ReaderLayout> onLayout;
  final ValueChanged<MushafEdition> onEdition;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          SegmentedButton<ReaderLayout>(
            segments: [
              for (final value in ReaderLayout.values)
                ButtonSegment(
                  value: value,
                  label: Text(value.label),
                  icon: Icon(value.icon),
                ),
            ],
            selected: {layout},
            onSelectionChanged: (value) => onLayout(value.single),
          ),
          if (layout != ReaderLayout.card) ...[
            const SizedBox(width: 12),
            SegmentedButton<MushafEdition>(
              segments: [
                for (final value in MushafEdition.values)
                  ButtonSegment(value: value, label: Text(value.label)),
              ],
              selected: {edition},
              onSelectionChanged: (value) => onEdition(value.single),
            ),
          ],
        ],
      ),
    );
  }
}

typedef _PageBundle = ({
  MushafPage page,
  String font,
  Map<int, String> names,
  ({String fontFamily, List<String> glyphs})? basmalah,
});

class _MushafPageItem extends StatefulWidget {
  const _MushafPageItem({
    super.key,
    required this.source,
    required this.page,
    required this.edition,
    required this.selectedVerse,
    required this.onVerseTap,
    required this.juzOf,
    required this.zoomable,
  });

  final QfDebugMushafSource source;
  final int page;
  final MushafEdition edition;
  final String? selectedVerse;
  final ValueChanged<String> onVerseTap;
  final int? Function(String verseKey) juzOf;
  final bool zoomable;

  @override
  State<_MushafPageItem> createState() => _MushafPageItemState();
}

class _MushafPageItemState extends State<_MushafPageItem> {
  late Future<_PageBundle> _future = _load();

  @override
  void didUpdateWidget(_MushafPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.edition != widget.edition || oldWidget.page != widget.page) {
      _future = _load();
    }
  }

  Future<_PageBundle> _load() async {
    final source = widget.source;
    final results = await Future.wait<Object>([
      source.page(widget.page),
      source.ensureFont(widget.edition, widget.page),
      source.surahNames(),
    ]);
    final page = results[0] as MushafPage;
    ({String fontFamily, List<String> glyphs})? basmalah;
    if (page.lines.any((line) => line is MushafBasmalah)) {
      // Basmalah = 1:1 tanpa nomor ayat, dengan font halaman 1 edisi yang sama.
      final first = await source.page(1);
      final family = await source.ensureFont(widget.edition, 1);
      basmalah = (
        fontFamily: family,
        glyphs: [
          for (final line in first.lines.whereType<MushafTextLine>())
            for (final word in line.words)
              if (word.verseKey == '1:1' && !word.isVerseEnd) word.glyph,
        ],
      );
    }
    return (
      page: page,
      font: results[1] as String,
      names: results[2] as Map<int, String>,
      basmalah: basmalah,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PageBundle>(
      future: _future,
      builder: (context, snapshot) {
        final error = snapshot.error;
        if (error != null) {
          return _PageError(
            page: widget.page,
            error: error,
            onRetry: () => setState(() => _future = _load()),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final keys = data.page.verseKeys;
        final first = keys.isEmpty ? null : keys.first;
        final surah = first == null ? null : int.parse(first.split(':')[0]);
        final juz = first == null ? null : widget.juzOf(first);
        final canvas = FittedBox(
          fit: BoxFit.contain,
          child: MushafPageCanvas(
            page: data.page,
            fontFamily: data.font,
            surahNames: data.names,
            basmalah: data.basmalah,
            selectedVerse: widget.selectedVerse,
            onVerseTap: widget.onVerseTap,
            colorFont: widget.edition == MushafEdition.tajweed,
          ),
        );
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Text(
                [
                  if (surah != null) surahCatalog[surah - 1].displayName,
                  if (juz != null) 'Juz $juz',
                  'Hal. ${widget.page}',
                ].join(' · '),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: widget.zoomable
                    ? InteractiveViewer(
                        maxScale: 3,
                        child: Center(child: canvas),
                      )
                    : Center(child: canvas),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Spread extends StatelessWidget {
  const _Spread({
    required this.source,
    required this.rightPage,
    required this.edition,
    required this.selectedVerse,
    required this.onVerseTap,
    required this.juzOf,
    required this.onUseSinglePage,
  });

  final QfDebugMushafSource source;

  /// Halaman ganjil di kanan; halaman genap berikutnya di kiri.
  final int rightPage;
  final MushafEdition edition;
  final String? selectedVerse;
  final ValueChanged<String> onVerseTap;
  final int? Function(String) juzOf;
  final VoidCallback onUseSinglePage;

  Widget _side(int page) => page > mushafPageCount
      ? const SizedBox.expand()
      : _MushafPageItem(
          key: ValueKey(page),
          source: source,
          page: page,
          edition: edition,
          selectedVerse: selectedVerse,
          onVerseTap: onVerseTap,
          juzOf: juzOf,
          zoomable: false,
        );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth / 2 < _minSpreadPageWidth) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Layar terlalu sempit untuk dua halaman tanpa membuat '
                    'teks terlalu kecil.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onUseSinglePage,
                    child: const Text('Pakai satu halaman'),
                  ),
                ],
              ),
            ),
          );
        }
        // Urutan anak dibuat eksplisit LTR: kiri = genap, kanan = ganjil.
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              Expanded(child: _side(rightPage + 1)),
              VerticalDivider(
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Expanded(child: _side(rightPage)),
            ],
          ),
        );
      },
    );
  }
}

class _PageError extends StatelessWidget {
  const _PageError({
    required this.page,
    required this.error,
    required this.onRetry,
  });

  final int page;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final layout = error is MushafLayoutException;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              layout ? Icons.rule_rounded : Icons.cloud_off_rounded,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              layout
                  ? 'Halaman $page tidak ditampilkan: data layout dari sumber '
                      'tidak konsisten, dan aplikasi tidak menyusun halaman '
                      'tebakan.\n${(error as MushafLayoutException).message}'
                  : 'Gagal memuat halaman $page.\n$error',
              textAlign: TextAlign.center,
            ),
            if (!layout) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerseToolbar extends StatefulWidget {
  const _VerseToolbar({required this.verseKey, required this.onClose});

  final String verseKey;
  final VoidCallback onClose;

  @override
  State<_VerseToolbar> createState() => _VerseToolbarState();
}

class _VerseToolbarState extends State<_VerseToolbar> {
  int get _surah => int.parse(widget.verseKey.split(':')[0]);
  int get _ayah => int.parse(widget.verseKey.split(':')[1]);

  Future<void> _toggleBookmark() async {
    if (SharedPreferencesService.isBookmarked(_surah, _ayah)) {
      await SharedPreferencesService.removeBookmark(_surah, _ayah);
    } else {
      await SharedPreferencesService.saveBookmark(_surah, _ayah);
    }
    if (mounted) setState(() {});
  }

  Future<void> _play() async {
    try {
      await QuranAudioService.instance.toggle(surah: _surah, ayah: _ayah);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Murottal belum dapat diputar. Periksa koneksi.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookmarked = SharedPreferencesService.isBookmarked(_surah, _ayah);
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${surahCatalog[_surah - 1].displayName} · Ayat $_ayah',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: 'Putar mulai ayat ini',
              icon: const Icon(Icons.play_circle_outline_rounded),
              onPressed: _play,
            ),
            IconButton(
              tooltip: bookmarked ? 'Hapus bookmark' : 'Simpan bookmark',
              icon: Icon(
                bookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
              ),
              onPressed: _toggleBookmark,
            ),
            const IconButton(
              tooltip: 'Tafsir belum tersedia',
              icon: Icon(Icons.menu_book_outlined),
              onPressed: null,
            ),
            IconButton(
              tooltip: 'Tutup',
              icon: const Icon(Icons.close_rounded),
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }
}

typedef _CardVerse = ({
  String key,
  String markup,
  String plain,
  String? translation,
});

/// Mode Card: ayat-ayat pada halaman yang sama dengan mode mushaf, sehingga
/// posisi baca terbawa saat berganti mode.
class _CardPage extends StatefulWidget {
  const _CardPage({required this.source, required this.page});

  final QfDebugMushafSource source;
  final int page;

  @override
  State<_CardPage> createState() => _CardPageState();
}

class _CardPageState extends State<_CardPage> {
  late Future<List<_CardVerse>> _future = _load();

  Future<List<_CardVerse>> _load() async {
    final source = widget.source;
    final page = await source.page(widget.page);
    final result = <_CardVerse>[];
    for (final surah in page.surahs) {
      final data = await Future.wait([
        source.tajweedMarkup(surah),
        source.uthmani(surah),
      ]);
      List<String>? translation;
      try {
        translation = await TranslationRepository.instance.forSurah(surah);
      } catch (_) {
        translation = null;
      }
      for (final key in page.verseKeys) {
        final parts = key.split(':').map(int.parse).toList();
        if (parts[0] != surah) continue;
        final markup = data[0][key];
        final plain = data[1][key];
        if (markup == null || plain == null) {
          throw FormatException('Ayat $key tidak ada di respons provider');
        }
        final index = parts[1] - 1;
        result.add((
          key: key,
          markup: markup,
          plain: plain,
          translation: translation != null && index < translation.length
              ? translation[index]
              : null,
        ));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_CardVerse>>(
      future: _future,
      builder: (context, snapshot) {
        final error = snapshot.error;
        if (error != null) {
          return _PageError(
            page: widget.page,
            error: error,
            onRetry: () => setState(() => _future = _load()),
          );
        }
        final verses = snapshot.data;
        if (verses == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Hal. ${widget.page} · Teks Arab: edisi Quran Foundation '
              '(text_uthmani_tajweed). Terjemahan: Kemenag via Tanzil (2010).',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final verse in verses) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CardHeader(verseKey: verse.key),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TajweedVersePanel(
                          verseKey: verse.key,
                          markup: verse.markup,
                          fallbackText: verse.plain,
                          fallbackEditionLabel:
                              'QF text_uthmani (encoding berbeda)',
                          arabicStyle: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize:
                                SharedPreferencesService.getArabicFontSize(),
                            height: 2.0,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      if (verse.translation != null) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            verse.translation!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _CardHeader extends StatefulWidget {
  const _CardHeader({required this.verseKey});

  final String verseKey;

  @override
  State<_CardHeader> createState() => _CardHeaderState();
}

class _CardHeaderState extends State<_CardHeader> {
  @override
  Widget build(BuildContext context) {
    final parts = widget.verseKey.split(':').map(int.parse).toList();
    final bookmarked = SharedPreferencesService.isBookmarked(
      parts[0],
      parts[1],
    );
    return Row(
      children: [
        Text(
          widget.verseKey,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
        ),
        const Spacer(),
        IconButton(
          tooltip: bookmarked ? 'Hapus bookmark' : 'Simpan bookmark',
          icon: Icon(
            bookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
          ),
          onPressed: () async {
            if (bookmarked) {
              await SharedPreferencesService.removeBookmark(
                parts[0],
                parts[1],
              );
            } else {
              await SharedPreferencesService.saveBookmark(parts[0], parts[1]);
            }
            if (mounted) setState(() {});
          },
        ),
        IconButton(
          tooltip: 'Putar mulai ayat ini',
          icon: const Icon(Icons.play_circle_outline_rounded),
          onPressed: () => QuranAudioService.instance
              .toggle(surah: parts[0], ayah: parts[1])
              .catchError((Object _) {}),
        ),
      ],
    );
  }
}
