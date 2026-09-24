import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_layout.dart';
import 'package:quran_app_2025/features/mushaf/domain/mushaf_text.dart';
import 'package:quran_app_2025/features/mushaf/presentation/mushaf_page_view.dart';
import 'package:quran_app_2025/features/mushaf/presentation/mushaf_tokens.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_repository.dart';
import 'package:quran_app_2025/features/tajweed/domain/tajweed_rule.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_legend_screen.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_palette.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Tata letak satu halaman (15 baris) dari sumber yang sah.
typedef MushafLayoutLoader = Future<MushafPage> Function(int page);

/// Halaman siap tampil beserta pelengkapnya.
class MushafPageData {
  const MushafPageData({
    required this.page,
    required this.arabicNames,
    this.tajweed = const {},
    this.juz,
  });

  final MushafComposedPage page;
  final List<String> arabicNames;
  final Map<String, TajweedVerse> tajweed;
  final int? juz;
}

/// Memuat dan menyusun satu halaman: layout + teks Tanzil + tajwid cpfair.
Future<MushafPageData> loadMushafPage(
  int number,
  MushafLayoutLoader layout, {
  bool tajweed = true,
}) async {
  final page = await layout(number);
  final surahs = {
    for (final line in page.lines)
      if (line is MushafTextLine)
        for (final word in line.words) word.surah,
  };
  final fatihah = await QuranTextRepository.instance.versesForSurah(1);
  final verses = {
    for (final surah in surahs)
      surah: await QuranTextRepository.instance.versesForSurah(surah),
  };
  final composed = composeMushafPage(page, verses, fatihah.first);

  // Warna tajwid dan juz hanya pelengkap: kegagalannya tidak menutup halaman.
  final colored = <String, TajweedVerse>{};
  if (tajweed) {
    try {
      for (final surah in surahs) {
        for (final verse in await TajweedRepository.instance.forSurah(surah)) {
          colored[verse.verseKey] = verse;
        }
      }
    } on Object {
      colored.clear();
    }
  }
  int? juz;
  final first = composed.firstItem;
  if (first != null) {
    try {
      for (final boundary in await JuzRepository.load()) {
        if (boundary.surah < first.surah ||
            (boundary.surah == first.surah && boundary.verse <= first.ayah)) {
          juz = boundary.number;
        }
      }
    } on Object {
      juz = null;
    }
  }
  return MushafPageData(
    page: composed,
    arabicNames: await SuraNamesRepository.load(),
    tajweed: colored,
    juz: juz,
  );
}

/// Mushaf 1 halaman (03) dan 2 halaman saat HP dimiringkan (04).
///
/// Halaman digeser seperti mushaf: halaman berikutnya datang dari kiri.
/// Data layout disuntikkan; tanpa data yang sah layar ini tidak dibuka.
class MushafScreen extends StatefulWidget {
  const MushafScreen({
    super.key,
    required this.initialPage,
    required this.layout,
    this.twoPages = true,
    this.onReadingMode,
  });

  final int initialPage;
  final MushafLayoutLoader layout;

  /// Tampilkan dua halaman saat HP mendatar dan cukup lebar.
  final bool twoPages;

  /// Tombol Aa: lembar Tampilan baca milik pemanggil.
  final void Function(BuildContext context)? onReadingMode;

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  late int _page = widget.initialPage.clamp(1, mushafPageCount).toInt();
  late bool _twoPages = widget.twoPages;
  final _cache = <int, Future<MushafPageData>>{};
  PageController? _controller;
  bool? _spread;

