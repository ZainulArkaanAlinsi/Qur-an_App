import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/features/hafalan/domain/murajaah_schedule.dart';
import 'package:quran_app_2025/models/memorization_status.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:record/record.dart';

/// Jenis sesi, untuk judul "Ziyadah · ayat 3 dari 1–5".
enum SessionMode {
  ziyadah('Ziyadah'),
  murajaah('Murajaah'),
  tasmi('Tasmi’');

  const SessionMode(this.label);
  final String label;
}

/// Lima langkah menghafal satu ayat.
enum _Step {
  dengar('Dengar'),
  baca('Baca'),
  tutup('Tutup'),
  uji('Uji'),
  sambung('Sambung');

  const _Step(this.label);
  final String label;
}

/// Sesi hafalan v2 (docs/design/v2/screens/11-sesi-hafalan.md,
/// V2-SesiHafalan.png): satu ayat demi satu ayat, lima langkah, lalu orang
/// menilai sendiri Salah / Ragu / Lancar.
///
/// Aplikasi tidak mendengar atau menilai bacaan
/// (docs/RELIGIOUS_CONTENT_GOVERNANCE.md). Rekaman opsional dan hanya
/// tersimpan di perangkat.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.surah,
    this.fromAyah,
    this.toAyah,
    this.mode = SessionMode.ziyadah,
    this.now,
  });

  final SurahMeta surah;

  /// Rentang sesi; bawaan seluruh surah.
  final int? fromAyah;
  final int? toAyah;
  final SessionMode mode;

  /// Hanya untuk tes: tanggal yang dibekukan.
  @visibleForTesting
  final DateTime Function()? now;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final int _from = (widget.fromAyah ?? 1).clamp(
    1,
    widget.surah.ayahCount,
  );
  late final int _to = (widget.toAyah ?? widget.surah.ayahCount).clamp(
    _from,
    widget.surah.ayahCount,
  );
  late int _ayah = _from;
  _Step _step = _Step.dengar;

  /// Berapa kata yang sudah terbuka pada langkah Tutup/Uji/Sambung.
  int _revealed = 0;

  late int _repeat = SharedPreferencesService.getHafalanRepeat();
  late final Future<_Texts> _texts = _load();

  final _results = <int, ReviewOutcome>{};
  bool _finished = false;

  DateTime get _today => widget.now?.call() ?? DateTime.now();

  Future<_Texts> _load() async {
    final arabic = await QuranTextRepository.instance.versesForSurah(
      widget.surah.number,
    );
    List<String>? translation;
    try {
      translation = await TranslationRepository.instance.forSurah(
        widget.surah.number,
      );
    } on Object {
      translation = null; // Terjemahan pelengkap; sesi tetap jalan.
    }
    return _Texts(arabic, translation);
  }

  @override
  void dispose() {
    // Jangan biarkan murottal terus berbunyi setelah sesi ditutup.
    if (QuranAudioService.instance.isPlaying.value) {
      unawaited(QuranAudioService.instance.stop());
    }
    super.dispose();
  }

  void _goTo(_Step step, List<String> words) {
    setState(() {
      _step = step;
      _revealed = switch (step) {
        // Tutup: separuh awal terlihat, sisanya diucapkan lalu dibuka.
        _Step.tutup => (words.length ~/ 2).clamp(1, words.length),
        _Step.uji || _Step.sambung => 0,
        _ => words.length,
      };
    });
  }

  Future<void> _listen({required bool withPrevious}) async {
    final audio = QuranAudioService.instance;
    try {
      if (audio.isPlaying.value) {
        await audio.stop();
        return;
      }
      await audio.playRange(
        surah: widget.surah.number,
        fromAyah: withPrevious ? _ayah - 1 : _ayah,
        toAyah: _ayah,
        // Jumlahnya diserahkan ke pemutar dan berhenti sendiri (RangePlan);
        // dulu LoopMode.all membuat 3× tidak pernah berhenti.
        repeatCount: _repeat,
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Murottal belum dapat diputar. Periksa koneksi.'),
        ),
      );
    }
  }

  /// Catat penilaian orangnya sendiri, lalu lanjut ke ayat berikutnya.
  Future<void> _rate(ReviewOutcome outcome) async {
    final surah = widget.surah.number;
    final today = _today;
    final existing = SharedPreferencesService.getAyahMemorization(
      surah,
    ).where((item) => item.ayah == _ayah).firstOrNull;
    final before =
        existing ??
        AyahMemorization.fresh(surah: surah, ayah: _ayah, today: today);
    await SharedPreferencesService.setAyahMemorization(
      surah,
      _ayah,
      before.reviewed(outcome, today),
    );
    if (SharedPreferencesService.getMemorizationStatus(surah) ==
        MemorizationStatus.notStarted) {
      await SharedPreferencesService.setMemorizationStatus(
        surah,
        MemorizationStatus.learning,
      );
    }
    if (QuranAudioService.instance.isPlaying.value) {
      await QuranAudioService.instance.stop();
    }
    if (!mounted) return;
    setState(() {
      _results[_ayah] = outcome;
      if (_ayah < _to) {
        _ayah++;
        _step = _Step.dengar;
      } else {
        _finished = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    // Word joiner: "1–5" tidak dipisah baris.
    final range = _from == _to ? '$_from' : '$_from⁠–⁠$_to';
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: FutureBuilder<_Texts>(
          future: _texts,
          builder: (context, snapshot) {
            final texts = snapshot.data;
            return Column(
              children: [
                _Header(
                  title: _finished
                      ? widget.surah.displayName
                      : '${widget.surah.displayName} · Ayat $_ayah',
                  subtitle: _finished
                      ? '${widget.mode.label} selesai'
                      : '${widget.mode.label} · ayat $_ayah dari $range',
                ),
                Expanded(
                  child: texts == null
                      ? Center(
                          child: Text(
                            snapshot.hasError
                                ? 'Teks ayat gagal dimuat.'
                                : 'Memuat ayat…',
                            style: SacredText.body.copyWith(color: tokens.sec),
                          ),
                        )
                      : _finished
                      ? _Summary(
                          surah: widget.surah,
                          results: _results,
                          onDone: () => Navigator.of(context).pop(),
                        )
                      : _session(context, texts),
                ),
                if (texts != null && !_finished) _RatingBar(onRate: _rate),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _session(BuildContext context, _Texts texts) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final words = _words(texts.arabic[_ayah - 1]);
    final shown = _step == _Step.dengar || _step == _Step.baca
        ? words.length
        : _revealed.clamp(0, words.length);
    final hasPrevious = _ayah > 1;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _Stepper(current: _step, onTap: (step) => _goTo(step, words)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: SacredCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == _Step.sambung && hasPrevious) ...[
                  Text(
                    texts.arabic[_ayah - 2],
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: SacredText.quran,
                      fontSize: 24,
                      height: 2.0,
                      color: tokens.sec,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                _MaskedVerse(words: words, shown: shown, ayah: _ayah),
                if ((_step == _Step.dengar || _step == _Step.baca) &&
                    texts.translation != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    texts.translation![_ayah - 1],
                    textAlign: TextAlign.center,
                    style: SacredText.lessonBody.copyWith(color: tokens.sec),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  _hint(hasPrevious, shown, words.length),
                  textAlign: TextAlign.center,
                  style: SacredText.sessionHint.copyWith(color: tokens.sec),
                ),
                const SizedBox(height: 14),
                Center(child: _stepAction(words, shown, hasPrevious)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: GroupedList(
            children: [
              ListRow(
                leading: const IconBadge(
                  icon: SacredIcons.repeat,
                  color: SacredBadge.green,
                ),
                title: 'Ulangi ayat',
                subtitle: 'Berhenti otomatis',
                trailing: _RepeatStepper(
                  value: _repeat,
                  onChanged: (value) {
                    setState(() => _repeat = value);
                    unawaited(SharedPreferencesService.setHafalanRepeat(value));
                  },
                ),
              ),
              _RecordRow(surah: widget.surah.number, ayah: _ayah),
            ],
          ),
        ),
      ],
    );
  }

  String _hint(bool hasPrevious, int shown, int total) => switch (_step) {
    _Step.dengar => 'Dengarkan $_repeat× sambil melihat teksnya.',
    _Step.baca => 'Baca pelan sambil melihat teks sampai terasa lancar.',
    _Step.tutup || _Step.uji when shown >= total =>
      'Semua kata sudah terbuka. Cocokkan dengan bacaanmu.',
    _Step.tutup => 'Ucapkan kata yang tertutup, lalu buka untuk mencocokkan.',
    _Step.uji =>
      'Ucapkan seluruh ayat tanpa melihat, lalu buka kata demi kata.',
    _Step.sambung when !hasPrevious =>
      'Ini ayat pertama surah; tidak ada ayat sebelumnya untuk disambung.',
    _Step.sambung => 'Baca ayat sebelumnya, lalu sambung dengan ayat ini.',
  };

  Widget _stepAction(List<String> words, int shown, bool hasPrevious) {
    final audio = QuranAudioService.instance;
    Widget listen({required bool withPrevious, required String label}) =>
        ValueListenableBuilder<bool>(
          valueListenable: audio.isPlaying,
          builder: (context, playing, _) => SacredButton(
            label: playing ? 'Hentikan' : label,
            icon: playing ? SacredIcons.pause : SacredIcons.play,
            iconFilled: true,
            tone: ButtonTone.soft,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            textStyle: SacredText.buttonSmall,
            onTap: () => _listen(withPrevious: withPrevious),
          ),
        );
    Widget next(_Step step) => SacredButton(
      label: 'Lanjut: ${step.label}',
      tone: ButtonTone.soft,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textStyle: SacredText.buttonSmall,
      onTap: () => _goTo(step, words),
    );
    Widget reveal() => SacredButton(
      label: 'Buka kata berikutnya',
      icon: SacredIcons.eyeOff,
      tone: ButtonTone.soft,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textStyle: SacredText.buttonSmall,
      onTap: () => setState(() => _revealed = shown + 1),
    );
    Widget both(List<Widget> children) => Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: children,
    );
    final hidden = shown < words.length;
    return switch (_step) {
      _Step.dengar => both([
        listen(withPrevious: false, label: 'Dengarkan $_repeat×'),
        next(_Step.baca),
      ]),
      _Step.baca => next(_Step.tutup),
      _Step.tutup => hidden ? reveal() : next(_Step.uji),
      _Step.uji => hidden ? reveal() : next(_Step.sambung),
      _Step.sambung => both([
        if (hasPrevious) listen(withPrevious: true, label: 'Dengar sambungan'),
        // Langkah terakhir: setelah semua terbuka tinggal menilai di bawah.
        if (hidden) reveal(),
      ]),
    };
  }

  /// Kata-kata ayat. Tanda waqaf yang berdiri sendiri ikut kata sebelumnya
  /// supaya tidak menjadi "kata" yang harus dibuka.
  static List<String> _words(String verse) {
    final mark = RegExp(r'^[ۖ-ۭؕ-ؚ]+$');
    final words = <String>[];
    for (final token in verse.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      if (mark.hasMatch(token) && words.isNotEmpty) {
        words[words.length - 1] = '${words.last} $token';
      } else {
        words.add(token);
      }
    }
    return words;
  }
}

class _Texts {
  const _Texts(this.arabic, this.translation);
  final List<String> arabic;
  final List<String>? translation;
}

/// Atas: tutup 40, judul + subjudul di tengah.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 0),
      child: Row(
        children: [
          RoundIconButton(
            icon: SacredIcons.close,
            tooltip: 'Tutup sesi',
            iconSize: 18,
            strokeWidth: 2,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: SacredText.sessionTitle.copyWith(color: tokens.ink),
                ),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: SacredText.cardNote.copyWith(color: tokens.sec),
                ),
              ],
            ),
          ),
          // Penyeimbang lebar tombol tutup supaya judul benar-benar di tengah.
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

/// Stepper 5 langkah: sebelum = emas, aktif = CTA, sesudah = abu. Setiap
/// langkah bisa diketuk untuk pindah.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.current, required this.onTap});

  final _Step current;
  final ValueChanged<_Step> onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(
        children: [
          for (final step in _Step.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: step == current,
                label: 'Langkah ${step.index + 1}, ${step.label}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onTap(step),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        _dot(tokens, step),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            step.label,
                            maxLines: 1,
                            style:
                                (step == current
                                        ? SacredText.stepActive
                                        : SacredText.stepIdle)
                                    .copyWith(
                                      color: step == current
                                          ? tokens.ink
                                          : tokens.sec,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(SacredTokens tokens, _Step step) {
    final (Color bg, Color fg) = step == current
        ? (tokens.cta, tokens.ctaInk)
        : step.index < current.index
        // Selesai = emas. Di tema gelap CTA juga emas, jadi pakai emas lembut
        // supaya langkah aktif tetap terbedakan.
        ? tokens.cta == tokens.artInk
              ? (tokens.goldSoft, tokens.goldText)
              : (tokens.artInk, tokens.onGold)
        : (tokens.surf2, tokens.sec);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        '${step.index + 1}',
        textScaler: TextScaler.noScaling,
        style: SacredText.stepNumber.copyWith(color: fg),
      ),
    );
  }
}

/// Ayat dengan kata tertutup: kotak surf2 radius 10 selebar katanya
/// (HiddenWordMask), diakhiri penanda ayat.
class _MaskedVerse extends StatelessWidget {
  const _MaskedVerse({
    required this.words,
    required this.shown,
    required this.ayah,
  });

  final List<String> words;
  final int shown;
  final int ayah;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final style = TextStyle(
      fontFamily: SacredText.quran,
      fontSize: 32,
      height: 2.0,
      color: tokens.ink,
    );
    return Semantics(
      label: shown >= words.length
          ? null
          : '$shown dari ${words.length} kata terbuka',
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            for (var i = 0; i < words.length; i++)
              i < shown
                  ? Text(words[i], style: style)
                  : _HiddenWord(word: words[i], style: style),
            // Penanda ayat bergaris dengan angka Arab-Indik (mockup).
            RosetteBadge(
              label: RosetteBadge.arabicNumerals(ayah),
              size: 32,
              outlined: true,
              textStyle: const TextStyle(fontFamily: SacredText.quran),
              semanticsLabel: 'Ayat $ayah',
            ),
          ],
        ),
      ),
    );
  }
}

