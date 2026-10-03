import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/features/murottal/application/murottal_verses.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Daftar ayat dalam antrean murottal yang mengikuti audio
/// (docs/design/v6/screens/20-murottal.md §3).
///
/// - Saat [activeAyah] berganti, daftar bergulir ke ayat itu (30% dari atas,
///   380 ms; langsung lompat bila "kurangi gerak" aktif).
/// - Digulir sendiri: mengikuti berhenti 6 detik dan muncul pill
///   "Kembali ke ayat yang diputar".
/// - Teks ayat tanpa efek apa pun: tidak ada `Opacity`/`ShaderMask`, tidak
///   di-clip, tinggi baris 2.15.
class AyahFollowList extends StatefulWidget {
  const AyahFollowList({
    super.key,
    required this.verses,
    required this.firstAyah,
    required this.lastAyah,
    required this.activeAyah,
    required this.showTranslation,
    this.onTapAyah,
    this.onLongPressAyah,
    this.bottomPadding = 0,
  });

  final MurottalVerses verses;
  final int firstAyah;
  final int lastAyah;

  /// Ayat yang diputar; null bila posisinya tidak diketahui (diputar per
  /// surah) sehingga tidak ada yang disorot dan daftar tidak bergulir sendiri.
  final int? activeAyah;
  final bool showTranslation;

  /// Ketuk ayat: lompat & putar dari ayat itu. Null = tidak bisa lompat.
  final ValueChanged<int>? onTapAyah;

  /// Tahan ayat: menu Bookmark · Buka di pembaca.
  final ValueChanged<int>? onLongPressAyah;

  /// Ruang di bawah daftar (bagian yang tertutup panel kontrol).
  final double bottomPadding;

  /// Posisi ayat aktif dari atas daftar (DESIGN v6 §7).
  static const alignment = .3;
  static const followPause = Duration(seconds: 6);

  @override
  State<AyahFollowList> createState() => _AyahFollowListState();
}

class _AyahFollowListState extends State<AyahFollowList> {
  final _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  bool _following = true;
  Timer? _resume;

  int _indexOf(int ayah) =>
      (ayah - widget.firstAyah).clamp(0, widget.lastAyah - widget.firstAyah);

