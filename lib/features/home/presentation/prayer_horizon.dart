import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/lintasan.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/features/home/domain/home_snapshot.dart';
import 'package:quran_app_2025/features/home/domain/prayer_horizon.dart';

/// Kartu horizon lima waktu salat di atas Beranda
/// (docs/design/v6/screens/19-beranda.md §3). Titik "sekarang" bergeser
/// tiap menit, bukan animasi terus-menerus.
class PrayerHorizon extends StatefulWidget {
  const PrayerHorizon({
    super.key,
    required this.snapshot,
    required this.now,
    required this.onOpen,
    required this.onSetCity,
    required this.onRetry,
  });

  final HomeSnapshot snapshot;
  final DateTime Function() now;

  /// Ketuk kartu → layar Salat.
  final VoidCallback onOpen;

  /// "Atur kota untuk jadwal salat".
  final VoidCallback onSetCity;

  /// "Coba lagi" saat jadwal belum dimuat.
  final VoidCallback onRetry;

  @override
  State<PrayerHorizon> createState() => _PrayerHorizonState();
}

class _PrayerHorizonState extends State<PrayerHorizon> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final s = widget.snapshot;
    final day = s.prayer;
    final model = day == null
        ? null
        : buildHorizon(day, widget.now(), tomorrow: s.prayerTomorrow);
    final Widget child;
    if (s.prayerStatus == PrayerStatus.belumDiatur) {
      child = _Message(
        text: 'Atur kota untuk jadwal salat',
        onTap: widget.onSetCity,
      );
    } else if (s.prayerStatus == PrayerStatus.memuat && model == null) {
      child = const _Skeleton();
    } else if (model == null) {
      // Luring tanpa cache: keadaan sebenarnya, bukan jam contoh.
      child = _Message(
        text: 'Jadwal salat belum dimuat · Coba lagi',
        onTap: widget.onRetry,
      );
    } else {
      child = _HorizonBody(model: model);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.sep),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [tokens.surf, tokens.skyHorizon],
          stops: const [.45, 1],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: model == null ? null : widget.onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _HorizonBody extends StatelessWidget {
  const _HorizonBody({required this.model});

  final HorizonModel model;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final next = model.nodes[model.nextIndex];
    final nextName = model.isTomorrow ? 'Subuh besok' : next.label;
    final nextTime = model.isTomorrow ? model.tomorrowTime : next.time;
    final left = model.untilNext;
    final semantics = [
      'Salat berikutnya $nextName',
      if (nextTime != null) 'pukul ${nextTime.replaceAll(':', '.')}',
      if (left != null) _spokenCountdown(left),
    ].join(', ');
    final large = MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6;
    return Semantics(
      container: true,
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Teks besar: pill pindah ke bawah judul, judul boleh turun baris
          // (label tidak dipotong, CLAUDE.md).
          if (large) ...[
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Berikutnya ',
                    style: SacredText.horizonLabel.copyWith(color: tokens.sec),
                  ),
                  TextSpan(
                    text: nextTime == null ? nextName : '$nextName $nextTime',
                    style: SacredText.horizonNext.copyWith(color: tokens.ink),
                  ),
                ],
              ),
            ),
            if (left != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: _Pill(text: horizonCountdown(left)),
              ),
            ],
          ] else
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Berikutnya ',
                          style: SacredText.horizonLabel.copyWith(
                            color: tokens.sec,
                          ),
                        ),
                        TextSpan(
                          text: nextTime == null
                              ? nextName
                              : '$nextName $nextTime',
                          style: SacredText.horizonNext.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (left != null) ...[
                  const SizedBox(width: 8),
                  _Pill(text: horizonCountdown(left)),
                ],
              ],
            ),
          const SizedBox(height: 10),
          if (large)
            // Teks 2.0: daftar vertikal lima baris (DESIGN v6 §7).
            for (var i = 0; i < model.nodes.length; i++)
              _NodeRow(
                node: model.nodes[i],
                next: !model.isTomorrow && i == model.nextIndex,
              )
          else ...[
            Lintasan(
              count: model.nodes.length,
              progress: model.nowPosition,
              current: model.isTomorrow ? null : model.nextIndex,
              nowMarker: true,
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, box) {
                final xs = Lintasan.dotPositions(
                  box.maxWidth,
                  model.nodes.length,
                );
                final slot =
                    (box.maxWidth - 2 * Lintasan.edge) /
                    (model.nodes.length - 1);
                return SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(30),
                  child: Stack(
                    children: [
                      for (var i = 0; i < model.nodes.length; i++)
                        Positioned(
                          left: (xs[i] - slot / 2).clamp(
                            0.0,
                            box.maxWidth - slot,
                          ),
                          width: slot,
                          top: 0,
                          child: _NodeLabel(
                            node: model.nodes[i],
                            next: !model.isTomorrow && i == model.nextIndex,
                            align: i == 0
                                ? TextAlign.left
                                : i == model.nodes.length - 1
                                ? TextAlign.right
                                : TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  static String _spokenCountdown(Duration left) {
    final minutes = left.inMinutes;
    if (minutes < 60) return '$minutes menit lagi';
    return '${minutes ~/ 60} jam ${minutes % 60} menit lagi';
  }
}

/// Nama + jam di bawah titik. Salat berikutnya: nama tebal, jam `goldText`
/// (`tertiary` tidak dipakai untuk teks; kontrasnya < 4.5).
class _NodeLabel extends StatelessWidget {
  const _NodeLabel({
    required this.node,
    required this.next,
    required this.align,
  });

  final HorizonNode node;
  final bool next;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Column(
      crossAxisAlignment: switch (align) {
        TextAlign.left => CrossAxisAlignment.start,
        TextAlign.right => CrossAxisAlignment.end,
        _ => CrossAxisAlignment.center,
      },
      children: [
        Text(
          node.label,
          maxLines: 1,
          softWrap: false,
          style: next
              ? SacredText.withWeight(
                  SacredText.dotName,
                  800,
                ).copyWith(color: tokens.ink)
              : SacredText.dotName.copyWith(color: tokens.ink),
        ),
        Text(
          node.time,
          maxLines: 1,
          softWrap: false,
          style: next
              ? SacredText.withWeight(
                  SacredText.dotTime,
                  800,
                ).copyWith(color: tokens.goldText)
              : SacredText.dotTime.copyWith(color: tokens.sec),
        ),
      ],
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({required this.node, required this.next});

  final HorizonNode node;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final style = next
        ? SacredText.withWeight(SacredText.nextStepBody, 800)
        : SacredText.nextStepBody;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              node.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(color: tokens.ink),
            ),
          ),
          Text(
            node.time,
            style: style.copyWith(color: next ? tokens.goldText : tokens.sec),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: SacredText.pill.copyWith(
          color: tokens.primaryText,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: SacredText.horizonNext.copyWith(color: tokens.ink),
              ),
            ),
            LineIcon(SacredIcons.chevronRight, color: tokens.sec, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Kerangka setinggi kartu saat memuat, tanpa spinner.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: tokens.surf2,
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return Semantics(
      label: 'Memuat jadwal salat',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(170, 18),
          const SizedBox(height: 16),
          bar(double.infinity, 8),
          const SizedBox(height: 14),
          bar(double.infinity, 26),
        ],
      ),
    );
  }
}
