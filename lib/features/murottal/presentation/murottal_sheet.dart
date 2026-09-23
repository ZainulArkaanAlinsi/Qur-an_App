import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:quran_app_2025/widgets/surah_download_button.dart';

const _speeds = [0.75, 1.0, 1.25, 1.5];

/// Lembar murottal. Semua kontrolnya terhubung ke pemutar sungguhan; tidak ada
/// tombol yang terlihat aktif tetapi tidak melakukan apa pun.
Future<void> showMurottalSheet(
  BuildContext context, {
  required SurahMeta surah,
  required String arabicName,
  required int verse,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Theme.of(context).extension<SacredTokens>()!.surf,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) =>
      _MurottalSheet(surah: surah, arabicName: arabicName, verse: verse),
);

class _MurottalSheet extends StatefulWidget {
  const _MurottalSheet({
    required this.surah,
    required this.arabicName,
    required this.verse,
  });

  final SurahMeta surah;
  final String arabicName;

  /// Ayat yang diputar bila pemutar sedang kosong.
  final int verse;

  @override
  State<_MurottalSheet> createState() => _MurottalSheetState();
}

class _MurottalSheetState extends State<_MurottalSheet> {
  int get _playingAyah {
    final key = QuranAudioService.instance.playingVerse.value;
    if (key == null) return widget.verse;
    return int.parse(key.split(':').last);
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Murottal belum dapat diputar. Periksa koneksi.'),
        ),
      );
    }
  }

  Future<void> _chooseTimer() async {
    final audio = QuranAudioService.instance;
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [15, 30, 60])
              ListTile(
                leading: const Icon(CupertinoIcons.timer),
                title: Text('Berhenti setelah $option menit'),
                onTap: () => Navigator.pop(context, option),
              ),
            if (audio.sleepAt.value != null)
              ListTile(
                leading: const Icon(CupertinoIcons.clear),
                title: const Text('Batalkan timer'),
                onTap: () => Navigator.pop(context, 0),
              ),
          ],
        ),
      ),
    );
    if (minutes == null) return;
    audio.setSleepTimer(minutes == 0 ? null : Duration(minutes: minutes));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final audio = QuranAudioService.instance;
    final reciter = SharedPreferencesService.getReciter();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Per ayat · ${reciter.bitrate ?? 128} kbps',
                    style: SacredText.eyebrow.copyWith(color: tokens.sec),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(CupertinoIcons.xmark, color: tokens.sec, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: ConstrainedBox(
                // Tinggi minimum saja; bingkainya boleh tumbuh supaya nama
                // surah tidak terpotong pada teks besar.
                constraints: const BoxConstraints(
                  minWidth: 168,
                  maxWidth: 168,
                  minHeight: 216,
                ),
                child: MihrabFrame(
                  child: Stack(
                    children: [
                      const Positioned.fill(child: GeometricPattern()),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
                          child: Text(
                            widget.arabicName,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: SacredText.quran,
                              fontSize: 26,
                              height: 2,
                              color: tokens.artInk,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<String?>(
              valueListenable: audio.playingVerse,
              builder: (context, playing, _) {
                final ayah = _playingAyah;
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.surah.displayName,
                            style: SacredText.cardTitle.copyWith(
                              color: tokens.ink,
                              fontSize: 24,
                            ),
                          ),
                          Text(
                            'Ayat $ayah · ${QuranAudioService.reciterName}',
                            style: SacredText.footnote.copyWith(
                              color: tokens.sec,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _BookmarkButton(surah: widget.surah.number, ayah: ayah),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            const _ProgressBar(),
            const SizedBox(height: 8),
            _Controls(
              onGuard: _guard,
              fallbackVerse: widget.verse,
              surah: widget.surah.number,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ValueListenableBuilder<AudioRepeat>(
                  valueListenable: audio.repeat,
                  builder: (context, repeat, _) => _Chip(
                    icon: CupertinoIcons.repeat,
                    // Pemutar hanya punya ulang tanpa batas, bukan hitungan,
                    // jadi labelnya tidak menjanjikan "3x".
                    label: repeat == AudioRepeat.verse
                        ? 'Ulangi ayat: aktif'
                        : 'Ulangi ayat',
                    active: repeat == AudioRepeat.verse,
                    onTap: () => _guard(
                      () => audio.setRepeat(
                        repeat == AudioRepeat.verse
                            ? AudioRepeat.off
                            : AudioRepeat.verse,
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<DateTime?>(
                  valueListenable: audio.sleepAt,
                  builder: (context, sleepAt, _) => _Chip(
                    icon: CupertinoIcons.timer,
                    label: sleepAt == null
                        ? 'Timer'
                        : 'Berhenti ${_clock(sleepAt)}',
                    active: sleepAt != null,
                    onTap: _chooseTimer,
                  ),
                ),
                SurahDownloadButton(surah: widget.surah.number),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Waktu mendengar dicatat terpisah dari menit membaca.',
              style: SacredText.footnote.copyWith(color: tokens.sec),
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}.'
      '${at.minute.toString().padLeft(2, '0')}';
}

class _BookmarkButton extends StatefulWidget {
  const _BookmarkButton({required this.surah, required this.ayah});

  final int surah;
  final int ayah;

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton> {
  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final saved = SharedPreferencesService.isBookmarked(
      widget.surah,
      widget.ayah,
    );
    return IconButton(
      tooltip: saved ? 'Hapus bookmark' : 'Simpan bookmark',
      onPressed: () async {
        if (saved) {
          await SharedPreferencesService.removeBookmark(
            widget.surah,
            widget.ayah,
          );
        } else {
          await SharedPreferencesService.saveBookmark(
            widget.surah,
            widget.ayah,
          );
        }
        if (mounted) setState(() {});
      },
      icon: Icon(
        saved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
        color: saved ? tokens.primaryText : tokens.sec,
      ),
    );
  }
}

/// Bar kemajuan ayat yang sedang diputar, memakai posisi pemutar sungguhan.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final audio = QuranAudioService.instance;
    return StreamBuilder<Duration?>(
      stream: audio.durationStream,
      builder: (context, durationSnapshot) => StreamBuilder<Duration>(
        stream: audio.positionStream,
        builder: (context, positionSnapshot) {
          final duration = durationSnapshot.data ?? Duration.zero;
          final position = positionSnapshot.data ?? Duration.zero;
          final fraction = duration.inMilliseconds == 0
              ? 0.0
              : (position.inMilliseconds / duration.inMilliseconds).clamp(
                  0.0,
                  1.0,
                );
          return Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  backgroundColor: tokens.surf2,
                  valueColor: AlwaysStoppedAnimation(tokens.primary),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _mmss(position),
                    style: SacredText.footnote.copyWith(color: tokens.sec),
                  ),
                  Text(
                    duration == Duration.zero ? '--:--' : _mmss(duration),
                    style: SacredText.footnote.copyWith(color: tokens.sec),
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

class _Controls extends StatelessWidget {
  const _Controls({
    required this.onGuard,
    required this.fallbackVerse,
    required this.surah,
  });

  final Future<void> Function(Future<void> Function()) onGuard;
  final int fallbackVerse;
  final int surah;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final audio = QuranAudioService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        audio.queue,
        audio.isPlaying,
        audio.buffering,
        audio.speed,
      ]),
      builder: (context, _) {
        final idle = audio.queue.value == null;
        final playing = audio.isPlaying.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: 'Ayat sebelumnya',
              onPressed: idle ? null : () => onGuard(audio.previous),
              icon: const Icon(CupertinoIcons.backward_end, size: 22),
            ),
            SizedBox.square(
              dimension: 62,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.cta,
                  foregroundColor: tokens.ctaInk,
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                onPressed: () => onGuard(() async {
                  if (idle) {
                    await audio.toggle(surah: surah, ayah: fallbackVerse);
                  } else {
                    await audio.togglePlayPause();
                  }
                }),
                child: audio.buffering.value
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Icon(
                        playing
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        size: 26,
                      ),
              ),
            ),
            IconButton(
              tooltip: 'Ayat berikutnya',
              onPressed: idle ? null : () => onGuard(audio.next),
              icon: const Icon(CupertinoIcons.forward_end, size: 22),
            ),
            TextButton(
              onPressed: idle
                  ? null
                  : () {
                      final next =
                          _speeds[(_speeds.indexOf(audio.speed.value) + 1) %
                              _speeds.length];
                      onGuard(() => audio.setSpeed(next));
                    },
              child: Text(
                '${audio.speed.value}×',
                style: SacredText.footnote.copyWith(
                  color: idle ? tokens.sec : tokens.primaryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? tokens.primarySoft : tokens.fill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? tokens.primaryText : tokens.sec,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: SacredText.footnote.copyWith(
                color: active ? tokens.primaryText : tokens.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