class _HiddenWord extends StatelessWidget {
  const _HiddenWord({required this.word, required this.style});

  final String word;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    // Lebarnya dari kata aslinya (tak terlihat), tingginya 30 seperti mockup.
    return ExcludeSemantics(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, child: Text(word, style: style)),
          Positioned.fill(
            child: Center(
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: tokens.surf2,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// − 3× + : jumlah ulang 1–10, berhenti sendiri.
class _RepeatStepper extends StatelessWidget {
  const _RepeatStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    Widget button(String label, String tooltip, int? next) => Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: next == null ? null : () => onChanged(next),
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 34,
          height: 32,
          child: Center(
            child: Text(
              label,
              style: SacredText.stepperSign.copyWith(
                color: next == null ? tokens.tertiary : tokens.ink,
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: tokens.fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button('−', 'Kurangi ulangan', value > 1 ? value - 1 : null),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28),
            child: Text(
              '$value×',
              textAlign: TextAlign.center,
              style: SacredText.stepperValue.copyWith(color: tokens.ink),
            ),
          ),
          button('+', 'Tambah ulangan', value < 10 ? value + 1 : null),
        ],
      ),
    );
  }
}

/// Rekam bacaanku: sakelar menyala = sedang merekam, mati = simpan. Berkas
/// per ayat di folder dokumen aplikasi; tidak pernah diunggah.
class _RecordRow extends StatefulWidget {
  const _RecordRow({required this.surah, required this.ayah});

