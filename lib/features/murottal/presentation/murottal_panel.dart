import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/murottal/application/now_playing_audio.dart';
import 'package:quran_app_2025/features/murottal/application/player_view_model.dart';
import 'package:quran_app_2025/features/murottal/presentation/ayah_segment_track.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/services/audio_download_service.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';
import 'package:quran_app_2025/widgets/surah_download_button.dart';

/// Panel kontrol Murottal v6 (20-murottal.md §2.4, §5): label ayat + waktu,
/// segmen ayat, transport, lalu pill Timer · Unduh · Rentang.
///
/// Padat `surf`, bukan kaca: teks ayat lewat di belakangnya.
class MurottalPanel extends StatefulWidget {
  const MurottalPanel({
    super.key,
    required this.audio,
    required this.view,
    required this.onError,
    this.failed = false,
    this.onRetry,
    this.downloadService,
    this.reciter,
  });

  final MurottalAudio audio;
  final PlayerView view;

  /// Dipanggil bila perintah ke pemutar gagal (mis. luring).
  final VoidCallback onError;

  /// Pemutar tertutup karena gagal: hanya putar (coba lagi), kecepatan,
  /// timer, unduh, dan rentang yang bisa dipakai.
  final bool failed;
  final VoidCallback? onRetry;

  /// Hanya untuk tes; produksi memakai pengunduh bawaan.
  final AudioDownloadService? downloadService;

  /// Qari terpilih. Per surah saja: Ulang ayat & Rentang memakai qari per
  /// ayat bawaan (keterangan tampil). Sumber yang tidak boleh diunduh
  /// (mis. Quran Foundation): pill Unduh disembunyikan (23-qari.md).
  final Reciter? reciter;

  /// Keterangan untuk qari per surah, atau null.
  static String? perSurahNote(Reciter? reciter) =>
      reciter == null || reciter.perAyat
      ? null
      : 'Qari ini per surah. Ulang ayat memakai '
            '${defaultReciter.displayName}.';

  static const repeatCounts = <int?>[1, 3, 5, 7, null];
  static const sleepMinutes = [5, 10, 15, 30, 45, 60];

  @override
  State<MurottalPanel> createState() => _MurottalPanelState();
}

class _MurottalPanelState extends State<MurottalPanel> {
  late Stream<AyahProgress> _progress = widget.audio.progress;
  AyahProgress? _last;

  @override
  void didUpdateWidget(MurottalPanel old) {
    super.didUpdateWidget(old);
    if (old.audio != widget.audio) _progress = widget.audio.progress;
  }

