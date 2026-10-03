import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/murottal/application/now_playing_audio.dart';
import 'package:quran_app_2025/features/murottal/presentation/ayah_segment_track.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

/// Baris "sedang diputar" (docs/design/v6/screens/21-dock.md), dipakai dock
/// dan pembaca. Kosong bila tidak ada yang diputar.
///
/// Gestur: ketuk atau geser ke atas → [onOpen]; geser ke bawah → hentikan
/// murottal, lalu SnackBar "Murottal dihentikan" dengan **Urungkan** selama
/// 4 detik. Pembaca layar mendapat aksi pengganti "Buka pemutar" dan
/// "Hentikan murottal".
class NowPlayingRow extends StatefulWidget {
  const NowPlayingRow({
    super.key,
    required this.audio,
    required this.onOpen,
    this.heroTag,
  });

  final NowPlayingAudio audio;
  final VoidCallback onOpen;

  /// Tag `Hero` mihrab mini → plakat Murottal. Hanya untuk satu rute.
  final Object? heroTag;

  /// Tag yang dipakai dock dan layar Murottal.
  static const murottalHeroTag = 'murottal-mihrab';

  /// Tinggi baris tanpa jalur segmen (21-dock.md: 62).
  static const height = 62.0;

  /// Batas geser (px) dan kecepatan (px/dtk) untuk membuka/menghentikan.
  static const swipeDistance = 40.0;
  static const swipeVelocity = 600.0;

  @override
  State<NowPlayingRow> createState() => _NowPlayingRowState();
}

class _NowPlayingRowState extends State<NowPlayingRow> {
  // Satu langganan posisi per baris, bukan per build.
  late final Stream<double> _fraction = widget.audio.verseFraction
      .asBroadcastStream();
  double _drag = 0;

  Future<void> _stop() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final audio = widget.audio;
    final point = audio.resumePoint();
    await audio.stop();
    if (messenger == null || point == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Murottal dihentikan'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Urungkan',
            onPressed: () => unawaited(audio.restore(point)),
          ),
        ),
      );
  }

  void _endDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final dy = _drag;
    _drag = 0;
    if (dy < -NowPlayingRow.swipeDistance ||
        velocity < -NowPlayingRow.swipeVelocity) {
      widget.onOpen();
    } else if (dy > NowPlayingRow.swipeDistance) {
      unawaited(_stop());
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.audio,
    builder: (context, _) {
      final audio = widget.audio;
      final queue = audio.queue;
      final ayah = NowPlayingAudio.ayahOf(audio.playingVerse);
      if (queue == null || ayah == null) return const SizedBox.shrink();
      final tokens = Theme.of(context).extension<SacredTokens>()!;
      final surah = surahCatalog[queue.surah - 1];
      final title = '${surah.displayName} · Ayat $ayah';
      final subtitle = _subtitle(audio, queue);
      final mihrab = _MiniMihrab(ayah: ayah, tokens: tokens);
      return Semantics(
        container: true,
        label: 'Sedang diputar: ${surah.displayName} ayat $ayah. $subtitle',
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Buka pemutar'): widget.onOpen,
          const CustomSemanticsAction(label: 'Hentikan murottal'): () =>
              unawaited(_stop()),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onOpen,
          onVerticalDragStart: (_) => _drag = 0,
          onVerticalDragUpdate: (d) => _drag += d.delta.dy,
          onVerticalDragEnd: _endDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: NowPlayingRow.height - 8,
                child: Row(
                  children: [
                    widget.heroTag == null
                        ? mihrab
                        : Hero(tag: widget.heroTag!, child: mihrab),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SacredText.nowPlayingTitle.copyWith(
                                color: tokens.ink,
                              ),
                            ),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SacredText.cardNote.copyWith(
                                color: tokens.sec,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _RoundButton(
                      tooltip: audio.isPlaying ? 'Jeda' : 'Putar',
                      background: tokens.primary,
                      onTap: () => unawaited(audio.togglePlayPause()),
                      child: LineIcon(
                        audio.isPlaying ? SacredIcons.pause : SacredIcons.play,
                        color: tokens.surf,
                        size: 18,
                        filled: true,
                      ),
                    ),
                    _RoundButton(
                      tooltip: 'Ayat berikutnya',
                      onTap: () => unawaited(audio.next()),
                      child: LineIcon(
                        SacredIcons.next,
                        color: tokens.ink,
                        size: 20,
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: StreamBuilder<double>(
                  stream: _fraction,
                  builder: (context, snapshot) => AyahSegmentTrack(
                    mini: true,
                    total: queue.length,
                    index: ayah - queue.firstAyah,
                    fraction: snapshot.data ?? 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  /// Status di bawah judul (21-dock.md): qari · per ayat, ulang, rentang,
  /// memuat, sumber cadangan.
  static String _subtitle(NowPlayingAudio audio, AudioQueue queue) {
    if (audio.buffering) return 'Memuat…';
    final pass = audio.rangeTarget == null
        ? ''
        : ' · ${audio.rangePass}/${audio.rangeTarget}';
    return switch (audio.repeat) {
      AudioRepeat.range => 'Rentang ${queue.firstAyah}–${queue.lastAyah}$pass',
      AudioRepeat.verse => 'Ulang ayat$pass',
      AudioRepeat.off =>
        audio.sourceNote != null
            ? 'Sumber cadangan'
            : '${audio.reciterName} · per ayat',
    };
  }
}

/// Mihrab mini 34×42 berisi nomor ayat (21-dock.md).
class _MiniMihrab extends StatelessWidget {
  const _MiniMihrab({required this.ayah, required this.tokens});

  final int ayah;
  final SacredTokens tokens;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 34,
    height: 42,
    child: MihrabFrame(
      background: tokens.heroA,
      lineColor: tokens.goldLine.withValues(alpha: .7),
      radius: 7,
      inset: 3,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(
          child: Text(
            '$ayah',
            maxLines: 1,
            style: SacredText.pill.copyWith(color: tokens.goldLine),
          ),
        ),
      ),
    ),
  );
}

/// Tombol 42 tanpa ripple Material (LIQUID_GLASS.md §6): umpan baliknya
/// skala 0.94 saat ditekan.
class _RoundButton extends StatefulWidget {
  const _RoundButton({
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
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.tooltip,
    excludeSemantics: true,
    child: Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: AnimatedScale(
              scale: _down ? .94 : 1,
              duration: const Duration(milliseconds: 90),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: widget.background == null
                    ? null
                    : BoxDecoration(
                        color: widget.background,
                        shape: BoxShape.circle,
                      ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