  final int surah;
  final int ayah;

  @override
  State<_RecordRow> createState() => _RecordRowState();
}

class _RecordRowState extends State<_RecordRow> {
  AudioRecorder? _recorder;
  AudioPlayer? _player;
  bool _recording = false;
  bool _playing = false;
  String? _saved;

  @override
  void didUpdateWidget(_RecordRow old) {
    super.didUpdateWidget(old);
    if (old.ayah != widget.ayah) {
      // Ayat baru: rekaman sebelumnya milik ayat itu, bukan ayat ini.
      unawaited(_stopRecording());
      _saved = null;
    }
  }

  @override
  void dispose() {
    unawaited(_recorder?.dispose());
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<String> _path() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/rekaman');
    await folder.create(recursive: true);
    return '${folder.path}/${widget.surah}_${widget.ayah}.m4a';
  }

  Future<void> _toggle(bool on) async {
    if (!on) {
      await _stopRecording();
      return;
    }
    try {
      final recorder = _recorder ??= AudioRecorder();
      if (!await recorder.hasPermission()) {
        _say('Izin mikrofon ditolak. Rekaman tidak dimulai.');
        return;
      }
      if (QuranAudioService.instance.isPlaying.value) {
        await QuranAudioService.instance.stop();
      }
      await recorder.start(const RecordConfig(), path: await _path());
      if (mounted) setState(() => _recording = true);
    } on Object {
      _say('Perekam tidak tersedia di perangkat ini.');
    }
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;
    try {
      final path = await _recorder?.stop();
      if (mounted) {
        setState(() {
          _recording = false;
          _saved = path;
        });
      }
    } on Object {
      if (mounted) setState(() => _recording = false);
    }
  }

