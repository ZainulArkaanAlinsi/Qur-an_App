import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';

// Komponen dasar paket desain v2 (docs/design/v2/DESIGN.md §3). Angka-angka
// di berkas ini disalin dari HTML acuan di docs/design/v2/html/, jangan
// dibulatkan sendiri.

/// Kartu v2: permukaan, radius 24, bayangan tipis + cincin 0.5 px.
class SacredCard extends StatelessWidget {
  const SacredCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 24,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tokens.surf,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: tokens.cardShadows,
      ),
      child: child,
    );
  }
}

/// Label bagian huruf kapital ("HARI INI", "MEMBACA") di atas grup.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: SacredText.eyebrow.copyWith(color: tokens.sec),
      ),
    );
  }
}

/// Grup baris gaya iOS v2: satu kartu radius 22, baris [ListRow] di dalamnya.
///
/// Garis pemisah digambar oleh tiap baris, mulai dari tepi kiri teksnya,
/// dan otomatis tidak digambar pada baris terakhir.
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children, this.label});

  final List<Widget> children;

  /// Label bagian opsional di atas kartu.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final card = Container(
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(22),
        boxShadow: tokens.cardShadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++)
            _GroupSlot(last: i == children.length - 1, child: children[i]),
        ],
      ),
    );
    if (label == null) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [SectionLabel(label!), card],
    );
  }
}

class _GroupSlot extends InheritedWidget {
  const _GroupSlot({required this.last, required super.child});

  final bool last;

  static bool isLast(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GroupSlot>()?.last ?? true;

  @override
  bool updateShouldNotify(_GroupSlot old) => old.last != last;
}

/// Baris list v2:
/// `[leading 32–44] 12 [Expanded(judul + subjudul, 1 baris)] 10 [trailing]`.
///
/// Teks di tengah selalu [Expanded] dengan satu baris dan elipsis; elemen
/// kanan berukuran intrinsik sehingga tidak pernah menekan teks sampai turun
/// huruf per huruf (bug lama di Hafalan dan Belajar).
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.titleColor,
    this.semanticsLabel,
    this.subtitleSpan,
  });

  final String title;
  final String? subtitle;

  /// Subjudul bercampur font (mis. nama Arab + keterangan Latin); dipakai
  /// sebagai pengganti [subtitle] bila diisi.
  final InlineSpan? subtitleSpan;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Tampilkan chevron › setelah [trailing].
  final bool chevron;
  final Color? titleColor;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final last = _GroupSlot.isLast(context);
    // Pada teks sangat besar (aksesibilitas) elemen kanan pindah ke bawah
    // teks, seperti daftar iOS; di ukuran biasa tetap satu baris.
    final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6;
    final lines = stacked ? 2 : 1;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: lines,
          overflow: TextOverflow.ellipsis,
          style: SacredText.rowTitle.copyWith(color: titleColor ?? tokens.ink),
        ),
        if (subtitleSpan != null) ...[
          const SizedBox(height: 2),
          Text.rich(
            subtitleSpan!,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
            style: SacredText.rowSubtitle.copyWith(color: tokens.sec),
          ),
        ] else if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
            style: SacredText.rowSubtitle.copyWith(color: tokens.sec),
          ),
        ],
      ],
    );
    final side = (trailing != null || chevron)
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?trailing,
              if (trailing != null && chevron) const SizedBox(width: 8),
              if (chevron)
                LineIcon(
                  SacredIcons.chevronRight,
                  color: tokens.tertiary,
                  size: 17,
                  strokeWidth: 2.2,
                ),
            ],
          )
        : null;
    final content = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.sep, width: .5)),
            ),
      child: stacked
          ? Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      text,
                      if (trailing != null) ...[
                        const SizedBox(height: 6),
                        trailing!,
                      ],
                    ],
                  ),
                ),
                if (chevron) ...[
                  const SizedBox(width: 10),
                  LineIcon(
                    SacredIcons.chevronRight,
                    color: tokens.tertiary,
                    size: 17,
                    strokeWidth: 2.2,
                  ),
                ],
              ],
            )
          : Row(
              children: [
                Expanded(child: text),
                if (side != null) ...[const SizedBox(width: 10), side],
              ],
            ),
    );
    final row = Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(child: content),
        ],
      ),
    );
    final label = semanticsLabel ?? [title, ?subtitle].join(', ');
    if (onTap == null) {
      return Semantics(container: true, label: label, child: row);
    }
    return Semantics(
      button: true,
      container: true,
      label: label,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// Nilai teks di kanan baris ("1 Halaman", "Otomatis"): 15/500 abu.
class RowValue extends StatelessWidget {
  const RowValue(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: SacredText.settingValue.copyWith(color: tokens.sec),
    );
  }
}