  MurottalAudio get _audio => widget.audio;
  PlayerView get _view => widget.view;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      widget.onError();
    }
  }

  /// Memuat ulang antrean yang sama dengan jumlah putaran [count] (null =
  /// tanpa batas), tanpa pindah dari ayat yang sedang didengar.
  Future<void> _replay(int? count) => _audio.playRange(
    surah: _view.surah,
    fromAyah: _view.queue.firstAyah,
    toAyah: _view.queue.lastAyah,
    repeatCount: count,
    startAyah: _view.ayah,
    position: _last?.position,
  );

  void _tapRepeat() {
    final current = _audio.repeat;
    final next = PlayerView.nextRepeat(current, hasRange: _view.total > 1);
    unawaited(
      _run(() {
        if (next == AudioRepeat.range) return _replay(null);
        if (current == AudioRepeat.range) return _replay(1);
        return _audio.setRepeat(next);
      }),
    );
  }

  Future<void> _holdRepeat() async {
    final count = await _pick<int?>(
      title: 'Ulang rentang ${_view.rangeLabel}',
      options: {
        for (final count in MurottalPanel.repeatCounts)
          count: count == null ? 'Tanpa batas (∞)' : '$count×',
      },
      selected: _audio.repeat == AudioRepeat.range ? _audio.rangeTarget : 1,
    );
    if (count case (final int? value,)) await _run(() => _replay(value));
  }

  Future<void> _chooseTimer() async {
    final picked = await _pick<int>(
      title: 'Hentikan murottal setelah',
      options: {
        for (final minutes in MurottalPanel.sleepMinutes)
          minutes: '$minutes menit',
        if (_audio.sleepAt != null) 0: 'Matikan timer',
      },
    );
    if (picked case (final int minutes,)) {
      _audio.setSleepTimer(minutes == 0 ? null : Duration(minutes: minutes));
    }
  }

  Future<void> _chooseRange() async {
    final picked = await showMurottalSheet<_RangeChoice>(
      context,
      title: 'Rentang ayat',
      child: _RangeSheet(
        ayahCount: surahCatalog[_view.surah - 1].ayahCount,
        from: _view.queue.firstAyah,
        to: _view.queue.lastAyah,
      ),
    );
    if (picked == null) return;
    await _run(
      () => _audio.playRange(
        surah: _view.surah,
        fromAyah: picked.from,
        toAyah: picked.to,
        repeatCount: picked.count,
      ),
    );
  }

  /// Lembar pilihan sederhana. Hasil dibungkus record supaya pilihan `null`
  /// (∞) bisa dibedakan dari lembar yang ditutup.
  Future<(T,)?> _pick<T>({
    required String title,
    required Map<T, String> options,
    T? selected,
  }) => showMurottalSheet<(T,)>(
    context,
    title: title,
    child: Builder(
      builder: (context) => InsetGroupedList(
        children: [
          for (final entry in options.entries)
            SheetOption(
              label: entry.value,
              selected: entry.key == selected,
              onTap: () => Navigator.pop(context, (entry.key,)),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final large = MediaQuery.textScalerOf(context).scale(10) >= 16;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final note = _audio.sourceNote;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: tokens.floatShadow,
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(22, 16, 22, inset + 12),
      child: StreamBuilder<AyahProgress>(
        stream: _progress,
        builder: (context, snapshot) {
          final progress = snapshot.data;
          if (progress != null) _last = progress;
          final fraction = progress == null
              ? 0.0
              : PlayerView.fractionOf(progress.position, progress.duration);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      _view.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.panelLabel.copyWith(color: tokens.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    progress == null || widget.failed
                        ? PlayerView.timeLabel(Duration.zero, null)
                        : PlayerView.timeLabel(
                            progress.position,
                            progress.duration,
                          ),
                    style: SacredText.panelTime.copyWith(color: tokens.sec),
                  ),
                ],
              ),
              if (note != null) ...[
                const SizedBox(height: 2),
                Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.cardNote.copyWith(color: tokens.sec),
                ),
              ],
              AyahSegmentTrack(
                total: _view.total,
                index: _view.index,
                fraction: widget.failed ? 0 : fraction,
                semanticsValue: _view.label,
                onSelect: widget.failed || _audio.wholeSurah
                    ? null
                    : (index) => unawaited(_run(() => _audio.jumpTo(index))),
              ),
              _Transport(
                audio: _audio,
                view: _view,
                failed: widget.failed,
                showLabels: !large,
                onRepeat: _tapRepeat,
                onRepeatHold: () => unawaited(_holdRepeat()),
                onRetry: widget.onRetry,
                run: _run,
              ),
              if (MurottalPanel.perSurahNote(widget.reciter)
                  case final note?) ...[
                const SizedBox(height: 6),
                Text(
                  note,
                  textAlign: TextAlign.center,
                  style: SacredText.cardNote.copyWith(color: tokens.sec),
                ),
              ],
              const SizedBox(height: 16),
              _Actions(
                large: large,
                children: [
                  _timerPill(tokens),
                  if (widget.reciter?.downloadable ?? true) _downloadPill(),
                  ActionPill(
                    icon: SacredIcons.range,
                    label: _view.rangeLabel,
                    semanticsLabel:
                        'Rentang ayat ${_view.queue.firstAyah} sampai '
                        '${_view.queue.lastAyah}. Ketuk untuk mengubah.',
                    onTap: () => unawaited(_chooseRange()),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _timerPill(SacredTokens tokens) {
    final sleepAt = _audio.sleepAt;
    if (sleepAt == null) {
      return ActionPill(
        icon: SacredIcons.timer,
        label: 'Timer',
        semanticsLabel: 'Timer berhenti',
        onTap: () => unawaited(_chooseTimer()),
      );
    }
    // "Berhenti 10:52" tidak muat di pill sepertiga lebar; ikon timer +
    // jam sudah cukup, kalimat lengkapnya untuk pembaca layar.
    final clock = PlayerView.clockOfDay(sleepAt);
    return ActionPill(
      icon: SacredIcons.timer,
      label: clock,
      active: true,
      semanticsLabel:
          'Timer aktif, berhenti pukul ${clock.replaceAll(':', '.')}. '
          'Ketuk untuk mengubah.',
      onTap: () => unawaited(_chooseTimer()),
    );
  }

  Widget _downloadPill() => SurahDownloadButton(
    // Kunci per surah: status dibaca ulang saat antrean pindah surah.
    key: ValueKey('unduh-${_view.surah}'),
    surah: _view.surah,
    service: widget.downloadService,
    builder: (context, view) => switch (view.status) {
      SurahDownloadStatus.notSaved => ActionPill(
        icon: SacredIcons.download,
        label: 'Unduh',
        semanticsLabel: 'Unduh murottal surah ini',
        onTap: view.onTap,
      ),
      SurahDownloadStatus.checking => const ActionPill(
        icon: SacredIcons.download,
        label: 'Unduh',
        semanticsLabel: 'Menghitung ukuran unduhan',
      ),
      SurahDownloadStatus.downloading => ActionPill(
        icon: SacredIcons.close,
        label: '${(view.fraction * 100).round()}%',
        semanticsLabel:
            'Mengunduh ${(view.fraction * 100).round()}%. '
            'Ketuk untuk membatalkan.',
        onTap: view.onTap,
      ),
      SurahDownloadStatus.saved => ActionPill(
        icon: SacredIcons.checkCircle,
        label: 'Tersimpan',
        active: true,
        semanticsLabel: 'Tersimpan di perangkat. Ketuk untuk hapus.',
        onTap: view.onTap,
      ),
    },
  );
}

/// Ulang · Sebelumnya · Putar/Jeda 78 · Berikutnya · Kecepatan.
class _Transport extends StatelessWidget {
  const _Transport({
    required this.audio,
    required this.view,
    required this.failed,
    required this.showLabels,
    required this.onRepeat,
    required this.onRepeatHold,
    required this.onRetry,
    required this.run,
  });

  final MurottalAudio audio;
  final PlayerView view;
  final bool failed;
  final bool showLabels;
  final VoidCallback onRepeat;
  final VoidCallback onRepeatHold;
  final VoidCallback? onRetry;
  final Future<void> Function(Future<void> Function()) run;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final repeat = audio.repeat;
    final target = audio.rangeTarget;
    final badge = repeat == AudioRepeat.range && target == null
        ? '∞'
        : target != null && target > 1
        ? '$target'
        : null;
    final repeatOn = repeat != AudioRepeat.off || badge != null;
    final looping = repeat == AudioRepeat.range;
    final canMove = !failed && !audio.wholeSurah;
    final canBack = canMove && (!view.isFirst || looping);
    final canNext = canMove && (!view.isLast || looping);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SmallControl(
          label: 'Ulang',
          showLabel: showLabels,
          active: repeatOn,
          badge: badge,
          semanticsLabel: switch (repeat) {
            AudioRepeat.off when badge != null => 'Ulang $badge kali',
            AudioRepeat.off => 'Ulang: mati',
            AudioRepeat.verse => 'Ulang ayat',
            AudioRepeat.range =>
              badge == '∞'
                  ? 'Ulang rentang tanpa batas'
                  : 'Ulang rentang $badge kali',
          },
          hint: 'Ketuk untuk mengganti, tahan untuk memilih jumlah ulang',
          onTap: failed ? null : onRepeat,
          onLongPress: failed ? null : onRepeatHold,
          child: LineIcon(
            SacredIcons.repeat,
            color: repeatOn ? tokens.goldText : tokens.ink,
            size: 20,
            strokeWidth: 2,
          ),
        ),
        _NavButton(
          icon: SacredIcons.skipPrevious,
          label: canBack ? 'Ayat sebelumnya' : 'Ayat pertama',
          onTap: canBack ? () => unawaited(run(audio.previous)) : null,
        ),
        _PlayButton(
          playing: audio.isPlaying && !failed,
          buffering: audio.buffering && !failed,
          onTap: failed ? onRetry : () => unawaited(run(audio.togglePlayPause)),
        ),
        _NavButton(
          icon: SacredIcons.skipNext,
          label: canNext ? 'Ayat berikutnya' : 'Ayat terakhir',
          onTap: canNext ? () => unawaited(run(audio.next)) : null,
        ),
        _SmallControl(
          label: 'Kecepatan',
          showLabel: showLabels,
          semanticsLabel: 'Kecepatan ${PlayerView.speedLabel(audio.speed)}',
          hint: 'Ketuk untuk mengganti kecepatan',
          onTap: () => unawaited(
            run(() => audio.setSpeed(PlayerView.nextSpeed(audio.speed))),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                PlayerView.speedLabel(audio.speed),
                maxLines: 1,
                style: SacredText.buttonSmall.copyWith(color: tokens.ink),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tombol bulat 46 dengan label kecil di bawahnya (Ulang, Kecepatan).
class _SmallControl extends StatelessWidget {
  const _SmallControl({
    required this.label,
    required this.showLabel,
    required this.semanticsLabel,
    required this.hint,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.active = false,
    this.badge,
  });

  final String label;
  final bool showLabel;
  final String semanticsLabel;
  final String hint;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final bool active;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final badge = this.badge;
    return Semantics(
      button: true,
      enabled: onTap != null,
      container: true,
      excludeSemantics: true,
      label: semanticsLabel,
      hint: hint,
      onLongPressHint: onLongPress == null ? null : 'Pilih jumlah ulang',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 66,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? tokens.goldSoft : tokens.bg,
                      shape: BoxShape.circle,
                    ),
                    child: child,
                  ),
                  if (badge != null)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tokens.gold,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          badge,
                          style: SacredText.transportBadge.copyWith(
                            color: tokens.onGold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (showLabel) ...[
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: SacredText.transportLabel.copyWith(color: tokens.sec),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Sebelumnya/Berikutnya 52. Di ujung antrean non-aktif, tidak disembunyikan.
class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, this.onTap});

  final List<String> icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      enabled: onTap != null,
      container: true,
      excludeSemantics: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 52,
          child: Center(
            child: LineIcon(
              icon,
              color: onTap == null ? tokens.tertiary : tokens.ink,
              size: 26,
              filled: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// Putar/Jeda 78 `primary`; saat buffering, cincin progres tipis di tepinya.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.buffering,
    required this.onTap,
  });

  final bool playing;
  final bool buffering;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: buffering ? 'Memuat murottal' : (playing ? 'Jeda' : 'Putar'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 78,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 78,
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.primary,
                  shape: BoxShape.circle,
                  boxShadow: tokens.floatShadows,
                ),
                child: LineIcon(
                  playing ? SacredIcons.pause : SacredIcons.play,
                  color: tokens.surf,
                  size: 30,
                  filled: true,
                ),
              ),
              if (buffering)
                SizedBox.square(
                  dimension: 78,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: tokens.gold,
                    // Tanpa gerak bila "kurangi gerak" aktif.
                    value: MediaQuery.disableAnimationsOf(context) ? .3 : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiga pill sama lebar; pada teks besar mengalir ke baris berikutnya
/// (selebar isinya) supaya label utuh tanpa memakan ruang ayat.
class _Actions extends StatelessWidget {
  const _Actions({required this.large, required this.children});

  final bool large;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (large) {
      return Wrap(spacing: 8, runSpacing: 8, children: children);
    }
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// Pill tinggi 44 di panel Murottal (Timer, Unduh, Rentang).
class ActionPill extends StatelessWidget {
  const ActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    this.onTap,
    this.active = false,
  });

  final List<String> icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      container: true,
      excludeSemantics: true,
      label: semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? tokens.goldSoft : tokens.bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: tokens.sep),
          ),
          child: Row(
            // Di Wrap (teks besar) pill selebar isinya; di baris biasa
            // Expanded memberi lebar tetap dan isinya di tengah.
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LineIcon(
                icon,
                color: active ? tokens.goldText : tokens.ink,
                size: 17,
                strokeWidth: 2,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.actionPill.copyWith(
                    color: enabled ? tokens.ink : tokens.sec,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lembar Murottal: latar `surf`, radius 28, judul, lalu isi.
Future<T?> showMurottalSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  final tokens = Theme.of(context).extension<SacredTokens>()!;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: tokens.surf,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: SacredText.headline.copyWith(color: tokens.ink),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    ),
  );
}

/// Satu pilihan di lembar Murottal; teks `Expanded` + tanda centang.
class SheetOption extends StatelessWidget {
  const SheetOption({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final List<String>? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final icon = this.icon;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[
                LineIcon(icon, color: tokens.primaryText, size: 20),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.settingTitle.copyWith(color: tokens.ink),
                ),
              ),
              if (selected)
                LineIcon(
                  SacredIcons.checkCircle,
                  color: tokens.primaryText,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _RangeChoice = ({int from, int to, int? count});

/// Dari ayat · sampai ayat · jumlah ulang.
class _RangeSheet extends StatefulWidget {
  const _RangeSheet({
    required this.ayahCount,
    required this.from,
    required this.to,
  });

  final int ayahCount;
  final int from;
  final int to;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  late int _from = widget.from;
  late int _to = widget.to;
  int? _count = 1;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InsetGroupedList(
          children: [
            _Stepper(
              label: 'Dari ayat',
              value: _from,
              onChanged: (value) => setState(() {
                _from = value.clamp(1, widget.ayahCount);
                if (_to < _from) _to = _from;
              }),
            ),
            _Stepper(
              label: 'Sampai ayat',
              value: _to,
              onChanged: (value) => setState(() {
                _to = value.clamp(1, widget.ayahCount);
                if (_from > _to) _from = _to;
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('ULANG', style: SacredText.eyebrow.copyWith(color: tokens.sec)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final count in MurottalPanel.repeatCounts)
              _CountChip(
                label: count == null ? '∞' : '$count×',
                semanticsLabel: count == null
                    ? 'Tanpa batas'
                    : 'Ulang $count kali',
                selected: count == _count,
                onTap: () => setState(() => _count = count),
              ),
          ],
        ),
        const SizedBox(height: 20),
        SacredButton(
          label: 'Putar ayat $_from–$_to',
          expand: true,
          onTap: () => Navigator.pop<_RangeChoice>(context, (
            from: _from,
            to: _to,
            count: _count,
          )),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    Widget step(List<String> icon, String hint, int next) => Semantics(
      button: true,
      label: hint,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(next),
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.bg,
                shape: BoxShape.circle,
              ),
              child: LineIcon(icon, color: tokens.ink, size: 18),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SacredText.settingTitle.copyWith(color: tokens.ink),
            ),
          ),
          step(const ['M6 12h12'], '$label dikurangi', value - 1),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: SacredText.panelLabel.copyWith(color: tokens.ink),
            ),
          ),
          step(SacredIcons.plus, '$label ditambah', value + 1),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.semanticsLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? tokens.cta : tokens.bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? tokens.cta : tokens.sep),
          ),
          child: Text(
            label,
            style: SacredText.actionPill.copyWith(
              color: selected ? tokens.ctaInk : tokens.ink,
            ),
          ),
        ),
      ),
    );
  }
}
