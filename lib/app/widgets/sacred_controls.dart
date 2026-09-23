import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/glass_surface.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';

/// Judul besar gaya iOS beserta subjudul opsional.
class LargeTitle extends StatelessWidget {
  const LargeTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SacredText.largeTitle.copyWith(color: tokens.ink),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: SacredText.footnote.copyWith(color: tokens.sec),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Daftar berkelompok gaya iOS: satu kartu, baris dipisah garis tipis.
class InsetGroupedList extends StatelessWidget {
  const InsetGroupedList({
    super.key,
    required this.children,
    this.header,
    this.radius = 20,
    this.separatorInset = 0,
  });

  final List<Widget> children;
  final String? header;

  /// Pengaturan.html memakai 22; layar lain 20.
  final double radius;

  /// Jarak garis pemisah dari tepi kiri kartu. Baris berikon memasangnya
  /// sejajar teks (16 padding + 30 ikon + 14 jarak = 60).
  final double separatorInset;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              header!.toUpperCase(),
              style: SacredText.eyebrow.copyWith(color: tokens.sec),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: tokens.surf,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: tokens.sep),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: separatorInset,
                    color: tokens.sep,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Segmented control gaya iOS. Label memakai ellipsis supaya tetap terbaca
/// pada text scale besar.
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final Map<T, String> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    // Tinggi 36, radius 12, padding 3; segmen aktif radius 9 berlatar putih
    // dengan dua bayangan (Quran.html, Progres.html, Cari.html).
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: tokens.fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final entry in segments.entries)
            Expanded(
              child: Semantics(
                selected: entry.key == value,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => onChanged(entry.key),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: entry.key == value
                        ? BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 1,
                                offset: Offset(0, 1),
                              ),
                            ],
                          )
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        entry.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (entry.key == value
                                    ? SacredText.segmentActive
                                    : SacredText.segmentIdle)
                                .copyWith(color: tokens.ink),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sakelar gaya iOS (51×31) dengan knob putih.
class IosToggle extends StatelessWidget {
  const IosToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticsLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final enabled = onChanged != null;
    return Semantics(
      label: semanticsLabel,
      toggled: value,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        // Target sentuh tetap >= 44 px meski sakelarnya 31 px.
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 51,
            height: 31,
            decoration: BoxDecoration(
              color: value ? tokens.toggleOn : tokens.surf2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .18),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu tujuan pada [FloatingTabBar].
class SacredTab {
  const SacredTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Tab bar kaca mengambang: kapsul 4 tab + tombol Cari bulat terpisah,
/// dengan scrim gradien di belakangnya (DESIGN_SPEC §5).
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onSelected,
    required this.onSearch,
    this.searchTooltip = 'Cari',
  });

  final List<SacredTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSearch;
  final String searchTooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        IgnorePointer(
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tokens.bg.withValues(alpha: 0), tokens.bg],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            // Label tab sangat kecil; batasi penskalaan agar tidak terpotong.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Row(
                children: [
                  Expanded(
                    child: GlassSurface(
                      borderRadius: BorderRadius.circular(31),
                      tint: tokens.glass,
                      child: SizedBox(
                        height: 62,
                        child: Row(
                          children: [
                            for (var i = 0; i < tabs.length; i++)
                              Expanded(
                                child: _TabButton(
                                  tab: tabs[i],
                                  selected: i == currentIndex,
                                  onTap: () => onSelected(i),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GlassSurface(
                    borderRadius: BorderRadius.circular(31),
                    tint: tokens.glass,
                    child: SizedBox.square(
                      dimension: 62,
                      child: IconButton(
                        tooltip: searchTooltip,
                        onPressed: onSearch,
                        icon: Icon(Icons.search_rounded, color: tokens.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final SacredTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final color = selected ? tokens.primaryText : tokens.sec;
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(27),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: selected
                ? BoxDecoration(
                    color: tokens.primarySoft,
                    borderRadius: BorderRadius.circular(27),
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? tab.activeIcon : tab.icon, color: color),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SacredText.tabLabel.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol lingkaran 40 px seperti di mockup, dengan target sentuh 44 px supaya
/// nyaman ditekan dan tidak bertabrakan dengan tombol sebelahnya.
class SacredCircleButton extends StatelessWidget {
  const SacredCircleButton({
    super.key,
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.background,
    this.bordered = true,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final Color? background;

  /// Lingkaran terang memakai garis rambut dan bayangan tipis; lingkaran
  /// berwarna pekat tidak.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background ?? tokens.surf,
                shape: BoxShape.circle,
                border: bordered ? Border.all(color: tokens.sep) : null,
                boxShadow: bordered
                    ? const [
                        BoxShadow(
                          color: Color(0x0F00281C),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Baris pengaturan gaya Pengaturan.html: lencana ikon 30 px berwarna, label,
/// nilai di kanan, lalu chevron. Tinggi minimum 50 supaya tetap nyaman
/// disentuh meski lencananya hanya 30 px.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.chipColor,
    required this.title,
    this.value,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final List<String> icon;
  final Color chipColor;
  final String title;
  final String? value;
  final String? subtitle;

  /// Kalau diisi, ini menggantikan chevron (mis. sakelar).
  final Widget? trailing;
  final VoidCallback? onTap;

  /// 16 padding kiri + 30 lencana + 14 jarak: garis pemisah sejajar teks.
  static const separatorInset = 60.0;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final row = Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(9),
            ),
            // Lencananya selalu berwarna pekat, jadi glifnya putih di tema
            // apa pun — bukan warna tinta tema yang bisa ikut menggelap.
            child: LineIcon(icon, color: const Color(0xFFFFFFFF), size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 9, 16, 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: SacredText.settingTitle.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: SacredText.cardNote.copyWith(
                              color: tokens.sec,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: SacredText.settingValue.copyWith(
                          color: tokens.sec,
                        ),
                      ),
                    ),
                  ],
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ] else if (onTap != null) ...[
                    const SizedBox(width: 8),
                    LineIcon(
                      SacredIcons.chevronRight,
                      color: tokens.sec,
                      size: 17,
                      strokeWidth: 2.2,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: row,
    );
    if (onTap == null) {
      return Semantics(
        container: true,
        label: value == null ? title : '$title: $value',
        excludeSemantics: trailing == null,
        child: content,
      );
    }
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: value == null ? title : '$title: $value',
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// Bayangan tipis yang dipakai kartu dan tombol bulat di seluruh aplikasi.
///
/// Nilainya dari mockup (`0 1px 2px rgba(0,40,28,0.06)`). Sengaja tidak ikut
/// tema: bayangan hijau yang sangat samar ini tetap benar di latar terang
/// maupun gelap, dan menjadikannya token hanya akan menambah satu nilai yang
/// harus disetel di lima tempat tanpa manfaat.
abstract final class SacredShadows {
  static const card = [
    BoxShadow(color: Color(0x0F00281C), blurRadius: 2, offset: Offset(0, 1)),
  ];
}

/// Kartu lembut bersudut 24: permukaan, garis tepi tipis, bayangan opsional.
///
/// Sebelumnya widget yang sama ditulis tiga kali — di Beranda, Progres, dan
/// Pengaturan — dengan hanya padding yang berbeda.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.shadowed = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Beranda memberi bayangan pada kartunya; layar lain tidak.
  final bool shadowed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.sep),
        boxShadow: shadowed ? SacredShadows.card : null,
      ),
      child: child,
    );
  }
}
