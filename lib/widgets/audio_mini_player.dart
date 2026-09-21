import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

/// Murottal controls shared by the reader and the main shell. Hidden while
/// nothing is loaded.
class AudioMiniPlayer extends StatelessWidget {
  const AudioMiniPlayer({super.key, this.onOpen});

  /// Opens the reader at the playing verse; omitted inside the reader.
  final void Function(SurahMeta surah, int ayah)? onOpen;

  @override
  Widget build(BuildContext context) {
    final audio = QuranAudioService.instance;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        audio.queue,
        audio.playingVerse,
        audio.isPlaying,
        audio.buffering,
        audio.repeat,
      ]),
      builder: (context, _) {
        final queue = audio.queue.value;
        final key = audio.playingVerse.value;
        if (queue == null || key == null) return const SizedBox.shrink();
        final surah = surahCatalog[queue.surah - 1];
        final ayah = int.parse(key.split(':').last);
        final repeat = audio.repeat.value;
        final subtitle = switch (repeat) {
          AudioRepeat.off => QuranAudioService.reciterName,
          AudioRepeat.verse => 'Mengulang ayat $ayah',
          AudioRepeat.range =>
            'Mengulang ayat ${queue.firstAyah}–${queue.lastAyah}',
        };
        return Semantics(
          container: true,
          label: 'Pemutar murottal',
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
            decoration: BoxDecoration(
              color: SacredTheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconTheme.merge(
              data: const IconThemeData(color: Colors.white),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onOpen == null ? null : () => onOpen!(surah, ayah),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${surah.displayName} · $ayah',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFFD7F0E4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: audio.previous,
                    icon: const Icon(Icons.skip_previous_rounded),
                    tooltip: 'Ayat sebelumnya',
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: SacredTheme.gold,
                      foregroundColor: SacredTheme.primary,
                    ),
                    onPressed: audio.togglePlayPause,
                    icon: audio.buffering.value
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: SacredTheme.primary,
                            ),
                          )
                        : Icon(
                            audio.isPlaying.value
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                    tooltip: audio.isPlaying.value ? 'Jeda' : 'Putar',
                  ),
                  IconButton(
                    onPressed: audio.next,
                    icon: const Icon(Icons.skip_next_rounded),
                    tooltip: 'Ayat berikutnya',
                  ),
                  PopupMenuButton<AudioRepeat>(
                    tooltip: 'Pengulangan',
                    icon: Icon(
                      repeat == AudioRepeat.verse
                          ? Icons.repeat_one_on_rounded
                          : repeat == AudioRepeat.range
                          ? Icons.repeat_on_rounded
                          : Icons.repeat_rounded,
                      color: repeat == AudioRepeat.off
                          ? Colors.white
                          : SacredTheme.gold,
                    ),
                    initialValue: repeat,
                    onSelected: (mode) async {
                      if (mode == AudioRepeat.range) {
                        await _chooseRange(context, surah, ayah);
                      } else {
                        await audio.setRepeat(mode);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: AudioRepeat.off,
                        child: Text('Putar berurutan'),
                      ),
                      PopupMenuItem(
                        value: AudioRepeat.verse,
                        child: Text('Ulangi ayat ini'),
                      ),
                      PopupMenuItem(
                        value: AudioRepeat.range,
                        child: Text('Ulangi rentang ayat…'),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: audio.stop,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Tutup pemutar',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _chooseRange(
  BuildContext context,
  SurahMeta surah,
  int currentAyah,
) async {
  final count = surah.ayahCount;
  var from = currentAyah;
  var to = (currentAyah + 4).clamp(1, count);
  final picked = await showModalBottomSheet<(int, int)>(
    context: context,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ulangi rentang ayat',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Cocok untuk murajaah hafalan. Rentang diputar terus sampai dihentikan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _AyahDropdown(
                      label: 'Dari ayat',
                      value: from,
                      min: 1,
                      max: count,
                      onChanged: (value) => setSheetState(() {
                        from = value;
                        if (to < from) to = from;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AyahDropdown(
                      // Rebuilt when the lower bound moves so a stale value
                      // never falls outside the item list.
                      key: ValueKey('to-$from'),
                      label: 'Sampai ayat',
                      value: to,
                      min: from,
                      max: count,
                      onChanged: (value) => setSheetState(() => to = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, (from, to)),
                icon: const Icon(Icons.repeat_rounded),
                label: Text('Ulangi ayat $from–$to'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (picked == null) return;
  try {
    await QuranAudioService.instance.playRange(
      surah: surah.number,
      fromAyah: picked.$1,
      toAyah: picked.$2,
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rentang belum dapat diputar. Periksa koneksi internet.'),
      ),
    );
  }
}

class _AyahDropdown extends StatelessWidget {
  const _AyahDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    initialValue: value,
    isExpanded: true,
    menuMaxHeight: 320,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (var ayah = min; ayah <= max; ayah++)
        DropdownMenuItem(value: ayah, child: Text('$ayah')),
    ],
    onChanged: (ayah) {
      if (ayah != null) onChanged(ayah);
    },
  );
}
