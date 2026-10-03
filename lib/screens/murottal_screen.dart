import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/murottal/application/murottal_verses.dart';
import 'package:quran_app_2025/features/murottal/application/now_playing_audio.dart';
import 'package:quran_app_2025/features/murottal/application/player_view_model.dart';
import 'package:quran_app_2025/features/murottal/presentation/ayah_follow_list.dart';
import 'package:quran_app_2025/features/murottal/presentation/murottal_panel.dart';
import 'package:quran_app_2025/features/murottal/presentation/now_playing_row.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/screens/reader_screen.dart';
import 'package:quran_app_2025/screens/reciter_picker.dart';
import 'package:quran_app_2025/services/audio_download_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Plakat mihrab pada Murottal.html (270×330), verbatim.
const _platePath =
    'M0 302 L0 128.0 C0 53.8 81.0 20.5 135.0 0 C189.0 20.5 270 53.8 270 128.0 '
    'L270 302 Q270 330 242 330 L28 330 Q0 330 0 302 Z';

/// Garis emas di dalamnya, digeser 10 px seperti di mockup.
const _plateInnerPath =
    'M0 290 L0 120.0 C0 50.4 75.0 19.2 125.0 0 C175.0 19.2 250 50.4 250 120.0 '
    'L250 290 Q250 310 230 310 L20 310 Q0 310 0 290 Z';

/// Bagian daftar ayat yang bergulir di belakang sudut panel (radius 30).
const _panelOverlap = 30.0;

/// Murottal v6 "ikuti bacaan" (docs/design/v6/screens/20-murottal.md,
/// acuan V6-Murottal.png).
///
/// Bar atas, chip qari + Teks | Sampul, isi (daftar ayat yang mengikuti
/// audio, atau sampul mihrab + satu ayat aktif), lalu panel kontrol padat.
class MurottalScreen extends StatefulWidget {
  const MurottalScreen({super.key, this.audio, this.downloadService});

  /// Hanya untuk tes: pemutar palsu.
  @visibleForTesting
  final MurottalAudio? audio;

  /// Hanya untuk tes: pengunduh dengan folder sementara.
  @visibleForTesting
  final AudioDownloadService? downloadService;

  @override
  State<MurottalScreen> createState() => _MurottalScreenState();
}

class _MurottalScreenState extends State<MurottalScreen> {
  late final MurottalAudio _audio = widget.audio ?? QuranNowPlayingAudio();
  late Future<List<String>> _arabicNames = SuraNamesRepository.load();
  final _verses = <int, Future<MurottalVerses>>{};
  bool _cover = SharedPreferencesService.getMurottalView() == 'sampul';
  bool _translation = SharedPreferencesService.getMurottalTranslation();