  /// 30% dari atas; pada teks besar daftarnya pendek, jadi ayat aktif
  /// diletakkan paling atas supaya sebanyak mungkin terlihat.
  double _alignment(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(10) >= 16
      ? 0
      : AyahFollowList.alignment;

  @override
  void didUpdateWidget(AyahFollowList old) {
    super.didUpdateWidget(old);
    final active = widget.activeAyah;
    if (active != null && active != old.activeAyah && _following) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  @override
  void dispose() {
    _resume?.cancel();
    super.dispose();
  }

  void _scrollToActive() {
    final active = widget.activeAyah;
    if (!mounted || active == null || !_scroll.isAttached) return;
    final index = _indexOf(active);
    // Ke ayat yang belum ter-layout, scrollTo() paket ini memudarkan dua
    // daftar (FadeTransition) — efek di atas teks ayat. Jadi lompat saja;
    // animasi hanya untuk ayat yang sudah ada di layar/cache.
    final near = _positions.itemPositions.value.any((p) => p.index == index);
    if (!near || MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(index: index, alignment: _alignment(context));
      return;
    }
    unawaited(
      _scroll.scrollTo(
        index: index,
        alignment: _alignment(context),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  /// Pengguna menggulir sendiri: berhenti mengikuti selama 6 detik.
  void _pause() {
    _resume?.cancel();
    _resume = Timer(AyahFollowList.followPause, () {
      if (mounted) setState(() => _following = true);
    });
    if (_following) setState(() => _following = false);
  }

  void _comeBack() {
    _resume?.cancel();
    setState(() => _following = true);
    _scrollToActive();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final active = widget.activeAyah;
    final count = widget.lastAyah - widget.firstAyah + 1;
    return Stack(
      children: [
        NotificationListener<ScrollStartNotification>(
          onNotification: (notification) {
            // Hanya seretan jari; gulir otomatis tidak punya dragDetails.
            if (notification.dragDetails != null) _pause();
            return false;
          },
          child: ScrollablePositionedList.builder(
            itemScrollController: _scroll,
            itemPositionsListener: _positions,
            itemCount: count,
            initialScrollIndex: active == null ? 0 : _indexOf(active),
            initialAlignment: active == null ? 0 : _alignment(context),
            padding: EdgeInsets.fromLTRB(20, 8, 20, widget.bottomPadding),
            itemBuilder: (context, index) {
              final ayah = widget.firstAyah + index;
              final onTap = widget.onTapAyah;
              final onLongPress = widget.onLongPressAyah;
              return AyahFollowItem(
                key: ValueKey(ayah),
                ayah: ayah,
                arabic: widget.verses.arabicOf(ayah),
                translation: widget.showTranslation
                    ? widget.verses.translationOf(ayah)
                    : null,
                active: ayah == active,
                onTap: onTap == null ? null : () => onTap(ayah),
                onLongPress: onLongPress == null
                    ? null
                    : () => onLongPress(ayah),
              );
            },
          ),
        ),
        if (!_following && active != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.bottomPadding + 12,
            child: Center(
              child: _BackPill(tokens: tokens, onTap: _comeBack),
            ),
          ),
      ],
    );
  }
}

/// Satu ayat: nomor, teks Arab, terjemahan. Ayat aktif berupa kartu `surf`
/// dengan label "DIPUTAR"; ayat lain tanpa latar (tidak diredupkan).
class AyahFollowItem extends StatelessWidget {
  const AyahFollowItem({
    super.key,
    required this.ayah,
    required this.arabic,
    required this.translation,
    required this.active,
    this.onTap,
    this.onLongPress,
  });

  final int ayah;
  final String arabic;
  final String? translation;
  final bool active;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final ink = active ? tokens.ink : tokens.sec;
    final text = translation;
    return Semantics(
      button: onTap != null,
      onTapHint: 'Putar dari ayat ini',
      onLongPressHint: 'Bookmark atau buka di pembaca',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: active ? tokens.surf : tokens.surf.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: active
                  ? tokens.primarySoft
                  : tokens.primarySoft.withValues(alpha: 0),
              width: 1.5,
            ),
            boxShadow: active ? tokens.cardShadows : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (active) ...[
                    LineIcon(
                      SacredIcons.equalizer,
                      color: tokens.primaryText,
                      size: 13,
                      strokeWidth: 2.6,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DIPUTAR',
                      style: SacredText.playingTag.copyWith(
                        color: tokens.primaryText,
                      ),
                    ),
                  ],
                  const Spacer(),
                  _AyahNumber(ayah: ayah, active: active),
                ],
              ),
              const SizedBox(height: 4),
              // Teks Arab: tanpa tinggi tetap, tanpa efek, tidak di-clip.
              Text(
                arabic,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontFamily: SacredText.quran,
                  fontSize: active ? 29 : 25,
                  height: 2.15,
                  color: ink,
                ),
              ),
              if (text != null) ...[
                const SizedBox(height: 4),
                Text(
                  text,
                  style:
                      (active
                              ? SacredText.ayahTranslationActive
                              : SacredText.ayahTranslation)
                          .copyWith(color: ink),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Nomor ayat dalam lingkaran 26. Garis `tertiary` hanya untuk bentuk,
/// angkanya tetap `sec` (kontras `tertiary` terlalu rendah untuk teks).
class _AyahNumber extends StatelessWidget {
  const _AyahNumber({required this.ayah, required this.active});

  final int ayah;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: ayah < 100 ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: ayah < 100 ? null : BorderRadius.circular(13),
        color: active ? tokens.goldSoft : null,
        border: Border.all(
          color: active ? tokens.gold : tokens.tertiary,
          width: 1.6,
        ),
      ),
      child: Text(
        '$ayah',
        style: SacredText.ayahNumber.copyWith(
          color: active ? tokens.goldText : tokens.sec,
        ),
      ),
    );
  }
}

class _BackPill extends StatelessWidget {
  const _BackPill({required this.tokens, required this.onTap});

  final SacredTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.cta,
          borderRadius: BorderRadius.circular(999),
          boxShadow: tokens.floatShadows,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LineIcon(
              SacredIcons.equalizer,
              color: tokens.ctaInk,
              size: 14,
              strokeWidth: 2.6,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Kembali ke ayat yang diputar',
                textAlign: TextAlign.center,
                style: SacredText.actionPill.copyWith(color: tokens.ctaInk),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
