import 'package:flutter/material.dart';

/// Warna ornamen halaman mushaf (V2-Mushaf.html dan V2-Mushaf-Gelap.html).
/// Seperti palet tajwid, ornamen mushaf punya file token sendiri
/// (CLAUDE.md). Kertas malam memakai palet malam, bukan kertas terang yang
/// dipaksakan.
@immutable
class MushafTokens {
  const MushafTokens({
    required this.backdrop,
    required this.paper,
    required this.frame,
    required this.gold,
    required this.ink,
    required this.headerFill,
    required this.headerInk,
    required this.numeral,
    required this.tab,
    required this.tabInk,
  });

  /// Latar di luar halaman.
  final Color backdrop;
  final Color paper;

  /// Bingkai tebal 3.
  final Color frame;

  /// Garis emas 1, rosette, dan pita surah.
  final Color gold;
  final Color ink;
  final Color headerFill;
  final Color headerInk;

  /// Angka Arab-Indik di rosette ayat.
  final Color numeral;
  final Color tab;
  final Color tabInk;

  static const light = MushafTokens(
    backdrop: Color(0xFFF3EEDF),
    paper: Color(0xFFFBF6E8),
    frame: Color(0xFF064E3B),
    gold: Color(0xFFB8912E),
    ink: Color(0xFF1B1C1C),
    headerFill: Color(0xFFEAF1EC),
    headerInk: Color(0xFF003527),
    numeral: Color(0xFF6E520E),
    tab: Color(0xFF064E3B),
    tabInk: Color(0xFFFED65B),
  );

  static const dark = MushafTokens(
    backdrop: Color(0xFF08110E),
    paper: Color(0xFF0F1714),
    frame: Color(0xFF0B3D2F),
    gold: Color(0xFFC9A13B),
    ink: Color(0xFFE9ECE6),
    headerFill: Color(0xFF16261F),
    headerInk: Color(0xFFF4D679),
    numeral: Color(0xFFE9C766),
    tab: Color(0xFF0B3D2F),
    tabInk: Color(0xFFFED65B),
  );

  static MushafTokens of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
