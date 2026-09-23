import 'package:flutter/material.dart';
import 'package:quran_app_2025/data/quran_text_repository.dart';
import 'package:quran_app_2025/data/translation_repository.dart';
import 'package:quran_app_2025/models/memorization_status.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Latihan hafalan satu surah: dengarkan, ulangi, lalu uji ingatan dengan
/// menyembunyikan teks.
///
/// Mekanisme saja — aplikasi tidak menilai bacaan dan tidak memberi skor
/// tajwid otomatis (docs/RELIGIOUS_CONTENT_GOVERNANCE.md).
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.surah});

  final SurahMeta surah;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  /// Pilihan pengulangan; `null` berarti tanpa batas.
  static const _repeatChoices = <int?>[1, 3, 5, 10, null];

  late Future<_PracticeContent> _content = _load();
  late MemorizationStatus _status =
      SharedPreferencesService.getMemorizationStatus(widget.surah.number);
  int? _repeat = 3;
  bool _hideText = false;
  int _from = 1;
  late int _to = widget.surah.ayahCount;

  Future<_PracticeContent> _load() async {
    final arabic = await QuranTextRepository.instance.versesForSurah(
      widget.surah.number,
    );
    List<String>? translation;
    try {
      translation = await TranslationRepository.instance.forSurah(
        widget.surah.number,
      );
    } on Object {
      translation = null;
    }
    return _PracticeContent(arabic, translation);
  }

  Future<void> _play() async {
    final audio = QuranAudioService.instance;
    try {
      // Jumlah putarannya diserahkan ke pemutar. Dulu di sini dipanggil
      // setRepeat setelah playRange, dan itulah sebab 3×/5×/10× tidak pernah
      // berhenti sementara 1× justru berlanjut sampai akhir surah.
      await audio.playRange(
        surah: widget.surah.number,
        fromAyah: _from,
        toAyah: _to,
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

  Future<void> _setStatus(MemorizationStatus status) async {
    setState(() => _status = status);
    await SharedPreferencesService.setMemorizationStatus(
      widget.surah.number,
      status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Latihan ${widget.surah.displayName}')),
      body: FutureBuilder<_PracticeContent>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Teks surah gagal dimuat.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(() => _content = _load()),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            );
          }
          final content = snapshot.data;
          if (content == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _Controls(
                repeatChoices: _repeatChoices,
                repeat: _repeat,
                hideText: _hideText,
                from: _from,
                to: _to,
                ayahCount: widget.surah.ayahCount,
                onRepeat: (value) => setState(() => _repeat = value),
                onHideText: (value) => setState(() => _hideText = value),
                onRange: (from, to) => setState(() {
                  _from = from;
                  _to = to;
                }),
                onPlay: _play,
              ),
              const SizedBox(height: 16),
              for (var ayah = _from; ayah <= _to; ayah++)
                _PracticeVerse(
                  surah: widget.surah.number,
                  ayah: ayah,
                  arabic: content.arabic[ayah - 1],
                  translation: content.translation == null
                      ? null
                      : content.translation![ayah - 1],
                  hidden: _hideText,
                ),
              const SizedBox(height: 20),
              Text('Catatan hafalan', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final status in MemorizationStatus.values)
                    ChoiceChip(
                      avatar: Icon(status.icon, size: 18),
                      label: Text(status.label),
                      selected: _status == status,
                      onSelected: (_) => _setStatus(status),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PracticeContent {
  const _PracticeContent(this.arabic, this.translation);

  final List<String> arabic;
  final List<String>? translation;
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.repeatChoices,
    required this.repeat,
    required this.hideText,
    required this.from,
    required this.to,
    required this.ayahCount,
    required this.onRepeat,
    required this.onHideText,
    required this.onRange,
    required this.onPlay,
  });

  final List<int?> repeatChoices;
  final int? repeat;
  final bool hideText;
  final int from;
  final int to;
  final int ayahCount;
  final ValueChanged<int?> onRepeat;
  final ValueChanged<bool> onHideText;
  final void Function(int from, int to) onRange;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rentang ayat', style: theme.textTheme.labelLarge),
            RangeSlider(
              min: 1,
              max: ayahCount.toDouble(),
              divisions: ayahCount > 1 ? ayahCount - 1 : null,
              values: RangeValues(from.toDouble(), to.toDouble()),
              labels: RangeLabels('$from', '$to'),
              onChanged: (values) =>
                  onRange(values.start.round(), values.end.round()),
            ),
            const SizedBox(height: 4),
            Text('Ulangi', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final choice in repeatChoices)
                  ChoiceChip(
                    label: Text(choice == null ? 'Tanpa batas' : '$choice×'),
                    selected: repeat == choice,
                    onSelected: (_) => onRepeat(choice),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: hideText,
              title: const Text('Sembunyikan teks'),
              subtitle: const Text(
                'Uji ingatan: ketuk satu ayat untuk mengintip sebentar.',
              ),
              onChanged: onHideText,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Putar ayat $from–$to'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu ayat pada mode latihan. Saat teks disembunyikan, ayat dapat diintip
/// sementara dengan mengetuknya.
class _PracticeVerse extends StatefulWidget {
  const _PracticeVerse({
    required this.surah,
    required this.ayah,
    required this.arabic,
    required this.translation,
    required this.hidden,
  });

  final int surah;
  final int ayah;
  final String arabic;
  final String? translation;
  final bool hidden;

  @override
  State<_PracticeVerse> createState() => _PracticeVerseState();
}

class _PracticeVerseState extends State<_PracticeVerse> {
  bool _revealed = false;

  @override
  void didUpdateWidget(_PracticeVerse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hidden != widget.hidden) _revealed = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hidden = widget.hidden && !_revealed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          onTap: widget.hidden
              ? () => setState(() => _revealed = !_revealed)
              : null,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Ayat ${widget.ayah}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (widget.hidden)
                      Text(
                        _revealed ? 'Ketuk untuk tutup' : 'Ketuk untuk lihat',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (hidden)
                  Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Teks disembunyikan',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                else ...[
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      widget.arabic,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: SharedPreferencesService.getArabicFontSize(),
                        height: SharedPreferencesService.getArabicLineHeight(),
                      ),
                    ),
                  ),
                  if (widget.translation != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      widget.translation!,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