  Future<void> _play() async {
    final path = _saved;
    if (path == null) return;
    try {
      final player = _player ??= AudioPlayer();
      if (_playing) {
        await player.stop();
        if (mounted) setState(() => _playing = false);
        return;
      }
      await player.setFilePath(path);
      if (mounted) setState(() => _playing = true);
      await player.play();
      if (mounted) setState(() => _playing = false);
    } on Object {
      if (mounted) setState(() => _playing = false);
      _say('Rekaman tidak dapat diputar.');
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListRow(
      leading: const IconBadge(icon: SacredIcons.mic, color: SacredBadge.red),
      title: 'Rekam bacaanku',
      subtitle: _recording
          ? 'Merekam… matikan untuk menyimpan'
          : _saved != null
          ? 'Tersimpan di HP · ketuk putar untuk mendengar'
          : 'Opsional · tersimpan di HP saja',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_saved != null && !_recording)
            RoundIconButton(
              icon: _playing ? SacredIcons.pause : SacredIcons.play,
              filled: true,
              tooltip: _playing ? 'Hentikan rekaman' : 'Putar rekamanku',
              size: 36,
              iconSize: 14,
              onTap: _play,
            ),
          IosToggle(
            value: _recording,
            semanticsLabel: 'Rekam bacaan',
            onChanged: _toggle,
          ),
        ],
      ),
    );
  }
}