/// Warna pill status.
enum PillTone {
  /// Emas lembut: "Hafal", "10 ayat", "MENUNGGU".
  gold,

  /// Hijau lembut: "Menghafal", "2 / 6".
  primary,

  /// Netral: "Perlu murajaah".
  neutral,

  /// Pekat: "berikutnya".
  solid,
}

/// Pill status: tinggi 24, padding 4×10, radius 10, teks 12/800 satu baris.
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.tone = PillTone.gold});

  final String text;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final (bg, fg) = switch (tone) {
      PillTone.gold => (tokens.goldSoft, tokens.goldText),
      PillTone.primary => (tokens.primarySoft, tokens.primaryText),
      PillTone.neutral => (tokens.fill, tokens.ink),
      PillTone.solid => (tokens.cta, tokens.ctaInk),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: SacredText.pill.copyWith(color: fg),
      ),
    );
  }
}

/// Lencana ikon kotak 32 radius 10 dengan glif putih 18 (baris Saya).
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 32,
  });

  final List<String> icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * 10 / 32),
    ),
    child: LineIcon(icon, color: SacredBadge.glyph, size: size * 18 / 32),
  );
}

/// Lingkaran lembut berisi ikon (murajaah di Beranda, kalender di Hafalan).
class SoftIconCircle extends StatelessWidget {
  const SoftIconCircle({
    super.key,
    required this.icon,
    this.size = 44,
    this.iconSize = 20,
    this.gold = true,
  });

  final List<String> icon;
  final double size;
  final double iconSize;

  /// Emas lembut (bawaan) atau hijau lembut.
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gold ? tokens.goldSoft : tokens.primarySoft,
        shape: BoxShape.circle,
      ),
      child: LineIcon(
        icon,
        color: gold ? tokens.goldText : tokens.primaryText,
        size: iconSize,
      ),
    );
  }
}

/// Cincin progres (46/6 di kartu target, 44/5 di baris belajar).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 46,
    this.stroke = 6,
    this.child,
    this.color,
  });

  /// 0–1; nilai di luar rentang dipotong.
  final double value;
  final double size;
  final double stroke;
  final Widget? child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0, 1).toDouble(),
          stroke: stroke,
          track: tokens.surf2,
          color: color ?? tokens.primaryText,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.stroke,
    required this.track,
    required this.color,
  });

  final double value;
  final double stroke;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(circle, 0, math.pi * 2, false, paint..color = track);
    if (value <= 0) return;
    canvas.drawArc(
      circle,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      paint
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.stroke != stroke ||
      old.track != track ||
      old.color != color;
}

/// Bar progres tipis (tinggi 6 di kartu tahap, 5 di baris surah).
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color,
  });

  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: tokens.surf2),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value.clamp(0, 1).toDouble(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color ?? tokens.primaryText,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kolom pencarian v2: tinggi 44, radius 14, latar isi, ikon 18.
class SacredSearchField extends StatelessWidget {
  const SacredSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: tokens.fill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          LineIcon(SacredIcons.search, color: tokens.sec, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: SacredText.searchInput.copyWith(color: tokens.ink),
              cursorColor: tokens.primaryText,
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                hintText: hint,
                hintStyle: SacredText.searchInput.copyWith(color: tokens.sec),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
