import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/lintasan.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/features/home/domain/next_step.dart';
import 'package:quran_app_2025/features/session/domain/session_plan.dart';

/// Kartu hijau "Langkah berikutnya" (docs/design/v6/screens/19-beranda.md
/// §4). Isinya dari `decideNextStep`; paling banyak satu tombol penuh.
class NextStepCard extends StatelessWidget {
  const NextStepCard({
    super.key,
    required this.result,
    required this.onAction,
    this.arabicName,
  });

  final NextStepResult result;
  final ValueChanged<NextStepAction> onAction;

  /// Nama Arab surah bacaan terakhir, untuk ikon mihrab pilihan "Baca".
  final String? arabicName;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    // Kontras tinggi: heroA = heroB → padat, tanpa gradien dan pola.
    final plain = tokens.heroA == tokens.heroB;
    final step = result.primary;
    final still = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.heroA,
          gradient: plain
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [tokens.heroA, tokens.heroB],
                ),
        ),
        child: Stack(
          children: [
            if (!plain)
              Positioned.fill(
                child: GeometricPattern(
                  tile: 56,
                  opacity: .07,
                  color: tokens.onHero,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: still ? 0 : 260),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(.035, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey('${step.kind}|${step.title}'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Eyebrow(badge: step.badge),
                    const SizedBox(height: 8),
                    Semantics(
                      header: true,
                      label: '${step.title}. ${step.subtitle}',
                      excludeSemantics: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SacredText.nextStepTitle.copyWith(
                              color: tokens.onHero,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text.rich(
                            _withCheckIcon(
                              step.subtitle,
                              SacredText.nextStepBody.copyWith(
                                color: tokens.onHeroSec,
                              ),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (step.sessionStep case final current?) ...[
                      const SizedBox(height: 14),
                      ExcludeSemantics(
                        child: Lintasan(
                          count: SessionStep.values.length,
                          progress: current / (SessionStep.values.length - 1),
                          current: current,
                          style: LintasanStyle.onHero,
                          labels: [
                            for (final s in SessionStep.values) s.shortLabel,
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _GoldButton(
                      label: step.cta,
                      onTap: () => onAction(step.action),
                    ),
                    if (result.alternatives.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _Alternatives(
                        alternatives: result.alternatives,
                        arabicName: arabicName,
                        onAction: onAction,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({this.badge});

  final String? badge;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final text = badge;
    return Row(
      children: [
        Expanded(
          child: Text(
            'LANGKAH BERIKUTNYA',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: SacredText.eyebrow.copyWith(color: tokens.goldLine),
          ),
        ),
        if (text != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.onHero.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              text,
              maxLines: 1,
              style: SacredText.pill.copyWith(color: tokens.onHero),
            ),
          ),
      ],
    );
  }
}

/// Tombol CTA utama: `goldButton`, tinggi 52, ikon putar + teks.
class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: tokens.goldButton,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LineIcon(
                    SacredIcons.play,
                    color: tokens.onGoldButton,
                    size: 16,
                    filled: true,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: SacredText.ctaLarge.copyWith(
                        color: tokens.onGoldButton,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paling banyak dua pilihan lain di dalam kartu: latar putih 7%, pemisah
/// putih 10%, baris ≥ 56.
class _Alternatives extends StatelessWidget {
  const _Alternatives({
    required this.alternatives,
    required this.onAction,
    this.arabicName,
  });

  final List<NextStepAlt> alternatives;
  final ValueChanged<NextStepAction> onAction;
  final String? arabicName;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      decoration: BoxDecoration(
        color: tokens.onHero.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.onHero.withValues(alpha: .10)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < alternatives.length; i++) ...[
            if (i > 0)
              Container(height: 1, color: tokens.onHero.withValues(alpha: .10)),
            _AltRow(
              alt: alternatives[i],
              arabicName: arabicName,
              onTap: () => onAction(alternatives[i].action),
            ),
          ],
        ],
      ),
    );
  }
}

class _AltRow extends StatelessWidget {
  const _AltRow({required this.alt, required this.onTap, this.arabicName});

  final NextStepAlt alt;
  final VoidCallback onTap;
  final String? arabicName;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      label: '${alt.eyebrow}: ${alt.text}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
              child: Row(
                children: [
                  _AltIcon(alt: alt, arabicName: arabicName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Eyebrow tidak boleh terpotong; teks data boleh.
                        Text(
                          alt.eyebrow,
                          style: SacredText.eyebrow.copyWith(
                            color: tokens.goldLine,
                          ),
                        ),
                        Text(
                          alt.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SacredText.nextStepAlt.copyWith(
                            color: tokens.onHero,
                          ),
                        ),
                      ],
                    ),
                  ),
                  LineIcon(
                    SacredIcons.chevronRight,
                    color: tokens.onHeroSec,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ikon 32×38: mihrab kecil berisi nama surah Arab untuk "Baca"; equalizer
/// untuk "Diputar"; ikon garis untuk lainnya.
class _AltIcon extends StatelessWidget {
  const _AltIcon({required this.alt, this.arabicName});

  final NextStepAlt alt;
  final String? arabicName;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final name = arabicName;
    if (alt.eyebrow == 'BACA' && name != null) {
      return SizedBox(
        width: 32,
        height: 38,
        child: MihrabFrame(
          background: tokens.onHero.withValues(alpha: .10),
          lineColor: tokens.goldLine.withValues(alpha: .6),
          radius: 6,
          inset: 3,
          child: Padding(
            padding: const EdgeInsets.only(top: 9, left: 2, right: 2),
            child: FittedBox(
              child: Text(
                name,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: SacredText.quran,
                  fontSize: 12,
                  height: 2,
                  color: tokens.goldLine,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final icon = switch (alt.eyebrow) {
      'DIPUTAR' => SacredIcons.equalizer,
      'MURAJAAH' => SacredIcons.layers,
      'DENGAR' => SacredIcons.headphones,
      'BACA' => SacredIcons.book,
      _ => SacredIcons.cap,
    };
    return Container(
      width: 32,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.onHero.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: LineIcon(icon, color: tokens.goldLine, size: 18),
    );
  }
}

/// "✓" tidak ada di font UI yang dibundel; digambar sebagai ikon di dalam
/// teks supaya "Sesi selesai ✓" tetap terlihat.
TextSpan _withCheckIcon(String text, TextStyle style) {
  final parts = text.split('✓');
  return TextSpan(
    style: style,
    children: [
      for (var i = 0; i < parts.length; i++) ...[
        if (i > 0)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: LineIcon(
                SacredIcons.checkCircle,
                color: style.color ?? const Color(0xFFFFFFFF),
                size: (style.fontSize ?? 14) + 1,
                semanticsLabel: 'selesai',
              ),
            ),
          ),
        TextSpan(text: parts[i]),
      ],
    ],
  );
}