  Future<MushafPageData> _data(int number) => _cache.putIfAbsent(
    number,
    () => loadMushafPage(
      number,
      widget.layout,
      tajweed: SharedPreferencesService.getReaderTajweed(),
    ),
  );

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Pengendali halaman untuk mode yang sedang dipakai; mempertahankan
  /// halaman saat berpindah 1 ↔ 2 halaman.
  PageController _controllerFor(bool spread) {
    if (_spread != spread || _controller == null) {
      _controller?.dispose();
      _controller = PageController(
        initialPage: spread ? (_page - 1) ~/ 2 : _page - 1,
      );
      _spread = spread;
    }
    return _controller!;
  }

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _play() async {
    try {
      final data = await _data(_page);
      final first = data.page.firstItem;
      if (first == null) return;
      await QuranAudioService.instance.toggle(
        surah: first.surah,
        ayah: first.ayah,
      );
    } on Object {
      if (mounted) _say('Murottal belum bisa diputar. Periksa koneksi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final colors = MushafTokens.of(Theme.of(context).brightness);
    return Scaffold(
      backgroundColor: colors.backdrop,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final landscape = constraints.maxWidth > constraints.maxHeight;
            // Dua halaman hanya bila tiap halaman tetap ≥ 230 dp.
            final spread =
                _twoPages &&
                landscape &&
                (constraints.maxWidth - 30) / 2 >= 230;
            final controller = _controllerFor(spread);
            if (spread) {
              // Dua halaman (04): halaman memenuhi layar, hanya tombol kecil
              // di pojok untuk kembali ke satu halaman.
              return Stack(
                children: [
                  Positioned.fill(
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: PageView.builder(
                        controller: controller,
                        itemCount: (mushafPageCount + 1) ~/ 2,
                        onPageChanged: (index) =>
                            setState(() => _page = index * 2 + 1),
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _Spread(
                            // Halaman ganjil di kanan, genap di kiri.
                            right: index * 2 + 1,
                            left: index * 2 + 2,
                            data: _data,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 8,
                    child: _RoundButton(
                      tooltip: 'Kembali ke satu halaman',
                      icon: SacredIcons.pageSingle,
                      onTap: () => setState(() => _twoPages = false),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                FutureBuilder<MushafPageData>(
                  future: _data(_page),
                  builder: (context, snapshot) => _Header(
                    data: snapshot.data,
                    page: _page,
                    onBack: () => Navigator.of(context).maybePop(),
                    onDisplay: widget.onReadingMode == null
                        ? null
                        : () => widget.onReadingMode!(context),
                  ),
                ),
                Expanded(
                  child: Directionality(
                    // Seperti mushaf: halaman berikutnya datang dari kiri.
                    textDirection: TextDirection.rtl,
                    child: PageView.builder(
                      controller: controller,
                      itemCount: spread
                          ? (mushafPageCount + 1) ~/ 2
                          : mushafPageCount,
                      onPageChanged: (index) => setState(
                        () => _page = spread ? index * 2 + 1 : index + 1,
                      ),
                      itemBuilder: (context, index) => spread
                          ? _Spread(
                              // Halaman ganjil di kanan, genap di kiri.
                              right: index * 2 + 1,
                              left: index * 2 + 2,
                              data: _data,
                            )
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                              child: _PageSlot(number: index + 1, data: _data),
                            ),
                    ),
                  ),
                ),
                _BottomBar(
                  tokens: tokens,
                  twoPages: spread,
                  onTajweed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const TajweedLegendScreen(backLabel: 'Mushaf'),
                    ),
                  ),
                  onPlay: () => unawaited(_play()),
                  onTwoPages: () {
                    if (!landscape) {
                      _say('Miringkan HP untuk membaca dua halaman.');
                      setState(() => _twoPages = true);
                      return;
                    }
                    setState(() => _twoPages = !_twoPages);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.data,
    required this.page,
    required this.onBack,
    required this.onDisplay,
  });

  final MushafPageData? data;
  final int page;
  final VoidCallback onBack;
  final VoidCallback? onDisplay;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final surahs = data?.page.surahs ?? const <int>[];
    final title = surahs.isEmpty
        ? 'Mushaf'
        : [
            surahCatalog[surahs.first - 1].displayName,
            if (surahs.length > 1) surahCatalog[surahs.last - 1].displayName,
          ].join(' – ');
    final juz = data?.juz;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Row(
        children: [
          _RoundButton(
            tooltip: 'Kembali',
            icon: SacredIcons.chevronLeft,
            onTap: onBack,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.navTitle.copyWith(
                    color: tokens.ink,
                    fontSize: 14,
                  ),
                ),
                Text(
                  [if (juz != null) 'Juz $juz', 'Halaman $page'].join(' · '),
                  textAlign: TextAlign.center,
                  style: SacredText.navSubtitle.copyWith(color: tokens.sec),
                ),
              ],
            ),
          ),
          if (onDisplay != null)
            _RoundButton(
              tooltip: 'Tampilan baca',
              icon: SacredIcons.textSize,
              onTap: onDisplay!,
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final List<String> icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.fill,
              shape: BoxShape.circle,
            ),
            child: LineIcon(
              icon,
              color: tokens.ink,
              size: 20,
              strokeWidth: 2.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu halaman: memuat, gagal dengan jujur, atau tampil.
class _PageSlot extends StatelessWidget {
  const _PageSlot({required this.number, required this.data});

  final int number;
  final Future<MushafPageData> Function(int) data;

  @override
  Widget build(BuildContext context) => FutureBuilder<MushafPageData>(
    future: data(number),
    builder: (context, snapshot) {
      final loaded = snapshot.data;
      if (loaded != null) {
        return MushafPageView(
          page: loaded.page,
          arabicNames: loaded.arabicNames,
          tajweed: loaded.tajweed,
          juz: loaded.juz,
        );
      }
      final tokens = Theme.of(context).extension<SacredTokens>()!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            snapshot.hasError
                ? 'Halaman $number belum bisa ditampilkan persis mushaf. '
                      'Data tata letaknya tidak tersedia atau tidak lolos '
                      'pemeriksaan.'
                : 'Memuat halaman $number…',
            textAlign: TextAlign.center,
            style: SacredText.body.copyWith(color: tokens.sec),
          ),
        ),
      );
    },
  );
}

/// Dua halaman seperti mushaf terbuka, dengan bayangan lipatan di tengah.
class _Spread extends StatelessWidget {
  const _Spread({required this.right, required this.left, required this.data});

  final int right;
  final int left;
  final Future<MushafPageData> Function(int) data;

  @override
  Widget build(BuildContext context) {
    final colors = MushafTokens.of(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Row(
        // Dalam RTL anak pertama di kanan: halaman ganjil.
        children: [
          Expanded(
            child: _PageSlot(number: right, data: data),
          ),
          Container(
            width: 10,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.ink.withValues(alpha: 0),
                  colors.ink.withValues(alpha: .14),
                  colors.ink.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          if (left <= mushafPageCount)
            Expanded(
              child: _PageSlot(number: left, data: data),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.tokens,
    required this.twoPages,
    required this.onTajweed,
    required this.onPlay,
    required this.onTwoPages,
  });

  final SacredTokens tokens;
  final bool twoPages;
  final VoidCallback onTajweed;
  final VoidCallback onPlay;
  final VoidCallback onTwoPages;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    const palette = TajweedPalette.draftPreview;
    // Teks sangat besar: pil cukup ikon (label tetap dibacakan), supaya
    // tidak ada label yang terpotong.
    final compact = MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6;
    Widget dot(TajweedRule rule) => Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(right: 2),
      decoration: BoxDecoration(
        color: palette.colorFor(rule, brightness),
        shape: BoxShape.circle,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: tokens.surf,
          borderRadius: BorderRadius.circular(28),
          boxShadow: tokens.floatShadows,
        ),
        child: Row(
          children: [
            _Pill(
              label: compact ? null : 'Tajwid',
              semantics: 'Arti warna tajwid',
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  dot(TajweedRule.qalqalah),
                  dot(TajweedRule.idghamBighunnah),
                  dot(TajweedRule.madThabii),
                ],
              ),
              onTap: onTajweed,
            ),
            const Spacer(),
            Semantics(
              button: true,
              label: 'Putar murottal halaman ini',
              excludeSemantics: true,
              child: InkResponse(
                onTap: onPlay,
                radius: 26,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.cta,
                    shape: BoxShape.circle,
                  ),
                  child: LineIcon(
                    SacredIcons.play,
                    color: tokens.ctaInk,
                    size: 17,
                    filled: true,
                  ),
                ),
              ),
            ),
            const Spacer(),
            _Pill(
              label: compact ? null : (twoPages ? '1 halaman' : '2 halaman'),
              semantics: twoPages
                  ? 'Kembali ke satu halaman'
                  : 'Dua halaman, miringkan HP',
              leading: LineIcon(
                twoPages ? SacredIcons.pageSingle : SacredIcons.rotate,
                color: tokens.ink,
                size: 17,
                strokeWidth: 1.9,
              ),
              onTap: onTwoPages,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.semantics,
    required this.leading,
    required this.onTap,
  });

  final String? label;
  final String semantics;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: tokens.fill,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading,
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: SacredText.buttonSmall.copyWith(
                      color: tokens.ink,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
