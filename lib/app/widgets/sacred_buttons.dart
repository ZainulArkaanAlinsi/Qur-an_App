import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';

/// Gaya tombol v2 (docs/design/v2/html/).
enum ButtonTone {
  /// CTA pekat: "Lanjut", "Lanjutkan" di Belajar.
  cta,

  /// Emas di atas kartu hero hijau: "Lanjutkan", "Mulai sesi".
  gold,

  /// Hijau lembut: "Buka kata berikutnya", "Unduh".
  soft,

  /// Isi abu tipis: tombol sekunder kecil.
  fill,

  /// Permukaan kartu berbayang: "Kiblat".
  surface,
}

/// Tombol berlabel dengan radius penuh. Label tidak pernah dipotong: bila
/// ruangnya sempit, tombol ikut melebar/menurun, bukan memberi elipsis
/// (CLAUDE.md: "Label tidak boleh terpotong").
class SacredButton extends StatelessWidget {
  const SacredButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconFilled = false,
    this.tone = ButtonTone.cta,
    this.height = 48,
    this.expand = false,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final String label;
  final VoidCallback? onTap;
  final List<String>? icon;

  /// Ikon isi (putar) atau garis.
  final bool iconFilled;
  final ButtonTone tone;
  final double height;

  /// Selebar induknya.
  final bool expand;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final (bg, fg, iconColor) = switch (tone) {
      ButtonTone.cta => (tokens.cta, tokens.ctaInk, tokens.ctaInk),
      ButtonTone.gold => (tokens.artInk, tokens.onGold, tokens.onGold),
      ButtonTone.soft => (
        tokens.primarySoft,
        tokens.primaryText,
        tokens.primaryText,
      ),
      ButtonTone.fill => (tokens.fill, tokens.ink, tokens.ink),
      ButtonTone.surface => (tokens.surf, tokens.ink, tokens.primaryText),
    };
    final style = (textStyle ?? SacredText.button).copyWith(color: fg);
    final radius = BorderRadius.circular(height / 2);
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          LineIcon(
            icon!,
            color: iconColor,
            size: iconFilled ? 15 : 18,
            filled: iconFilled,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(label, style: style, textAlign: TextAlign.center),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      // Nonaktif harus terlihat nonaktif, bukan tombol yang tampak rusak.
      child: Opacity(
        opacity: onTap == null ? .4 : 1,
        child: Material(
          color: bg,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Container(
              constraints: BoxConstraints(minHeight: height),
              padding: padding,
              decoration: tone == ButtonTone.surface
                  ? BoxDecoration(
                      borderRadius: radius,
                      boxShadow: tokens.cardShadows,
                    )
                  : null,
              alignment: expand ? Alignment.center : null,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol ikon bulat v2 (36–48): isi abu tipis, permukaan berbayang, atau
/// warna bebas.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 40,
    this.iconSize = 20,
    this.background,
    this.iconColor,
    this.surface = false,
    this.filled = false,
    this.strokeWidth = 1.9,
    this.border,
  });

  final List<String> icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? iconColor;

  /// Latar kartu + bayangan (Cari & Bookmark di Beranda).
  final bool surface;

  /// Ikon isi.
  final bool filled;
  final double strokeWidth;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final bg = background ?? (surface ? tokens.surf : tokens.fill);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: size / 2 + 4,
          // Target sentuh minimal 44 meski lingkarannya 36–40.
          child: SizedBox.square(
            dimension: size < 44 ? 44 : size,
            child: Center(
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: border,
                  boxShadow: surface ? tokens.cardShadows : null,
                ),
                child: LineIcon(
                  icon,
                  color: iconColor ?? tokens.ink,
                  size: iconSize,
                  filled: filled,
                  strokeWidth: strokeWidth,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tautan balik "‹ Nama" di atas judul besar layar turunan: tinggi 44,
/// chevron 26, teks 17/600 primaryText.
class BackLink extends StatelessWidget {
  const BackLink({super.key, required this.label, this.onTap});

  final String label;

  /// Bawaan: `Navigator.maybePop`.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      label: 'Kembali ke $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LineIcon(
                SacredIcons.chevronLeft,
                color: tokens.primaryText,
                size: 26,
                strokeWidth: 2.2,
              ),
              Text(
                label,
                maxLines: 1,
                style: SacredText.backLabel.copyWith(color: tokens.primaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kepala layar v2: tautan balik opsional, judul besar EB Garamond 42, dan
/// subjudul 14, dengan elemen kanan opsional sejajar judul.
///
/// Posisi atas mengikuti mockup: layar utama mulai 58 dari tepi atas,
/// layar turunan 52 (termasuk tinggi bilah status yang dianggap 47).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.backLabel,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;

  /// Diisi pada layar turunan ("Beranda", "Saya", …).
  final String? backLabel;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: SacredText.screenTitle.copyWith(color: tokens.ink),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: SacredText.screenSubtitle.copyWith(color: tokens.sec),
          ),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (backLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
            child: BackLink(label: backLabel!, onTap: onBack),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, backLabel != null ? 6 : 11, 20, 0),
          child: trailing == null
              ? titleBlock
              : Row(
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ),
        ),
      ],
    );
  }
}