/// "Bagaimana hafalanmu untuk ayat ini?" Salah / Ragu / Lancar.
class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.onRate});

  final ValueChanged<ReviewOutcome> onRate;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    Widget button(ReviewOutcome outcome, Color bg, Color fg) => Expanded(
      child: Semantics(
        button: true,
        label: '${outcome.label}. ${outcome.effect}',
        excludeSemantics: true,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () => onRate(outcome),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text(
                outcome.label,
                textAlign: TextAlign.center,
                style: SacredText.button.copyWith(color: fg),
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Bagaimana hafalanmu untuk ayat ini?',
            textAlign: TextAlign.center,
            style: SacredText.cardLabel.copyWith(color: tokens.sec),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              button(ReviewOutcome.salah, tokens.dangerSoft, tokens.danger),
              const SizedBox(width: 8),
              button(ReviewOutcome.ragu, tokens.goldSoft, tokens.goldText),
              const SizedBox(width: 8),
              button(ReviewOutcome.lancar, tokens.cta, tokens.ctaInk),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ringkasan akhir sesi dan jadwal berikutnya.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.surah,
    required this.results,
    required this.onDone,
  });

  final SurahMeta surah;
  final Map<int, ReviewOutcome> results;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    int count(ReviewOutcome o) => results.values.where((r) => r == o).length;
    final recorded = SharedPreferencesService.getAyahMemorization(
      surah.number,
    ).length;
    final complete = recorded >= surah.ayahCount;
    final status = SharedPreferencesService.getMemorizationStatus(surah.number);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.gold,
              shape: BoxShape.circle,
            ),
            child: LineIcon(
              SacredIcons.checkCircle,
              color: tokens.onGold,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            '${results.length} ayat selesai',
            textAlign: TextAlign.center,
            style: SacredText.lessonTitle.copyWith(color: tokens.ink),
          ),
        ),
        const SizedBox(height: 16),
        GroupedList(
          children: [
            for (final outcome in ReviewOutcome.values)
              ListRow(
                title: outcome.label,
                subtitle: outcome.effect,
                trailing: RowValue('${count(outcome)} ayat'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Ayat yang ditandai muncul lagi di Murajaah sesuai jadwalnya.',
          textAlign: TextAlign.center,
          style: SacredText.cardNote.copyWith(color: tokens.sec),
        ),
        if (complete && status != MemorizationStatus.memorized) ...[
          const SizedBox(height: 18),
          SacredButton(
            label: 'Tandai ${surah.displayName} hafal',
            tone: ButtonTone.soft,
            expand: true,
            height: 46,
            textStyle: SacredText.buttonSmall,
            onTap: () async {
              await SharedPreferencesService.setMemorizationStatus(
                surah.number,
                MemorizationStatus.memorized,
              );
              onDone();
            },
          ),
        ],
        const SizedBox(height: 12),
        SacredButton(label: 'Selesai', expand: true, height: 54, onTap: onDone),
      ],
    );
  }
}
