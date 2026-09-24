import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:quran_app_2025/app/glass_surface.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/page_repository.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/features/murottal/presentation/murottal_sheet.dart';
import 'package:quran_app_2025/features/reader/presentation/card_parts.dart';
import 'package:quran_app_2025/features/reader/presentation/reading_mode_sheet.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_markup_parser.dart';
import 'package:quran_app_2025/features/tajweed/data/tajweed_repository.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_legend_screen.dart';
import 'package:quran_app_2025/features/tajweed/presentation/tajweed_palette.dart';
import 'package:quran_app_2025/screens/translation_picker.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:quran_app_2025/services/firebase_sync.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/widgets/audio_mini_player.dart';

/// Banyaknya ayat per blok pada mode fokus. Mockup menyambung seluruh ayat
/// jadi satu paragraf; blok kecil membuat tampilannya tetap mengalir tetapi
/// posisi baca masih tercatat saat digulir.
const _focusChunk = 5;

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.surah, this.initialVerse = 1});
  final SurahMeta surah;
  final int initialVerse;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Future<_ReaderContent> _content;
  late ReadingSessionTracker _tracker;
  bool _focusMode = false;
  bool _showTranslation = SharedPreferencesService.getShowIndonesian();
  double _arabicSize = SharedPreferencesService.getArabicFontSize();
  double _lineHeight = SharedPreferencesService.getArabicLineHeight();
  final _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  final _timerText = ValueNotifier<String>('');

  /// Ayat yang sedang dilihat, dipisah dari `setState` supaya menggulir tidak
  /// membangun ulang seluruh daftar.
  final _verse = ValueNotifier<int>(1);
  Timer? _saveTimer;
  int _currentVerse = 1;
  bool _ready = false;

  /// Kartu pertama yang terlihat saat layar dibuka.
  late final int _firstCard = widget.initialVerse
      .clamp(1, widget.surah.ayahCount)
      .toInt();

  /// Pesan kegagalan murottal yang sedang ditampilkan, beserta ayat yang
  /// gagal diputar supaya tombol "Coba lagi" tahu harus mengulang apa.
  String? _audioError;
  int? _audioErrorVerse;

  /// Warna tajwid di kartu (chip Tajwid).
  bool _tajweed = SharedPreferencesService.getReaderTajweed();

  /// Kertas pembaca pilihan pengguna; null = ikut tema aplikasi.
  ReaderPaper? _paper = ReaderPaper.byName(
    SharedPreferencesService.getReaderPaper(),
  );

  /// Lembar "Tampilan baca": mode, tajwid, legenda, ukuran teks, kertas.
  Future<void> _openReadingMode(_ReaderContent content) async {
    final current =
        _paper ??
        (Theme.of(context).brightness == Brightness.dark
            ? ReaderPaper.night
            : ReaderPaper.ivory);
    var openTextSize = false;
    await showReadingModeSheet(
      context,
      tajweed: _tajweed,
      onTajweed: (value) {
        if (value != _tajweed) _toggleTajweed(content);
      },
      paper: current,
      onPaper: (paper) {
        setState(() => _paper = paper);
        unawaited(SharedPreferencesService.setReaderPaper(paper.name));
      },
      onLegend: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const TajweedLegendScreen(backLabel: 'Tampilan'),
        ),
      ),
      onTextSize: () {
        openTextSize = true;
        Navigator.of(context).pop();
      },
    );
    if (openTextSize && mounted) await _openDisplaySheet();
  }

  /// Terjemahan kedua pilihan pengguna (maksimal dua terjemahan sekaligus),
  /// beserta isinya bila sudah tersimpan di perangkat.
  TranslationEdition? _second = readSecondTranslation();
  List<String>? _secondVerses;
  DownloadState _download = DownloadState.idle;

  /// Memuat isi terjemahan kedua dari perangkat; tidak mengunduh apa pun.
  Future<void> _loadSecond() async {
    final edition = _second;
    List<String>? verses;
    if (edition != null) {
      try {
        final saved = await TranslationRepository.instance.online.load(edition);
        final surah = saved?.verses[widget.surah.number - 1];
        if (surah != null && surah.length == widget.surah.ayahCount) {
          verses = surah;
        }
      } on Object {
        verses = null;
      }
    }
    if (mounted) setState(() => _secondVerses = verses);
  }

  Future<void> _setSecond(TranslationEdition? edition) async {
    await SharedPreferencesService.setSecondTranslation(
      edition == null ? null : jsonEncode(edition.toJson()),
    );
    setState(() {
      _second = edition;
      _secondVerses = null;
      _download = DownloadState.idle;
    });
    await _loadSecond();
  }

  Future<void> _downloadSecond() async {
    final edition = _second;
    if (edition == null) return;
    setState(() => _download = DownloadState.downloading);
    try {
      final saved = await TranslationRepository.instance.online.download(
        edition,
      );
      if (!mounted) return;
      // Bila QuranEnc gagal, padanan dari fawazahmed0 yang tersimpan.
      if (saved != edition) {
        await _setSecond(saved);
      } else {
        await _loadSecond();
      }
      if (mounted) setState(() => _download = DownloadState.idle);
    } on Object {
      if (mounted) setState(() => _download = DownloadState.failed);
    }
  }

  String get _languageLabel {
    final parts = [
      if (_showTranslation) 'Indonesia',
      if (_second != null) translationLanguage(_second!),
    ];
    return parts.isEmpty ? 'Tanpa terjemahan' : parts.join(' + ');
  }

  void _toggleTajweed(_ReaderContent content) {
    final next = !_tajweed;
    setState(() => _tajweed = next);
    unawaited(SharedPreferencesService.setReaderTajweed(next));
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (next && content.tajweed == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Data warna tajwid tidak dapat dimuat.')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(next ? 'Warna tajwid menyala' : 'Warna tajwid dimatikan'),
        action: next
            ? SnackBarAction(
                label: 'Arti warna',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const TajweedLegendScreen(backLabel: 'Kartu'),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  /// Layar Terjemahan (06): memilih Indonesia bawaan dan satu terjemahan
  /// lain. Sepulangnya, pilihan dibaca ulang dari penyimpanan.
  Future<void> _openTranslations() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TranslationPicker(backLabel: 'Kartu'),
      ),
    );
    if (!mounted) return;
    setState(() {
      _showTranslation = SharedPreferencesService.getShowIndonesian();
      _second = readSecondTranslation();
      _secondVerses = null;
      _download = DownloadState.idle;
    });
    await _loadSecond();
  }

  Future<_ReaderContent> _load() async {
    final arabic = await QuranTextRepository.instance.versesForSurah(
      widget.surah.number,
    );
    // Basmalah di awal ayat 1 (bawaan teks Tanzil) ditampilkan terpisah;
    // pembandingnya ayat 1:1 dari dataset yang sama.
    final fatihah = await QuranTextRepository.instance.versesForSurah(1);
    final basmalah = basmalahPrefix(
      widget.surah.number,
      arabic.first,
      fatihah.first,
    );
    // Warna tajwid hanya pelengkap: bila gagal, ayat tetap tampil polos.
    List<TajweedVerse>? tajweed;
    try {
      tajweed = await TajweedRepository.instance.forSurah(widget.surah.number);
      if (tajweed.length != arabic.length) tajweed = null;
    } on Object {
      tajweed = null;
    }
    List<String>? translation;
    try {
      translation = await TranslationRepository.instance.forSurah(
        widget.surah.number,
      );
      if (translation.length != arabic.length) translation = null;
    } catch (_) {}
    // Nama Arab dan penanda posisi hanya pelengkap navigasi; kegagalannya
    // tidak boleh menutup teks yang sudah berhasil dibaca.
    String? arabicName;
    var juz = const <JuzBoundary>[];
    var pages = const <PageBoundary>[];
    try {
      arabicName = (await SuraNamesRepository.load())[widget.surah.number - 1];
      juz = await JuzRepository.load();
      pages = await PageRepository.load();
    } on Object {
      // Biarkan apa adanya: label posisi menghilang, teksnya tetap tampil.
    }
    if (mounted) {
      _ready = true;
      _tracker.start();
    }
    return _ReaderContent(
      arabic,
      translation,
      arabicName,
      juz,
      pages,
      tajweed: tajweed,
      basmalah: basmalah,
    );
  }

  void _positionChanged() {
    final visible =
        _positions.itemPositions.value
            .where(
              (item) =>
                  item.index > 0 &&
                  item.itemTrailingEdge > 0 &&
                  item.itemLeadingEdge < 1,
            )
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    if (visible.isEmpty) return;
    final verse = _verseForIndex(visible.first.index);
    if (verse == _currentVerse) return;
    _currentVerse = verse;
    _verse.value = verse;
    _tracker.verseKey = '${widget.surah.number}:$verse';
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), _savePosition);
  }

  /// Indeks daftar → nomor ayat. Mode fokus memuat beberapa ayat per blok,
  /// jadi pemetaannya berbeda.
  int _verseForIndex(int index) =>
      _focusMode ? (index - 1) * _focusChunk + 1 : index;

  int _indexForVerse(int verse) =>
      _focusMode ? (verse - 1) ~/ _focusChunk + 1 : verse;

  void _savePosition() {
    if (_ready) {
      unawaited(
        SharedPreferencesService.setLastReadVerse(
          widget.surah.number,
          _currentVerse,
        ),
      );
    }
  }

  Future<void> _jumpToVerse() async {
    _tracker.setPaused(true);
    final controller = TextEditingController(text: '$_currentVerse');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buka ayat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Ayat 1–${widget.surah.ayahCount}',
          ),
          onSubmitted: (value) {
            final verse = int.tryParse(value);
            if (verse != null &&
                verse >= 1 &&
                verse <= widget.surah.ayahCount) {
              Navigator.pop(context, verse);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final verse = int.tryParse(controller.text);
              if (verse != null &&
                  verse >= 1 &&
                  verse <= widget.surah.ayahCount) {
                Navigator.pop(context, verse);
              }
            },
            child: const Text('Buka'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _tracker.setPaused(false);
    if (result != null && _scroll.isAttached) {
      _scroll.jumpTo(index: _indexForVerse(result));
    }
  }

  /// Lembar "Tampilan": ukuran dan jarak baris teks Arab, hasilnya langsung
  /// terlihat di halaman di belakang lembar.
  Future<void> _openDisplaySheet() async {
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
        child: StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'TAMPILAN',
                  style: SacredText.eyebrow.copyWith(color: tokens.sec),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ukuran teks Arab',
                  style: SacredText.cardLabel.copyWith(color: tokens.sec),
                ),
                Slider(
                  value: _arabicSize,
                  min: 22,
                  max: 42,
                  divisions: 20,
                  label: _arabicSize.round().toString(),
                  onChanged: (value) {
                    setSheetState(() {});
                    setState(() => _arabicSize = value);
                  },
                  onChangeEnd: (value) => unawaited(
                    SharedPreferencesService.setArabicFontSize(value),
                  ),
                ),
                Text(
                  'Jarak antarbaris',
                  style: SacredText.cardLabel.copyWith(color: tokens.sec),
                ),
                Slider(
                  value: _lineHeight,
                  min: 1.6,
                  max: 3,
                  divisions: 14,
                  label: _lineHeight.toStringAsFixed(1),
                  onChanged: (value) {
                    setSheetState(() {});
                    setState(() => _lineHeight = value);
                  },
                  onChangeEnd: (value) => unawaited(
                    SharedPreferencesService.setArabicLineHeight(value),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tampilkan terjemahan Indonesia',
                        style: SacredText.settingTitle.copyWith(
                          color: tokens.ink,
                        ),
                      ),
                    ),
                    IosToggle(
                      value: _showTranslation,
                      semanticsLabel: 'Tampilkan terjemahan Indonesia',
                      onChanged: (value) {
                        setSheetState(() {});
                        setState(() => _showTranslation = value);
                        unawaited(
                          SharedPreferencesService.setShowIndonesian(value),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMurottal(_ReaderContent content) => showMurottalSheet(
    context,
    surah: widget.surah,
    arabicName: content.arabicName ?? widget.surah.displayName,
    verse: _currentVerse,
  );

  /// Kegagalan murottal ditahan di layar sebagai keadaan, bukan pesan sekilas.
  void _showAudioError() {
    final message = QuranAudioService.instance.error.value;
    if (message == null || !mounted) return;
    setState(() => _audioError = message);
  }

  Future<void> _playVerse(int ayah) async {
    try {
      await QuranAudioService.instance.toggle(
        surah: widget.surah.number,
        ayah: ayah,
      );
    } on Object {
      if (!mounted) return;
      setState(() {
        _audioErrorVerse = ayah;
        _audioError =
            'Murottal belum tersedia. Periksa koneksi internet, atau unduh '
            'surah ini lebih dulu.';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentVerse = widget.initialVerse
        .clamp(1, widget.surah.ayahCount)
        .toInt();
    _verse.value = _currentVerse;
    _tracker = ReadingSessionTracker(
      onChanged: () {
        if (mounted) {
          _timerText.value = _tracker.needsConfirmation
              ? 'Masih membaca?'
              : _timerLabel();
        }
      },
    );
    _tracker.verseKey = '${widget.surah.number}:$_currentVerse';
    _timerText.value = _timerLabel();
    _content = _load();
    unawaited(_loadSecond());
    _positions.itemPositions.addListener(_positionChanged);
    QuranAudioService.instance.playingVerse.addListener(_followAudio);
    QuranAudioService.instance.error.addListener(_showAudioError);
  }

  /// Menjaga ayat yang sedang diputar tetap terlihat.
  void _followAudio() {
    final key = QuranAudioService.instance.playingVerse.value;
    final prefix = '${widget.surah.number}:';
    if (key == null || !key.startsWith(prefix) || !_scroll.isAttached) return;
    final index = _indexForVerse(int.parse(key.substring(prefix.length)));
    final visible = _positions.itemPositions.value.any(
      (item) =>
          item.index == index &&
          item.itemLeadingEdge >= 0 &&
          item.itemTrailingEdge <= .85,
    );
    if (visible) return;
    unawaited(
      _scroll.scrollTo(
        index: index,
        alignment: .08,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _savePosition();
    _positions.itemPositions.removeListener(_positionChanged);
    QuranAudioService.instance.playingVerse.removeListener(_followAudio);
    QuranAudioService.instance.error.removeListener(_showAudioError);
    _timerText.dispose();
    _verse.dispose();
    unawaited(
      _tracker.dispose().then((_) => AccountService.instance.syncNow()),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mode fokus memakai palet sepia seperti di mockup, apa pun tema aplikasi.
    // Kertas pilihan (Tampilan baca) berlaku di mode kartu; tanpa pilihan,
    // pembaca ikut tema aplikasi.
    final theme = _focusMode
        ? SacredTheme.themeFor(AppPalette.sepia, Brightness.light)
        : _paper?.theme ?? Theme.of(context);
    return Theme(
      data: theme,
      child: Builder(builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: FutureBuilder<_ReaderContent>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ReaderError(
              message: '${snapshot.error}',
              onRetry: () => setState(() => _content = _load()),
            );
          }
          final content = snapshot.data!;
          final verses = content.arabic;
          final itemCount = _focusMode
              ? (verses.length / _focusChunk).ceil() + 1
              : verses.length + 1;

          return Stack(
            children: [
              if (_focusMode)
                Positioned.fill(
                  child: GeometricPattern(
                    tile: 56,
                    opacity: .05,
                    color: tokens.gold,
                  ),
                ),
              Column(
                children: [
                  if (_focusMode)
                    _FocusHeader(
                      onClose: () => setState(() => _focusMode = false),
                      onDisplay: _openDisplaySheet,
                    )
                  else
                    _ReaderNav(
                      surah: widget.surah,
                      verse: _verse,
                      content: content,
                      onBack: () => Navigator.of(context).maybePop(),
                      onJump: _jumpToVerse,
                      onDisplay: () => unawaited(_openReadingMode(content)),
                      onFocus: () => setState(() => _focusMode = true),
                    ),
                  if (!_focusMode)
                    ReaderChips(
                      languageLabel: _languageLabel,
                      tajweed: _tajweed,
                      onLanguage: () => unawaited(_openTranslations()),
                      onTajweed: () => _toggleTajweed(content),
                    ),
                  Expanded(
                    child: Listener(
                      onPointerDown: (_) => _tracker.interact(),
                      child: ScrollablePositionedList.builder(
                        itemScrollController: _scroll,
                        itemPositionsListener: _positions,
                        initialScrollIndex: _currentVerse == 1
                            ? 0
                            : _indexForVerse(_currentVerse),
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          _focusMode ? 22 : 10,
                          8,
                          _focusMode ? 22 : 10,
                          _focusMode ? 20 : 28,
                        ),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _SurahPlate(
                              surah: widget.surah,
                              arabicName: content.arabicName,
                              timerText: _timerText,
                              tracker: _tracker,
                              compact: _focusMode,
                            );
                          }
                          if (_focusMode) {
                            return _FocusBlock(
                              verses: verses,
                              first: (index - 1) * _focusChunk,
                              count: _focusChunk,
                              size: _arabicSize,
                              lineHeight: _lineHeight,
                            );
                          }
                          final number = index;
                          final translation = content.translation;
                          final second = _second;
                          final secondVerses = _secondVerses;
                          // Bahasa kedua yang belum tersimpan ditawarkan
                          // sekali, di kartu pertama yang dibuka.
                          final offerDownload =
                              second != null &&
                              secondVerses == null &&
                              number == _firstCard;
                          return _VerseCard(
                            key: ValueKey('${widget.surah.number}:$number'),
                            verseNumber: number,
                            arabic: verses[number - 1],
                            basmalah: number == 1 ? content.basmalah : 0,
                            tajweed: _tajweed && content.tajweed != null
                                ? content.tajweed![number - 1]
                                : null,
                            translation: _showTranslation && translation != null
                                ? translation[number - 1]
                                : null,
                            secondCode: second == null
                                ? null
                                : translationCode(second),
                            secondText: secondVerses?[number - 1],
                            secondRtl: second?.direction == 'rtl',
                            extra: offerDownload
                                ? TranslationDownloadRow(
                                    edition: second,
                                    state: _download,
                                    onDownload: () =>
                                        unawaited(_downloadSecond()),
                                  )
                                : null,
                            surahNumber: widget.surah.number,
                            arabicSize: _arabicSize,
                            lineHeight: _lineHeight,
                            onPlay: _playVerse,
                          );
                        },
                      ),
                    ),
                  ),
                  if (_focusMode)
                    _FocusBar(
                      tracker: _tracker,
                      onMurottal: () => unawaited(_openMurottal(content)),
                      onTranslation: () => setState(() {
                        _focusMode = false;
                        _showTranslation = true;
                      }),
                    ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: _audioError == null
                          ? AudioMiniPlayer(
                              onOpen: (_, __) =>
                                  unawaited(_openMurottal(content)),
                            )
                          : _AudioUnavailable(
                              message: _audioError!,
                              onRetry: () {
                                final ayah = _audioErrorVerse;
                                setState(() => _audioError = null);
                                if (ayah != null) unawaited(_playVerse(ayah));
                              },
                              onDismiss: () =>
                                  setState(() => _audioError = null),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _timerLabel() {
    final progress = ReadingProgressService.read();
    return '${progress.todaySeconds ~/ 60}/${progress.targetSeconds ~/ 60} m';
  }
}

/// Navigasi kaca pembaca (Pembaca.html): kembali ke daftar surah, judul surah
/// dengan posisi Juz/halaman, lalu tombol Tampilan dan Mode fokus.
class _ReaderNav extends StatelessWidget {
  const _ReaderNav({
    required this.surah,
    required this.verse,
    required this.content,
    required this.onBack,
    required this.onJump,
    required this.onDisplay,
    required this.onFocus,
  });

  final SurahMeta surah;
  final ValueNotifier<int> verse;
  final _ReaderContent content;
  final VoidCallback onBack;
  final VoidCallback onJump;
  final VoidCallback onDisplay;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return GlassSurface(
      borderRadius: BorderRadius.zero,
      tint: tokens.glass,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.sep, width: .5)),
          ),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onBack,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LineIcon(
                        SacredIcons.chevronLeft,
                        color: tokens.primaryText,
                        size: 24,
                        strokeWidth: 2.2,
                      ),
                      Text(
                        'Surah',
                        style: SacredText.backLabel.copyWith(
                          color: tokens.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onJump,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                surah.displayName,
                                textAlign: TextAlign.center,
                                maxLines:
                                    MediaQuery.textScalerOf(context).scale(16) /
                                            16 >=
                                        1.6
                                    ? 2
                                    : 1,
                                overflow: TextOverflow.ellipsis,
                                style: SacredText.navTitle.copyWith(
                                  color: tokens.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            LineIcon(
                              SacredIcons.chevronDown,
                              color: tokens.sec,
                              size: 15,
                              strokeWidth: 2.4,
                            ),
                          ],
                        ),
                        Text(
                          'Kartu ayat · ${surah.ayahCount} ayat',
                          textAlign: TextAlign.center,
                          // Teks besar: boleh dua baris, jangan terpotong.
                          maxLines:
                              MediaQuery.textScalerOf(context).scale(16) / 16 >=
                                  1.6
                              ? 2
                              : 1,
                          overflow: TextOverflow.ellipsis,
                          style: SacredText.navSubtitle.copyWith(
                            color: tokens.sec,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _FillButton(
                tooltip: 'Tampilan bacaan',
                onTap: onDisplay,
                paths: SacredIcons.textSize,
              ),
              _FillButton(
                tooltip: 'Mode fokus',
                onTap: onFocus,
                paths: SacredIcons.moon,
                iconSize: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol bulat berlatar isian lembut, seperti tombol kanan pada nav pembaca.
class _FillButton extends StatelessWidget {
  const _FillButton({
    required this.tooltip,
    required this.onTap,
    required this.paths,
    this.strokeWidth = SacredIcons.strokeNav,
    this.size = 40,
    this.iconSize = 20,
  });

  final String tooltip;
  final VoidCallback onTap;
  final List<String> paths;
  final double strokeWidth;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.fill,
                shape: BoxShape.circle,
              ),
              child: LineIcon(
                paths,
                color: tokens.ink,
                size: iconSize,
                strokeWidth: strokeWidth,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kepala mode fokus: tutup, penanda mode, dan tombol tampilan.
class _FocusHeader extends StatelessWidget {
  const _FocusHeader({required this.onClose, required this.onDisplay});

  final VoidCallback onClose;
  final VoidCallback onDisplay;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _FillButton(
              tooltip: 'Keluar dari mode fokus',
              onTap: onClose,
              paths: SacredIcons.close,
              strokeWidth: SacredIcons.strokeAction,
              size: 44,
            ),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.fill,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Mode fokus · Sepia',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SacredText.linkLabel.copyWith(color: tokens.sec),
                  ),
                ),
              ),
            ),
            _FillButton(
              tooltip: 'Tampilan bacaan',
              onTap: onDisplay,
              paths: SacredIcons.textSize,
              size: 44,
            ),
          ],
        ),
      ),
    );
  }
}

/// Plakat nama surah. Di mode biasa memakai bidang emas lembut seperti mockup;
/// di mode fokus berupa kotak bergaris dengan rosette di dua sisi.
class _SurahPlate extends StatelessWidget {
  const _SurahPlate({
    required this.surah,
    required this.arabicName,
    required this.timerText,
    required this.tracker,
    required this.compact,
  });

  final SurahMeta surah;
  final String? arabicName;
  final ValueNotifier<String> timerText;
  final ReadingSessionTracker tracker;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.gold),
          ),
          child: Row(
            children: [
              RosetteBadge(
                label: '',
                size: 22,
                outlined: true,
                color: tokens.gold,
              ),
              Expanded(
                child: Text(
                  arabicName ?? surah.displayName,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: SacredText.quran,
                    fontSize: 28,
                    height: 50 / 28,
                    color: tokens.ink,
                  ),
                ),
              ),
              RosetteBadge(
                label: '',
                size: 22,
                outlined: true,
                color: tokens.gold,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 250,
              maxWidth: 250,
              minHeight: 128,
            ),
            child: CustomPaint(
              foregroundPainter: _PlateOutline(color: tokens.gold),
              child: ClipPath(
                clipper: const MihrabClipper(radius: 18),
                child: ColoredBox(
                  color: tokens.goldSoft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          arabicName ?? surah.displayName,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: SacredText.quran,
                            fontSize: 30,
                            height: 50 / 30,
                            color: tokens.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${surah.revelation == 'Makkah' ? 'Makkiyah' : 'Madaniyah'}'
                          ' · ${surah.ayahCount} ayat',
                          textAlign: TextAlign.center,
                          style: SacredText.plateMeta.copyWith(
                            color: tokens.goldText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<String>(
            valueListenable: timerText,
            builder: (context, value, _) => InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: () => tracker.setPaused(!tracker.paused),
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: tokens.primarySoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  tracker.paused
                      ? (value == 'Masih membaca?' ? value : 'Lanjutkan')
                      : 'Sesi $value',
                  style: SacredText.cardNote.copyWith(
                    color: tokens.primaryText,
                    fontWeight: FontWeight.w800,
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

class _PlateOutline extends CustomPainter {
  const _PlateOutline({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      MihrabClipper.pathFor(size, radius: 18),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color,
    );
    const inset = 7.0;
    if (size.width <= inset * 2 || size.height <= inset * 2) return;
    canvas.drawPath(
      MihrabClipper.pathFor(
        Size(size.width - inset * 2, size.height - inset * 2),
        radius: 14,
      ).shift(const Offset(inset, inset)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6
        ..color = color.withValues(alpha: .7),
    );
  }

  @override
  bool shouldRepaint(_PlateOutline old) => old.color != color;
}

/// Beberapa ayat yang mengalir jadi satu paragraf, rata tengah.
class _FocusBlock extends StatelessWidget {
  const _FocusBlock({
    required this.verses,
    required this.first,
    required this.count,
    required this.size,
    required this.lineHeight,
  });

  final List<String> verses;
  final int first;
  final int count;
  final double size;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final last = (first + count).clamp(0, verses.length);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text.rich(
        TextSpan(
          children: [
            for (var i = first; i < last; i++) ...[
              TextSpan(text: verses[i]),
              const WidgetSpan(child: SizedBox(width: 4)),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: RosetteBadge.ayah(i + 1, size: size),
              ),
              const WidgetSpan(child: SizedBox(width: 4)),
            ],
          ],
        ),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: SacredText.quran,
          fontSize: size,
          height: lineHeight,
          color: tokens.ink,
        ),
      ),
    );
  }
}

/// Baris bawah mode fokus: lama sesi, target, dan dua tombol.
class _FocusBar extends StatelessWidget {
  const _FocusBar({
    required this.tracker,
    required this.onMurottal,
    required this.onTranslation,
  });

  final ReadingSessionTracker tracker;
  final VoidCallback onMurottal;
  final VoidCallback onTranslation;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final progress = ReadingProgressService.read();
    final fraction = progress.targetSeconds <= 0
        ? 1.0
        : (progress.todaySeconds / progress.targetSeconds).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // Perkiraan: waktu hanya dihitung selama layar aktif.
                  'Sesi ini ${_mmss(tracker.elapsed)} · perkiraan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.cardNote.copyWith(color: tokens.sec),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Target ${(progress.targetSeconds / 60).round()} mnt',
                style: SacredText.cardNote.copyWith(color: tokens.sec),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: tokens.surf2,
              valueColor: AlwaysStoppedAnimation(tokens.gold),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _FocusAction(
                  label: 'Murottal',
                  paths: SacredIcons.headphones,
                  onTap: onMurottal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FocusAction(
                  label: 'Terjemahan',
                  paths: SacredIcons.translate,
                  onTap: onTranslation,
                  primary: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _mmss(Duration value) =>
      '${value.inMinutes.toString().padLeft(2, '0')}:'
      '${(value.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _FocusAction extends StatelessWidget {
  const _FocusAction({
    required this.label,
    required this.paths,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final List<String> paths;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final foreground = primary ? tokens.ctaInk : tokens.ink;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: primary ? tokens.cta : tokens.fill,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LineIcon(
              paths,
              color: foreground,
              size: 18,
              strokeWidth: SacredIcons.strokeNav,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SacredText.chipLabel.copyWith(
                  color: foreground,
                  fontWeight: primary ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle, size: 46),
          const SizedBox(height: 14),
          const Text(
            'Konten tidak dapat dibuka',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(CupertinoIcons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );
}

/// Kartu ayat v2 (V2-Kartu.html): rosette nomor, putar & bookmark, Arab
/// bertajwid, lalu terjemahan berlabel kode bahasa.
class _VerseCard extends StatefulWidget {
  const _VerseCard({
    super.key,
    required this.verseNumber,
    required this.arabic,
    required this.translation,
    required this.surahNumber,
    required this.arabicSize,
    required this.lineHeight,
    required this.onPlay,
    this.basmalah = 0,
    this.tajweed,
    this.secondCode,
    this.secondText,
    this.secondRtl = false,
    this.extra,
  });
  final int verseNumber;
  final String arabic;
  final String? translation;
  final int surahNumber;
  final double arabicSize;
  final double lineHeight;
  final Future<void> Function(int ayah) onPlay;

  /// Panjang awalan basmalah pada [arabic] (ayat 1 teks Tanzil), atau 0.
  final int basmalah;

  /// Rentang tajwid ayat ini; null = teks polos.
  final TajweedVerse? tajweed;
  final String? secondCode;
  final String? secondText;
  final bool secondRtl;

  /// Baris tambahan di bawah terjemahan (tawaran unduh bahasa kedua).
  final Widget? extra;

  @override
  State<_VerseCard> createState() => _VerseCardState();
}

class _VerseCardState extends State<_VerseCard> {
  late bool bookmarked;

  @override
  void initState() {
    super.initState();
    bookmarked = SharedPreferencesService.isBookmarked(
      widget.surahNumber,
      widget.verseNumber,
    );
  }

  Future<void> _onBookmark() async {
    if (!bookmarked) {
      await SharedPreferencesService.saveBookmark(
        widget.surahNumber,
        widget.verseNumber,
      );
      if (!mounted) return;
      setState(() => bookmarked = true);
      await _chooseBookmarkCollection();
      return;
    }
    // Sudah ditandai: tawarkan pindah koleksi atau hapus, supaya ketukan
    // tidak sengaja tidak langsung menghapus.
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: tokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GroupedList(
            label: 'Bookmark ayat ${widget.verseNumber}',
            children: [
              ListRow(
                title: 'Pindahkan ke koleksi',
                chevron: true,
                onTap: () => Navigator.pop(context, 'move'),
              ),
              ListRow(
                title: 'Hapus bookmark',
                titleColor: tokens.danger,
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'move') {
      await _chooseBookmarkCollection();
      return;
    }
    await SharedPreferencesService.removeBookmark(
      widget.surahNumber,
      widget.verseNumber,
    );
    if (mounted) setState(() => bookmarked = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final brightness = Theme.of(context).brightness;
    final translationSize = SharedPreferencesService.getTranslationFontSize();
    final verseKey = '${widget.surahNumber}:${widget.verseNumber}';
    final tajweed = widget.tajweed;
    return RepaintBoundary(
      child: ValueListenableBuilder<String?>(
        valueListenable: QuranAudioService.instance.playingVerse,
        builder: (context, playing, child) {
          final active = playing == verseKey;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 18),
            decoration: BoxDecoration(
              // Ayat yang sedang diputar diberi latar hijau lembut.
              color: active ? tokens.primarySoft : tokens.surf,
              borderRadius: BorderRadius.circular(28),
              boxShadow: tokens.cardShadows,
            ),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _VerseHeader(
              verseKey: verseKey,
              ayah: widget.verseNumber,
              bookmarked: bookmarked,
              onBookmark: _onBookmark,
              onPlay: () => widget.onPlay(widget.verseNumber),
            ),
            const SizedBox(height: 6),
            if (widget.basmalah > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text.rich(
                  TextSpan(
                    children: tajweed == null
                        ? [
                            TextSpan(
                              text: widget.arabic.substring(
                                0,
                                widget.basmalah - 1,
                              ),
                            ),
                          ]
                        : tajweedSpans(
                            tajweed,
                            palette: TajweedPalette.draftPreview,
                            brightness: brightness,
                            base: tokens.ink,
                            to: widget.basmalah - 1,
                          ),
                  ),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  semanticsLabel: 'Basmalah',
                  style: TextStyle(
                    fontFamily: SacredText.quran,
                    fontSize: widget.arabicSize * .8,
                    height: 2,
                    color: tokens.ink,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text.rich(
                TextSpan(
                  children: tajweed == null
                      ? [
                          TextSpan(
                            text: widget.arabic.substring(widget.basmalah),
                          ),
                        ]
                      : tajweedSpans(
                          tajweed,
                          palette: TajweedPalette.draftPreview,
                          brightness: brightness,
                          base: tokens.ink,
                          from: widget.basmalah,
                        ),
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                semanticsLabel: 'Ayat ${widget.verseNumber}',
                style: TextStyle(
                  fontFamily: SacredText.quran,
                  fontSize: widget.arabicSize,
                  // Minimal 2.0 supaya harakat tidak terpotong.
                  height: widget.lineHeight < 2 ? 2 : widget.lineHeight,
                  color: tokens.ink,
                ),
              ),
            ),
            if (widget.translation != null) ...[
              const SizedBox(height: 10),
              LabeledTranslation(
                code: 'ID',
                text: widget.translation!,
                size: translationSize,
              ),
            ],
            if (widget.secondText != null && widget.secondCode != null) ...[
              const SizedBox(height: 10),
              LabeledTranslation(
                code: widget.secondCode!,
                text: widget.secondText!,
                size: translationSize,
                rtl: widget.secondRtl,
              ),
            ],
            if (widget.extra != null) ...[
              const SizedBox(height: 12),
              widget.extra!,
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _chooseBookmarkCollection() async {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final collection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: tokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GroupedList(
            label: 'Simpan ke koleksi',
            children: [
              for (final option in const ['Umum', 'Hafalan', 'Favorit'])
                ListRow(
                  title: option,
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        ),
      ),
    );
    if (collection == null) return;
    await SharedPreferencesService.setBookmarkCollection(
      widget.surahNumber,
      widget.verseNumber,
      collection,
    );
  }
}

class _VerseHeader extends StatelessWidget {
  const _VerseHeader({
    required this.verseKey,
    required this.ayah,
    required this.bookmarked,
    required this.onBookmark,
    required this.onPlay,
  });

  final String verseKey;
  final int ayah;
  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final audio = QuranAudioService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        audio.playingVerse,
        audio.isPlaying,
        audio.buffering,
      ]),
      builder: (context, _) {
        final current = audio.playingVerse.value == verseKey;
        final playing = current && audio.isPlaying.value;
        final accent = current ? tokens.primaryText : tokens.sec;
        return Row(
          children: [
            Semantics(
              label: 'Ayat $ayah',
              excludeSemantics: true,
              child: RosetteBadge.ayah(ayah, size: 30),
            ),
            const Spacer(),
            _RoundIcon(
              tooltip: playing ? 'Jeda ayat $ayah' : 'Putar ayat $ayah',
              onTap: onPlay,
              background: current ? tokens.surf : Colors.transparent,
              child: current && audio.buffering.value
                  ? SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    )
                  : LineIcon(
                      playing ? SacredIcons.pause : SacredIcons.play,
                      color: current ? accent : tokens.ink,
                      size: 14,
                      filled: true,
                    ),
            ),
            _RoundIcon(
              tooltip: bookmarked
                  ? 'Bookmark ayat $ayah: pindah atau hapus'
                  : 'Bookmark ayat $ayah',
              onTap: onBookmark,
              child: LineIcon(
                bookmarked ? SacredIcons.bookmarkFilled : SacredIcons.bookmark,
                color: bookmarked ? tokens.primaryText : tokens.ink,
                size: 18,
                strokeWidth: SacredIcons.strokeNav,
                filled: bookmarked,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.background,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background ?? Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class _ReaderContent {
  const _ReaderContent(
    this.arabic,
    this.translation,
    this.arabicName,
    this.juz,
    this.pages, {
    this.tajweed,
    this.basmalah = 0,
  });

  /// Panjang awalan basmalah di ayat 1 (0 bila tidak ada).
  final int basmalah;

  /// Ayat beserta rentang tajwidnya (cpfair), atau null bila gagal dimuat.
  final List<TajweedVerse>? tajweed;

  final List<String> arabic;
  final List<String>? translation;
  final String? arabicName;
  final List<JuzBoundary> juz;
  final List<PageBoundary> pages;

  /// "Juz 1 · Hal. 1 · Ayat 1" dari metadata Tanzil. Bagian yang tidak
  /// diketahui dihilangkan, bukan ditebak.
  String locationLabel(int surah, int verse) {
    int? juzNumber;
    for (final boundary in juz) {
      if (boundary.surah < surah ||
          (boundary.surah == surah && boundary.verse <= verse)) {
        juzNumber = boundary.number;
      }
    }
    int? pageNumber;
    for (final boundary in pages) {
      if (boundary.surah < surah ||
          (boundary.surah == surah && boundary.verse <= verse)) {
        pageNumber = boundary.number;
      }
    }
    return [
      if (juzNumber != null) 'Juz $juzNumber',
      if (pageNumber != null) 'Hal. $pageNumber',
      'Ayat $verse',
    ].join(' · ');
  }
}

/// Pengganti mini player saat murottal gagal dimuat: mengaku apa adanya dan
/// menawarkan satu tindakan, bukan pesan yang hilang sendiri.
class _AudioUnavailable extends StatelessWidget {
  const _AudioUnavailable({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: tokens.goldSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.sep),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.speaker_slash, size: 20, color: tokens.goldText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Murottal belum tersedia',
                  style: SacredText.cardNote.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  message,
                  style: SacredText.cardNote.copyWith(color: tokens.sec),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          IconButton(
            tooltip: 'Tutup pemberitahuan',
            onPressed: onDismiss,
            icon: Icon(CupertinoIcons.xmark, size: 18, color: tokens.sec),
          ),
        ],
      ),
    );
  }
}
