import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:quran_app_2025/app/glass_surface.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/data/juz_repository.dart';
import 'package:quran_app_2025/data/page_repository.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/features/murottal/presentation/murottal_sheet.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/services/reading_progress_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:quran_app_2025/services/firebase_sync.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/widgets/audio_mini_player.dart';

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
  bool _showTranslation = true;
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

  /// Pesan kegagalan murottal yang sedang ditampilkan, beserta ayat yang
  /// gagal diputar supaya tombol "Coba lagi" tahu harus mengulang apa.
  String? _audioError;
  int? _audioErrorVerse;

  Future<_ReaderContent> _load() async {
    final arabic = await QuranTextRepository.instance.versesForSurah(
      widget.surah.number,
    );
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
    return _ReaderContent(arabic, translation, arabicName, juz, pages);
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
    if (visible.isEmpty || visible.first.index == _currentVerse) return;
    _currentVerse = visible.first.index;
    _verse.value = _currentVerse;
    _tracker.verseKey = '${widget.surah.number}:$_currentVerse';
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), _savePosition);
  }

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
    // The dialog may still animate while its controller is attached.
    if (!mounted) return;
    _tracker.setPaused(false);
    if (result != null && _scroll.isAttached) _scroll.jumpTo(index: result);
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
                  style: SacredText.footnote.copyWith(color: tokens.sec),
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
                  style: SacredText.footnote.copyWith(color: tokens.sec),
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tampilkan terjemahan'),
                  value: _showTranslation,
                  onChanged: (value) {
                    setSheetState(() {});
                    setState(() => _showTranslation = value);
                  },
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
    _positions.itemPositions.addListener(_positionChanged);
    QuranAudioService.instance.playingVerse.addListener(_followAudio);
    QuranAudioService.instance.error.addListener(_showAudioError);
  }

  /// Keeps the verse the player is actually on in view.
  void _followAudio() {
    final key = QuranAudioService.instance.playingVerse.value;
    final prefix = '${widget.surah.number}:';
    if (key == null || !key.startsWith(prefix) || !_scroll.isAttached) return;
    final index = int.parse(key.substring(prefix.length));
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

  /// Kegagalan murottal ditahan di layar sebagai keadaan, bukan snackbar yang
  /// lewat begitu saja, supaya pembaca tahu kenapa suaranya tidak muncul.
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
  void dispose() {
    _saveTimer?.cancel();
    _savePosition();
    _positions.itemPositions.removeListener(_positionChanged);
    QuranAudioService.instance.playingVerse.removeListener(_followAudio);
    QuranAudioService.instance.error.removeListener(_showAudioError);
    _timerText.dispose();
    _verse.dispose();
    // Upload the session just closed once the tracker has saved it.
    unawaited(
      _tracker.dispose().then((_) => AccountService.instance.syncNow()),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          return Column(
            children: [
              _ReaderNav(
                surah: widget.surah,
                verse: _verse,
                content: content,
                focusMode: _focusMode,
                onJump: _jumpToVerse,
                onDisplay: _openDisplaySheet,
                onToggleFocus: () => setState(() => _focusMode = !_focusMode),
              ),
              Expanded(
                child: Listener(
                  onPointerDown: (_) => _tracker.interact(),
                  child: ScrollablePositionedList.separated(
                    itemScrollController: _scroll,
                    itemPositionsListener: _positions,
                    // Dibuka dari awal surah: tampilkan bingkai judulnya dulu.
                    initialScrollIndex: _currentVerse == 1 ? 0 : _currentVerse,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    itemCount: content.arabic.length + 1,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: _focusMode ? 6 : 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _SurahHeader(
                          surah: widget.surah,
                          arabicName: content.arabicName,
                          timerText: _timerText,
                          tracker: _tracker,
                          compact: _focusMode,
                        );
                      }
                      final number = index;
                      final translation = content.translation;
                      return _focusMode
                          ? _FocusVerse(
                              arabic: content.arabic[number - 1],
                              number: number,
                              size: _arabicSize,
                              lineHeight: _lineHeight,
                            )
                          : _VerseCard(
                              key: ValueKey('${widget.surah.number}:$number'),
                              verseNumber: number,
                              arabic: content.arabic[number - 1],
                              translation:
                                  _showTranslation && translation != null
                                  ? translation[number - 1]
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
                  timerText: _timerText,
                  onMurottal: () => unawaited(_openMurottal(content)),
                  // Terjemahan tidak ditampilkan di mode fokus, jadi tombolnya
                  // mengembalikan pembaca ke tampilan biasa.
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
                          onOpen: (_, __) => unawaited(_openMurottal(content)),
                        )
                      : _AudioUnavailable(
                          message: _audioError!,
                          onRetry: () {
                            final ayah = _audioErrorVerse;
                            setState(() => _audioError = null);
                            if (ayah != null) unawaited(_playVerse(ayah));
                          },
                          onDismiss: () => setState(() => _audioError = null),
                        ),
                ),
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

/// Navigasi kaca pembaca: kembali, judul surah dengan posisi Juz/halaman, lalu
/// tombol Tampilan dan Mode fokus.
class _ReaderNav extends StatelessWidget {
  const _ReaderNav({
    required this.surah,
    required this.verse,
    required this.content,
    required this.focusMode,
    required this.onJump,
    required this.onDisplay,
    required this.onToggleFocus,
  });

  final SurahMeta surah;
  final ValueNotifier<int> verse;
  final _ReaderContent content;
  final bool focusMode;
  final VoidCallback onJump;
  final VoidCallback onDisplay;
  final VoidCallback onToggleFocus;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(24),
          tint: tokens.glass,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Kembali ke daftar surah',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(CupertinoIcons.chevron_left, color: tokens.ink),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onJump,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Text(
                            surah.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SacredText.headline.copyWith(
                              color: tokens.ink,
                            ),
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: verse,
                            builder: (context, value, _) => Text(
                              content.locationLabel(surah.number, value),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SacredText.footnote.copyWith(
                                color: tokens.sec,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tampilan teks',
                  onPressed: onDisplay,
                  icon: Icon(CupertinoIcons.textformat_size, color: tokens.ink),
                ),
                IconButton(
                  tooltip: focusMode ? 'Keluar dari mode fokus' : 'Mode fokus',
                  onPressed: onToggleFocus,
                  icon: Icon(
                    focusMode
                        ? CupertinoIcons.fullscreen_exit
                        : CupertinoIcons.fullscreen,
                    color: focusMode ? tokens.primaryText : tokens.ink,
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

/// Bingkai mihrab berisi nama surah, keterangan singkat, dan penanda sesi.
class _SurahHeader extends StatelessWidget {
  const _SurahHeader({
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
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 4),
      child: Column(
        children: [
          ConstrainedBox(
            // Tinggi minimum menjaga proporsi bingkai, tetapi dibiarkan
            // tumbuh: nama surah tidak boleh terpotong pada teks besar.
            constraints: BoxConstraints(
              minWidth: 210,
              maxWidth: 210,
              minHeight: compact ? 132 : 168,
            ),
            child: MihrabFrame(
              child: Stack(
                children: [
                  const Positioned.fill(child: GeometricPattern(opacity: .09)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 34, 18, 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (arabicName != null)
                          Text(
                            arabicName!,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: SacredText.quran,
                              fontSize: 24,
                              height: 2,
                              color: tokens.artInk,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          surah.displayName,
                          textAlign: TextAlign.center,
                          style: SacredText.footnote.copyWith(
                            color: Colors.white.withValues(alpha: .88),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${surah.revelation} · ${surah.ayahCount} ayat',
            style: SacredText.footnote.copyWith(color: tokens.sec),
          ),
          const SizedBox(height: 8),
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
                  style: SacredText.footnote.copyWith(
                    color: tokens.primaryText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          if (!compact) ...[const SizedBox(height: 12), const _SourceNotice()],
        ],
      ),
    );
  }
}

class _SourceNotice extends StatelessWidget {
  const _SourceNotice();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.goldSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.cloud_download, size: 18, color: tokens.goldText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Teks Arab dan terjemahan Indonesia tersedia luring. Murottal '
              'dialirkan saat ada internet; tekan tombol putar pada satu ayat '
              'untuk memutar berurutan dari sana.',
              style: SacredText.footnote.copyWith(color: tokens.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mode fokus: hanya teks Arab, rata tengah, dengan penanda akhir ayat.
class _FocusVerse extends StatelessWidget {
  const _FocusVerse({
    required this.arabic,
    required this.number,
    required this.size,
    required this.lineHeight,
  });

  final String arabic;
  final int number;
  final double size;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: arabic),
            const WidgetSpan(child: SizedBox(width: 6)),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: RosetteBadge.ayah(number, size: size * .95),
            ),
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

/// Baris bawah mode fokus: lama sesi, target hari ini, dan dua tombol.
class _FocusBar extends StatelessWidget {
  const _FocusBar({
    required this.tracker,
    required this.timerText,
    required this.onMurottal,
    required this.onTranslation,
  });

  final ReadingSessionTracker tracker;
  final ValueNotifier<String> timerText;
  final VoidCallback onMurottal;
  final VoidCallback onTranslation;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.sep),
      ),
      child: ValueListenableBuilder<String>(
        valueListenable: timerText,
        builder: (context, value, _) {
          final progress = ReadingProgressService.read();
          final fraction = progress.targetSeconds <= 0
              ? 1.0
              : (progress.todaySeconds / progress.targetSeconds).clamp(
                  0.0,
                  1.0,
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      // Perkiraan: waktu hanya dihitung selama layar aktif.
                      'Sesi ${_mmss(tracker.elapsed)} · perkiraan',
                      style: SacredText.footnote.copyWith(color: tokens.sec),
                    ),
                  ),
                  Text(
                    '$value hari ini',
                    style: SacredText.footnote.copyWith(
                      color: tokens.primaryText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 5,
                  backgroundColor: tokens.surf2,
                  valueColor: AlwaysStoppedAnimation(tokens.primary),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMurottal,
                      icon: const Icon(CupertinoIcons.headphones, size: 18),
                      label: const Text('Murottal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTranslation,
                      icon: const Icon(CupertinoIcons.textformat_alt, size: 18),
                      label: const Text('Terjemahan'),
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

  static String _mmss(Duration value) =>
      '${value.inMinutes.toString().padLeft(2, '0')}:'
      '${(value.inSeconds % 60).toString().padLeft(2, '0')}';
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
  });
  final int verseNumber;
  final String arabic;
  final String? translation;
  final int surahNumber;
  final double arabicSize;
  final double lineHeight;
  final Future<void> Function(int ayah) onPlay;

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

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final translationSize = SharedPreferencesService.getTranslationFontSize();
    final verseKey = '${widget.surahNumber}:${widget.verseNumber}';
    return RepaintBoundary(
      child: ValueListenableBuilder<String?>(
        valueListenable: QuranAudioService.instance.playingVerse,
        builder: (context, playing, child) {
          final active = playing == verseKey;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 18),
            decoration: BoxDecoration(
              color: active ? tokens.primarySoft : tokens.surf,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: active ? tokens.primary : tokens.sep,
                width: active ? 1.2 : 1,
              ),
            ),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  verseKey,
                  style: SacredText.footnote.copyWith(
                    color: tokens.sec,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    if (bookmarked) {
                      await SharedPreferencesService.removeBookmark(
                        widget.surahNumber,
                        widget.verseNumber,
                      );
                    } else {
                      await SharedPreferencesService.saveBookmark(
                        widget.surahNumber,
                        widget.verseNumber,
                      );
                      if (mounted) await _chooseBookmarkCollection();
                    }
                    if (mounted) setState(() => bookmarked = !bookmarked);
                  },
                  icon: Icon(
                    bookmarked
                        ? CupertinoIcons.bookmark_fill
                        : CupertinoIcons.bookmark,
                    size: 20,
                  ),
                  color: bookmarked ? tokens.primaryText : tokens.sec,
                  tooltip: bookmarked ? 'Hapus bookmark' : 'Simpan bookmark',
                ),
                _VersePlayButton(
                  surah: widget.surahNumber,
                  ayah: widget.verseNumber,
                  onPlay: widget.onPlay,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: widget.arabic),
                    const WidgetSpan(child: SizedBox(width: 6)),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: RosetteBadge.ayah(
                        widget.verseNumber,
                        size: widget.arabicSize * .95,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: SacredText.quran,
                  fontSize: widget.arabicSize,
                  height: widget.lineHeight,
                  color: tokens.ink,
                ),
              ),
            ),
            if (widget.translation != null) ...[
              const SizedBox(height: 14),
              Text(
                widget.translation!,
                style: SacredText.body.copyWith(
                  color: tokens.ink,
                  fontSize: translationSize,
                  height: 1.55,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _chooseBookmarkCollection() async {
    final collection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const ['Umum', 'Hafalan', 'Favorit'])
              ListTile(
                leading: const Icon(CupertinoIcons.folder),
                title: Text(option),
                onTap: () => Navigator.pop(context, option),
              ),
          ],
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

class _ReaderContent {
  const _ReaderContent(
    this.arabic,
    this.translation,
    this.arabicName,
    this.juz,
    this.pages,
  );

  final List<String> arabic;
  final List<String>? translation;
  final String? arabicName;
  final List<JuzBoundary> juz;
  final List<PageBoundary> pages;

  /// "Juz 23 · Hal. 442 · Ayat 41" dari metadata Tanzil. Bagian yang tidak
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

class _VersePlayButton extends StatelessWidget {
  const _VersePlayButton({
    required this.surah,
    required this.ayah,
    required this.onPlay,
  });
  final int surah;
  final int ayah;

  /// Pemutaran ditangani layar supaya kegagalannya bisa ditampilkan menetap.
  final Future<void> Function(int ayah) onPlay;

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
        final current = audio.playingVerse.value == '$surah:$ayah';
        final playing = current && audio.isPlaying.value;
        return IconButton(
          onPressed: () => onPlay(ayah),
          icon: current && audio.buffering.value
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Icon(
                  playing ? CupertinoIcons.pause_fill : CupertinoIcons.play,
                  size: 20,
                ),
          color: current ? tokens.primaryText : tokens.sec,
          tooltip: playing ? 'Jeda murottal' : 'Putar mulai ayat ini',
        );
      },
    );
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
                  style: SacredText.footnote.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  message,
                  style: SacredText.footnote.copyWith(
                    color: tokens.sec,
                    fontSize: 12,
                  ),
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