  /// Antrean terakhir yang diputar, untuk banner galat & "Coba lagi"
  /// setelah pemutar menutup dirinya.
  PlayerView? _last;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _last = PlayerView.of(_audio.queue, _audio.playingVerse);
    _audio.addListener(_onAudio);
  }

  @override
  void dispose() {
    _audio.removeListener(_onAudio);
    super.dispose();
  }

  /// Pesan galat hanya terisi sesaat sebelum pemutar ditutup, jadi dibaca
  /// di sini, bukan di `build`.
  void _onAudio() {
    final view = PlayerView.of(_audio.queue, _audio.playingVerse);
    if (view != null) {
      _last = view;
      if (_failed) setState(() => _failed = false);
    }
    if (_audio.error != null && !_failed) setState(() => _failed = true);
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onError() {
    if (mounted) setState(() => _failed = true);
  }

  Future<MurottalVerses> _versesFor(int surah) =>
      _verses.putIfAbsent(surah, () => MurottalVerses.load(surah));

  void _retry() {
    final last = _last;
    if (last == null) return;
    unawaited(
      _guard(
        () => _audio.playRange(
          surah: last.surah,
          fromAyah: last.queue.firstAyah,
          toAyah: last.queue.lastAyah,
          startAyah: last.ayah,
        ),
      ),
    );
  }

  void _setCover(bool cover) {
    setState(() => _cover = cover);
    unawaited(
      SharedPreferencesService.setMurottalView(cover ? 'sampul' : 'teks'),
    );
  }

  void _openReader(int surah, int ayah) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ReaderScreen(surah: surahCatalog[surah - 1], initialVerse: ayah),
    ),
  );

  /// Pemilih qari memuat ulang antrean di ayat yang sama sendiri
  /// (23-qari.md §Tampilan 7); di sini cukup menyegarkan nama qari.
  Future<void> _pickReciter() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ReciterPicker()));
    if (mounted) setState(() {});
  }

  Future<void> _openMenu(PlayerView view) async {
    final choice = await showMurottalSheet<String>(
      context,
      title: surahCatalog[view.surah - 1].displayName,
      child: Builder(
        builder: (context) => InsetGroupedList(
          children: [
            SheetOption(
              icon: SacredIcons.book,
              label: 'Buka di pembaca',
              onTap: () => Navigator.pop(context, 'baca'),
            ),
            SheetOption(
              icon: SacredIcons.translate,
              label: _translation
                  ? 'Sembunyikan terjemahan'
                  : 'Tampilkan terjemahan',
              onTap: () => Navigator.pop(context, 'terjemahan'),
            ),
            SheetOption(
              icon: SacredIcons.close,
              label: 'Hentikan murottal',
              onTap: () => Navigator.pop(context, 'hentikan'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'baca':
        _openReader(view.surah, view.ayah);
      case 'terjemahan':
        setState(() => _translation = !_translation);
        unawaited(
          SharedPreferencesService.setMurottalTranslation(_translation),
        );
      case 'hentikan':
        await _audio.stop();
        if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _ayahMenu(int surah, int ayah) async {
    final saved = SharedPreferencesService.isBookmarked(surah, ayah);
    final choice = await showMurottalSheet<String>(
      context,
      title: '${surahCatalog[surah - 1].displayName} · Ayat $ayah',
      child: Builder(
        builder: (context) => InsetGroupedList(
          children: [
            SheetOption(
              icon: saved ? SacredIcons.bookmarkFilled : SacredIcons.bookmark,
              label: saved ? 'Hapus bookmark' : 'Simpan bookmark',
              onTap: () => Navigator.pop(context, 'bookmark'),
            ),
            SheetOption(
              icon: SacredIcons.book,
              label: 'Buka di pembaca',
              onTap: () => Navigator.pop(context, 'baca'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'bookmark':
        if (saved) {
          await SharedPreferencesService.removeBookmark(surah, ayah);
        } else {
          await SharedPreferencesService.saveBookmark(surah, ayah);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(saved ? 'Bookmark dihapus.' : 'Bookmark disimpan.'),
          ),
        );
      case 'baca':
        _openReader(surah, ayah);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _audio,
          builder: (context, _) {
            final live = PlayerView.of(_audio.queue, _audio.playingVerse);
            final view = live ?? (_failed ? _last : null);
            if (view == null) return _idle(context);
            return _player(context, view, live: live != null);
          },
        ),
      ),
    );
  }

  Widget _player(BuildContext context, PlayerView view, {required bool live}) {
    final surah = surahCatalog[view.surah - 1];
    final failed = _failed && !live;
    final banner = failed ? 90.0 : 0.0;
    return Column(
      children: [
        _TopBar(
          title: surah.displayName,
          onClose: () => Navigator.of(context).pop(),
          onMenu: () => unawaited(_openMenu(view)),
        ),
        _ChoiceRow(
          reciterName: _audio.reciterName,
          onReciter: () => unawaited(_pickReciter()),
          cover: _cover,
          onCover: _setCover,
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: -_panelOverlap,
                child: FutureBuilder<MurottalVerses>(
                  future: _versesFor(view.surah),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _TextError(
                        onRetry: () =>
                            setState(() => _verses.remove(view.surah)),
                      );
                    }
                    final verses = snapshot.data;
                    if (verses == null) return const SizedBox.shrink();
                    final active = _audio.wholeSurah ? null : view.ayah;
                    if (_cover) {
                      return _Cover(
                        surah: surah,
                        names: _arabicNames,
                        onRetryNames: () => setState(
                          () => _arabicNames = SuraNamesRepository.load(),
                        ),
                        ayah: view.ayah,
                        arabic: verses.arabicOf(view.ayah),
                        translation: _translation
                            ? verses.translationOf(view.ayah)
                            : null,
                        bottomPadding: _panelOverlap + 16 + banner,
                      );
                    }
                    return AyahFollowList(
                      // Antrean baru = daftar baru (posisi awal & ayat).
                      key: ValueKey(
                        '${view.surah}:${view.queue.firstAyah}-'
                        '${view.queue.lastAyah}',
                      ),
                      verses: verses,
                      firstAyah: view.queue.firstAyah,
                      lastAyah: view.queue.lastAyah,
                      activeAyah: active,
                      showTranslation: _translation,
                      bottomPadding: _panelOverlap + 16 + banner,
                      onTapAyah: live && !_audio.wholeSurah
                          ? (ayah) => unawaited(
                              _guard(
                                () =>
                                    _audio.jumpTo(ayah - view.queue.firstAyah),
                              ),
                            )
                          : null,
                      onLongPressAyah: (ayah) =>
                          unawaited(_ayahMenu(view.surah, ayah)),
                    );
                  },
                ),
              ),
              if (failed)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 10,
                  child: _ErrorBanner(onRetry: _retry),
                ),
            ],
          ),
        ),
        MurottalPanel(
          audio: _audio,
          view: view,
          failed: failed,
          onRetry: _retry,
          onError: _onError,
          downloadService: widget.downloadService,
          reciter: SharedPreferencesService.getReciter(),
        ),
      ],
    );
  }

  /// Tidak ada yang diputar: ajakan memutar bacaan terakhir.
  Widget _idle(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final surahNumber = SharedPreferencesService.getLastReadSurah() ?? 1;
    final ayah = SharedPreferencesService.getLastReadVerse(surahNumber);
    final surah = surahCatalog[surahNumber - 1];
    return Column(
      children: [
        _TopBar(
          title: 'Murottal',
          eyebrow: null,
          onClose: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
              child: Column(
                children: [
                  SizedBox(
                    width: 120,
                    child: FittedBox(
                      child: _Plate(
                        names: _arabicNames,
                        surah: surah,
                        onRetry: () => setState(
                          () => _arabicNames = SuraNamesRepository.load(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Murottal sedang tidak diputar',
                    textAlign: TextAlign.center,
                    style: SacredText.headline.copyWith(color: tokens.ink),
                  ),
                  const SizedBox(height: 20),
                  SacredButton(
                    label: 'Putar ${surah.displayName} dari ayat $ayah',
                    icon: SacredIcons.play,
                    iconFilled: true,
                    onTap: () => unawaited(
                      _guard(() => _audio.playFrom(surahNumber, ayah)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tutup · "MUROTTAL · PER AYAT" + nama surah · menu ⋯.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onClose,
    this.onMenu,
    this.eyebrow = 'MUROTTAL · PER AYAT',
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback? onMenu;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final onMenu = this.onMenu;
    final eyebrow = this.eyebrow;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: Row(
        children: [
          _CircleButton(
            icon: SacredIcons.chevronDown,
            label: 'Tutup',
            onTap: onClose,
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                children: [
                  if (eyebrow != null) ...[
                    Text(
                      eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.murottalEyebrow.copyWith(
                        color: tokens.sec,
                      ),
                    ),
                    const SizedBox(height: 1),
                  ],
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SacredText.murottalTitle.copyWith(color: tokens.ink),
                  ),
                ],
              ),
            ),
          ),
          if (onMenu != null)
            _CircleButton(
              icon: SacredIcons.more,
              filled: true,
              label: 'Menu murottal',
              onTap: onMenu,
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final List<String> icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.surf,
                shape: BoxShape.circle,
                boxShadow: tokens.cardShadows,
              ),
              child: LineIcon(
                icon,
                color: tokens.ink,
                size: 20,
                strokeWidth: 2.2,
                filled: filled,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip qari (ke pemilih qari) + kapsul Teks | Sampul.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.reciterName,
    required this.onReciter,
    required this.cover,
    required this.onCover,
  });

  final String reciterName;
  final VoidCallback onReciter;
  final bool cover;
  final ValueChanged<bool> onCover;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(10) >= 16;
    final chip = _ReciterChip(name: reciterName, onTap: onReciter);
    final segments = SegmentedPill<bool>(
      capsule: true,
      segments: const {false: 'Teks', true: 'Sampul'},
      value: cover,
      onChanged: onCover,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [chip, const SizedBox(height: 10), segments],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: chip),
                const SizedBox(width: 12),
                IntrinsicWidth(child: segments),
              ],
            ),
    );
  }
}

class _ReciterChip extends StatelessWidget {
  const _ReciterChip({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: 'Qari $name. Ketuk untuk mengganti qari.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          decoration: BoxDecoration(
            color: tokens.surf,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tokens.sep),
            boxShadow: tokens.cardShadows,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: SacredText.qariChip.copyWith(color: tokens.surf),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.qariChip.copyWith(color: tokens.ink),
                ),
              ),
              const SizedBox(width: 6),
              LineIcon(
                SacredIcons.chevronDown,
                color: tokens.sec,
                size: 14,
                strokeWidth: 2.4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mode Sampul: mihrab 62% lebar layar + satu ayat aktif, tanpa daftar.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.surah,
    required this.names,
    required this.onRetryNames,
    required this.ayah,
    required this.arabic,
    required this.translation,
    required this.bottomPadding,
  });

  final SurahMeta surah;
  final Future<List<String>> names;
  final VoidCallback onRetryNames;
  final int ayah;
  final String arabic;
  final String? translation;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * .62;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            // Mihrab mini di dock terbang ke plakat ini (21-dock.md).
            child: Hero(
              tag: NowPlayingRow.murottalHeroTag,
              child: SizedBox(
                width: width,
                child: FittedBox(
                  child: _Plate(
                    names: names,
                    surah: surah,
                    onRetry: onRetryNames,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          AyahFollowItem(
            ayah: ayah,
            arabic: arabic,
            translation: translation,
            active: true,
          ),
        ],
      ),
    );
  }
}

/// Banner di atas panel saat murottal gagal diputar.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: tokens.goldSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Murottal belum dapat diputar. Periksa koneksi atau unduh '
              'surah ini.',
              style: SacredText.footnote.copyWith(color: tokens.ink),
            ),
          ),
          Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                child: Text(
                  'Coba lagi',
                  style: SacredText.linkLabel.copyWith(
                    color: tokens.primaryText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Teks ayat gagal dibaca dari aset (sangat jarang): tawarkan muat ulang.
class _TextError extends StatelessWidget {
  const _TextError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Teks ayat belum dapat dimuat.',
              textAlign: TextAlign.center,
              style: SacredText.body.copyWith(color: tokens.sec),
            ),
            const SizedBox(height: 12),
            SacredButton(
              label: 'Muat ulang',
              tone: ButtonTone.soft,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// Plakat mihrab berisi nama surah dalam aksara Arab (270×330).
class _Plate extends StatelessWidget {
  const _Plate({
    required this.names,
    required this.surah,
    required this.onRetry,
  });

  final Future<List<String>> names;
  final SurahMeta surah;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return SizedBox(
      width: 270,
      height: 330,
      child: ClipPath(
        clipper: const _PathClipper(_platePath, Size(270, 330)),
        child: Container(
          color: tokens.art,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _PlateOutline(tokens.goldLine)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 108, 16, 16),
                child: Column(
                  children: [
                    FutureBuilder<List<String>>(
                      future: names,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return GestureDetector(
                            onTap: onRetry,
                            child: Text(
                              'Muat ulang nama surah',
                              style: SacredText.linkLabel.copyWith(
                                color: tokens.artInk,
                              ),
                            ),
                          );
                        }
                        final arabic = snapshot.data == null
                            ? ''
                            : snapshot.data![surah.number - 1];
                        return Text(
                          arabic,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: SacredText.quran,
                            fontSize: 56,
                            height: 90 / 56,
                            color: tokens.gold,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'SURAH KE-${surah.number} · '
                      '${surah.revelation.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: SacredText.eyebrow.copyWith(color: tokens.artInk),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Memotong kotak mengikuti jalur SVG mockup.
class _PathClipper extends CustomClipper<Path> {
  const _PathClipper(this.d, this.design);

  final String d;
  final Size design;

  @override
  Path getClip(Size size) => parseSvgPath(d).transform(
    Matrix4.diagonal3Values(
      size.width / design.width,
      size.height / design.height,
      1,
    ).storage,
  );

  @override
  bool shouldReclip(_PathClipper old) => old.d != d || old.design != design;
}

class _PlateOutline extends CustomPainter {
  const _PlateOutline(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 270;
    final scaleY = size.height / 330;
    final matrix = Matrix4.identity()
      ..translateByDouble(10 * scaleX, 10 * scaleY, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1);
    canvas.drawPath(
      parseSvgPath(_plateInnerPath).transform(matrix.storage),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_PlateOutline old) => old.color != color;
}
