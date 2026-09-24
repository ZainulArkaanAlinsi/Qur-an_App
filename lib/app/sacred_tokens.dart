import 'package:flutter/material.dart';

/// Token desain "Sacred Serenity · edisi iOS"
/// (quran-ios-redesign-handoff/docs/design/ios-redesign/DESIGN_SPEC.md §2–§3).
///
/// Semua layar mengambil warna dan gaya teks dari sini, bukan angka lepas,
/// supaya satu perubahan token berlaku di seluruh aplikasi.
@immutable
class SacredTokens extends ThemeExtension<SacredTokens> {
  const SacredTokens({
    required this.bg,
    required this.surf,
    required this.surf2,
    required this.ink,
    required this.sec,
    required this.sep,
    required this.fill,
    required this.primary,
    required this.primaryText,
    required this.primarySoft,
    required this.gold,
    required this.goldText,
    required this.goldSoft,
    required this.cta,
    required this.ctaInk,
    required this.toggleOn,
    required this.art,
    required this.artInk,
    required this.glass,
    required this.glassBorder,
    required this.heatmap,
    required this.ring,
    required this.tertiary,
    required this.onGold,
    required this.shadow,
    required this.floatShadow,
    required this.floatShadowSoft,
    required this.segment,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
  });

  final Color bg;
  final Color surf;
  final Color surf2;
  final Color ink;
  final Color sec;
  final Color sep;
  final Color fill;
  final Color primary;
  final Color primaryText;
  final Color primarySoft;
  final Color gold;

  /// Emas untuk teks di latar terang; emas ornamen terlalu tipis kontrasnya.
  final Color goldText;
  final Color goldSoft;
  final Color cta;
  final Color ctaInk;
  final Color toggleOn;

  /// Latar kartu hero/sampul.
  final Color art;
  final Color artInk;
  final Color glass;
  final Color glassBorder;

  /// Empat tingkat heatmap istiqamah, dari kosong ke penuh.
  final List<Color> heatmap;

  /// Garis 0.5 px di tepi kartu (v2: `0 0 0 .5px`).
  final Color ring;

  /// Abu ketiga untuk chevron dan ikon pasif.
  final Color tertiary;

  /// Tinta di atas tombol emas pada kartu hero; sama di kedua tema.
  final Color onGold;

  /// Bayangan kartu (`0 1px 2px`); transparan di tema gelap.
  final Color shadow;

  /// Dua lapis bayangan untuk elemen mengambang seperti tab bar.
  final Color floatShadow;
  final Color floatShadowSoft;

  /// Segmen aktif pada segmented control (putih di terang, #2C3A35 di gelap).
  final Color segment;

  /// Jawaban benar (cincin + teks) dan latar lembutnya; juga "Lancar".
  final Color success;
  final Color successSoft;

  /// Jawaban salah dan latar lembutnya; juga tombol "Salah" di sesi hafalan.
  final Color danger;
  final Color dangerSoft;

  /// Bayangan kartu v2: bayangan tipis + cincin 0.5 px.
  List<BoxShadow> get cardShadows => [
    BoxShadow(color: shadow, blurRadius: 2, offset: const Offset(0, 1)),
    BoxShadow(color: ring, spreadRadius: .5),
  ];

  /// Bayangan tab bar dan panel mengambang.
  List<BoxShadow> get floatShadows => [
    BoxShadow(color: floatShadow, blurRadius: 32, offset: const Offset(0, 12)),
    BoxShadow(
      color: floatShadowSoft,
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];

  static const light = SacredTokens(
    bg: Color(0xFFF4F1EA),
    surf: Color(0xFFFCF9F8),
    surf2: Color(0xFFEAE6DC),
    ink: Color(0xFF1B1C1C),
    sec: Color(0xFF5F625D),
    sep: Color(0x171B1C1C),
    fill: Color(0x173C463E),
    primary: Color(0xFF003527),
    primaryText: Color(0xFF00513B),
    primarySoft: Color(0xFFE0ECE5),
    gold: Color(0xFFC9A13B),
    goldText: Color(0xFF7A5A0E),
    goldSoft: Color(0xFFFBF0CC),
    cta: Color(0xFF003527),
    ctaInk: Color(0xFFFFFFFF),
    toggleOn: Color(0xFF0E6A4C),
    art: Color(0xFF064E3B),
    artInk: Color(0xFFFED65B),
    glass: Color(0xC2FCF9F8),
    glassBorder: Color(0xD9FFFFFF),
    heatmap: [
      Color(0xFFE6E2D8),
      Color(0xFFF6E3A2),
      Color(0xFFE7BE45),
      Color(0xFFA57E14),
    ],
    ring: Color(0x0F00281C),
    tertiary: Color(0xFF9A9D97),
    onGold: Color(0xFF1F1A05),
    shadow: Color(0x0F00281C),
    floatShadow: Color(0x2100281C),
    floatShadowSoft: Color(0x1400281C),
    segment: Color(0xFFFFFFFF),
    success: Color(0xFF1B7D3A),
    successSoft: Color(0xFFE3F2E8),
    danger: Color(0xFF9B1C1C),
    dangerSoft: Color(0xFFFBE3E3),
  );

  static const dark = SacredTokens(
    bg: Color(0xFF08110E),
    surf: Color(0xFF111C18),
    surf2: Color(0xFF1A2823),
    ink: Color(0xFFECEFEA),
    sec: Color(0xFF9DA79F),
    sep: Color(0x14FFFFFF),
    fill: Color(0x14FFFFFF),
    primary: Color(0xFF8FD7B8),
    primaryText: Color(0xFF9ADDBF),
    primarySoft: Color(0x218FD7B8),
    gold: Color(0xFFFED65B),
    goldText: Color(0xFFF4D679),
    goldSoft: Color(0x1FFED65B),
    cta: Color(0xFFFED65B),
    ctaInk: Color(0xFF1F1A05),
    toggleOn: Color(0xFF2F9E75),
    art: Color(0xFF0B3D2F),
    artInk: Color(0xFFFED65B),
    glass: Color(0xC214201C),
    glassBorder: Color(0x17FFFFFF),
    heatmap: [
      Color(0xFF1A2823),
      Color(0xFF3D3715),
      Color(0xFF8A7424),
      Color(0xFFFED65B),
    ],
    ring: Color(0x0FFFFFFF),
    tertiary: Color(0xFF646D67),
    onGold: Color(0xFF1F1A05),
    shadow: Color(0x00000000),
    floatShadow: Color(0x8C000000),
    floatShadowSoft: Color(0x66000000),
    segment: Color(0xFF2C3A35),
    success: Color(0xFF6FD890),
    successSoft: Color(0x1F6FD890),
    danger: Color(0xFFFF9B9B),
    dangerSoft: Color(0x1FFF7B7B),
  );

  /// Sepia memakai kaca dan aksen tema terang, sesuai spesifikasi.
  static const sepia = SacredTokens(
    bg: Color(0xFFF4ECD8),
    surf: Color(0xFFFBF4E4),
    surf2: Color(0xFFE9DCBE),
    ink: Color(0xFF3E3222),
    sec: Color(0xFF6E5D44),
    sep: Color(0x1F3E3222),
    fill: Color(0x1F6E5A3C),
    primary: Color(0xFF003527),
    primaryText: Color(0xFF00513B),
    primarySoft: Color(0xFFE0ECE5),
    gold: Color(0xFFC9A13B),
    goldText: Color(0xFF7A5A0E),
    goldSoft: Color(0xFFFBF0CC),
    cta: Color(0xFF003527),
    ctaInk: Color(0xFFFFFFFF),
    toggleOn: Color(0xFF0E6A4C),
    art: Color(0xFF064E3B),
    artInk: Color(0xFFFED65B),
    glass: Color(0xC2FBF4E4),
    glassBorder: Color(0xD9FFFFFF),
    heatmap: [
      Color(0xFFE6E2D8),
      Color(0xFFF6E3A2),
      Color(0xFFE7BE45),
      Color(0xFFA57E14),
    ],
    ring: Color(0x143E3222),
    tertiary: Color(0xFF9A8E78),
    onGold: Color(0xFF1F1A05),
    shadow: Color(0x0F3E3222),
    floatShadow: Color(0x213E3222),
    floatShadowSoft: Color(0x143E3222),
    segment: Color(0xFFFFFFFF),
    success: Color(0xFF1B7D3A),
    successSoft: Color(0xFFE3F2E8),
    danger: Color(0xFF9B1C1C),
    dangerSoft: Color(0xFFFBE3E3),
  );

  /// Kontras tinggi: hitam/putih penuh, aksen tetap dapat dibedakan.
  static const highContrastLight = SacredTokens(
    bg: Color(0xFFFFFFFF),
    surf: Color(0xFFFFFFFF),
    surf2: Color(0xFFE0E0E0),
    ink: Color(0xFF000000),
    sec: Color(0xFF2B2B2B),
    sep: Color(0x663A3A3A),
    fill: Color(0x1F000000),
    primary: Color(0xFF00301F),
    primaryText: Color(0xFF00301F),
    primarySoft: Color(0xFFD7E7DF),
    gold: Color(0xFF7A5A0E),
    goldText: Color(0xFF5A420A),
    goldSoft: Color(0xFFF3E6BF),
    cta: Color(0xFF000000),
    ctaInk: Color(0xFFFFFFFF),
    toggleOn: Color(0xFF00301F),
    art: Color(0xFF00301F),
    artInk: Color(0xFFFFE27A),
    glass: Color(0xF2FFFFFF),
    glassBorder: Color(0xFF3A3A3A),
    heatmap: [
      Color(0xFFE0E0E0),
      Color(0xFFBDA45A),
      Color(0xFF8A6B12),
      Color(0xFF3F3005),
    ],
    ring: Color(0x663A3A3A),
    tertiary: Color(0xFF2B2B2B),
    onGold: Color(0xFF000000),
    shadow: Color(0x00000000),
    floatShadow: Color(0x33000000),
    floatShadowSoft: Color(0x1F000000),
    segment: Color(0xFFFFFFFF),
    success: Color(0xFF0B5A26),
    successSoft: Color(0xFFD9EFE0),
    danger: Color(0xFF7A0F0F),
    dangerSoft: Color(0xFFF7D6D6),
  );

  static const highContrastDark = SacredTokens(
    bg: Color(0xFF000000),
    surf: Color(0xFF0A0A0A),
    surf2: Color(0xFF1F1F1F),
    ink: Color(0xFFFFFFFF),
    sec: Color(0xFFD7D7D7),
    sep: Color(0x669A9A9A),
    fill: Color(0x33FFFFFF),
    primary: Color(0xFFA9E8C9),
    primaryText: Color(0xFFBDEFD8),
    primarySoft: Color(0x3DA9E8C9),
    gold: Color(0xFFFFE27A),
    goldText: Color(0xFFFFE27A),
    goldSoft: Color(0x33FFE27A),
    cta: Color(0xFFFFE27A),
    ctaInk: Color(0xFF000000),
    toggleOn: Color(0xFFA9E8C9),
    art: Color(0xFF0A0A0A),
    artInk: Color(0xFFFFE27A),
    glass: Color(0xF20A0A0A),
    glassBorder: Color(0xFF9A9A9A),
    heatmap: [
      Color(0xFF1F1F1F),
      Color(0xFF6B5A16),
      Color(0xFFB79B2C),
      Color(0xFFFFE27A),
    ],
    ring: Color(0x669A9A9A),
    tertiary: Color(0xFFD7D7D7),
    onGold: Color(0xFF000000),
    shadow: Color(0x00000000),
    floatShadow: Color(0x8C000000),
    floatShadowSoft: Color(0x66000000),
    segment: Color(0xFF2B2B2B),
    success: Color(0xFF8FF0AE),
    successSoft: Color(0x338FF0AE),
    danger: Color(0xFFFFB3B3),
    dangerSoft: Color(0x33FFB3B3),
  );

  @override
  SacredTokens copyWith({
    Color? bg,
    Color? surf,
    Color? surf2,
    Color? ink,
    Color? sec,
    Color? sep,
    Color? fill,
    Color? primary,
    Color? primaryText,
    Color? primarySoft,
    Color? gold,
    Color? goldText,
    Color? goldSoft,
    Color? cta,
    Color? ctaInk,
    Color? toggleOn,
    Color? art,
    Color? artInk,
    Color? glass,
    Color? glassBorder,
    List<Color>? heatmap,
    Color? ring,
    Color? tertiary,
    Color? onGold,
    Color? shadow,
    Color? floatShadow,
    Color? floatShadowSoft,
    Color? segment,
    Color? success,
    Color? successSoft,
    Color? danger,
    Color? dangerSoft,
  }) => SacredTokens(
    bg: bg ?? this.bg,
    surf: surf ?? this.surf,
    surf2: surf2 ?? this.surf2,
    ink: ink ?? this.ink,
    sec: sec ?? this.sec,
    sep: sep ?? this.sep,
    fill: fill ?? this.fill,
    primary: primary ?? this.primary,
    primaryText: primaryText ?? this.primaryText,
    primarySoft: primarySoft ?? this.primarySoft,
    gold: gold ?? this.gold,
    goldText: goldText ?? this.goldText,
    goldSoft: goldSoft ?? this.goldSoft,
    cta: cta ?? this.cta,
    ctaInk: ctaInk ?? this.ctaInk,
    toggleOn: toggleOn ?? this.toggleOn,
    art: art ?? this.art,
    artInk: artInk ?? this.artInk,
    glass: glass ?? this.glass,
    glassBorder: glassBorder ?? this.glassBorder,
    heatmap: heatmap ?? this.heatmap,
    ring: ring ?? this.ring,
    tertiary: tertiary ?? this.tertiary,
    onGold: onGold ?? this.onGold,
    shadow: shadow ?? this.shadow,
    floatShadow: floatShadow ?? this.floatShadow,
    floatShadowSoft: floatShadowSoft ?? this.floatShadowSoft,
    segment: segment ?? this.segment,
    success: success ?? this.success,
    successSoft: successSoft ?? this.successSoft,
    danger: danger ?? this.danger,
    dangerSoft: dangerSoft ?? this.dangerSoft,
  );

  @override
  SacredTokens lerp(ThemeExtension<SacredTokens>? other, double t) {
    if (other is! SacredTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return SacredTokens(
      bg: mix(bg, other.bg),
      surf: mix(surf, other.surf),
      surf2: mix(surf2, other.surf2),
      ink: mix(ink, other.ink),
      sec: mix(sec, other.sec),
      sep: mix(sep, other.sep),
      fill: mix(fill, other.fill),
      primary: mix(primary, other.primary),
      primaryText: mix(primaryText, other.primaryText),
      primarySoft: mix(primarySoft, other.primarySoft),
      gold: mix(gold, other.gold),
      goldText: mix(goldText, other.goldText),
      goldSoft: mix(goldSoft, other.goldSoft),
      cta: mix(cta, other.cta),
      ctaInk: mix(ctaInk, other.ctaInk),
      toggleOn: mix(toggleOn, other.toggleOn),
      art: mix(art, other.art),
      artInk: mix(artInk, other.artInk),
      glass: mix(glass, other.glass),
      glassBorder: mix(glassBorder, other.glassBorder),
      heatmap: [
        for (var i = 0; i < heatmap.length; i++)
          mix(heatmap[i], other.heatmap[i]),
      ],
      ring: mix(ring, other.ring),
      tertiary: mix(tertiary, other.tertiary),
      onGold: mix(onGold, other.onGold),
      shadow: mix(shadow, other.shadow),
      floatShadow: mix(floatShadow, other.floatShadow),
      floatShadowSoft: mix(floatShadowSoft, other.floatShadowSoft),
      segment: mix(segment, other.segment),
      success: mix(success, other.success),
      successSoft: mix(successSoft, other.successSoft),
      danger: mix(danger, other.danger),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
    );
  }
}

/// Gradien langit mengikuti periode waktu salat (DESIGN_SPEC §2).
enum SkyPeriod {
  fajr([Color(0xFF1B2B4A), Color(0xFF5E6488), Color(0xFFE7A98A)]),
  day([Color(0xFF1D6A86), Color(0xFF62A9C0), Color(0xFFCFE8EC)]),
  dusk([
    Color(0xFF0B3F48),
    Color(0xFF2E7078),
    Color(0xFFB7A383),
    Color(0xFFF2C98A),
  ]),
  night([Color(0xFF030B0A), Color(0xFF0A2624), Color(0xFF163A37)]);

  const SkyPeriod(this.colors);

  final List<Color> colors;

  /// Periode dari jam setempat; dipakai bila jadwal salat belum dimuat.
  /// Subuh hanya sampai jam 7; jam 9 pagi sudah langit siang, bukan fajar.
  static SkyPeriod fromHour(int hour) => switch (hour) {
    >= 4 && < 7 => SkyPeriod.fajr,
    >= 7 && < 15 => SkyPeriod.day,
    >= 15 && < 18 => SkyPeriod.dusk,
    _ => SkyPeriod.night,
  };

  /// Gradien empat warna memakai titik henti mockup (0, 44%, 76%, 100%).
  LinearGradient get gradient => gradientFor(Brightness.light);

  /// Di tema gelap langitnya diredupkan 45% supaya tidak menyilaukan
  /// (V2-Beranda-Gelap: #06161A → #8C6A43).
  LinearGradient gradientFor(Brightness brightness) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: brightness == Brightness.dark
        ? [
            for (final color in colors)
              Color.lerp(color, const Color(0xFF000000), .45)!,
          ]
        : colors,
    stops: colors.length == 4 ? const [0, .44, .76, 1] : null,
  );
}

/// Gaya teks DESIGN_SPEC §3. Ketebalan diatur lewat [FontVariation] karena
/// font UI yang dibundel adalah font variabel.
abstract final class SacredText {
  static const ui = 'PlusJakartaSans';
  static const serif = 'EBGaramond';
  static const quran = 'AmiriQuran';

  static FontWeight _weightOf(double value) =>
      FontWeight.values[((value / 100).round() - 1).clamp(0, 8)];

  static TextStyle _font(
    String family,
    double size,
    double height,
    double weight,
  ) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: height / size,
    fontWeight: _weightOf(weight),
    fontVariations: [FontVariation('wght', weight)],
  );

  static TextStyle get largeTitle => _font(serif, 42, 46, 500);
  static TextStyle get greeting => _font(serif, 40, 44, 500);
  static TextStyle get cardTitle => _font(serif, 28, 34, 500);
  static TextStyle get headline => _font(ui, 17, 22, 700);
  static TextStyle get body => _font(ui, 15, 23, 500);
  static TextStyle get footnote => _font(ui, 13, 18, 500);
  static TextStyle get tabLabel => _font(ui, 10.5, 14, 600);

  /// Label kecil huruf kapital dengan jarak huruf lebar.
  static TextStyle get eyebrow =>
      _font(ui, 11, 14, 800).copyWith(letterSpacing: 11 * .12);

  // Gaya di bawah ini diambil langsung dari mockup di folder handoff
  // (`docs/design/ios-redesign/html/`). Setiap ukuran punya nama supaya tidak
  // ada lagi angka lepas yang ditulis berbeda-beda di tiap layar.

  /// Beranda: baris tanggal Masehi dan baris Hijriah di bawahnya.
  static TextStyle get dateLine => _font(ui, 13, 17, 700);
  static TextStyle get dateSub => _font(ui, 13, 17, 500);

  /// "Assalamu'alaikum," di atas nama.
  static TextStyle get greetingSmall => _font(ui, 15, 20, 600);

  /// Inisial pada lingkaran profil.
  static TextStyle get avatar => _font(serif, 21, 24, 500);

  /// Judul surah pada kartu hero.
  static TextStyle get heroTitle => _font(serif, 32, 36, 500);
  static TextStyle get heroCta => _font(ui, 15, 20, 800);
  static TextStyle get heroAction => _font(ui, 15, 20, 700);

  /// Angka persen di samping bar kemajuan.
  static TextStyle get percent => _font(ui, 12, 16, 800);

  /// Judul kecil di dalam kartu, dan keterangan di bawahnya.
  static TextStyle get cardLabel => _font(ui, 13, 17, 700);
  static TextStyle get cardNote => _font(ui, 12, 16, 600);

  /// Angka besar pada kartu target dan istiqamah, beserta satuannya.
  static TextStyle get metric => _font(ui, 22, 26, 800);
  static TextStyle get metricUnit => _font(ui, 14, 18, 600);

  /// Persen kecil di tengah cincin target.
  static TextStyle get ringLabel => _font(ui, 12, 14, 800);

  /// Chip kecil seperti "MENUNGGU".
  static TextStyle get chip => _font(ui, 10.5, 13, 800);

  /// Label pada pintasan Surah/Bookmark/Khatam.
  static TextStyle get chipLabel => _font(ui, 14, 18, 700);

  /// Huruf hari di bawah titik istiqamah.
  static TextStyle get dayLetter => _font(ui, 10, 13, 700);

  /// Strip salat: nama dan jam, lalu pil hitung mundur.
  static TextStyle get stripTitle => _font(ui, 15, 20, 800);
  static TextStyle get stripPill => _font(
    ui,
    12.5,
    16,
    800,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Terjemahan pada kartu ayat hari ini.
  static TextStyle get verseTranslation =>
      _font(serif, 19, 25, 400).copyWith(fontStyle: FontStyle.italic);

  /// Judul besar layar Qur'an, Progres, Pengaturan, dan Salat.
  static TextStyle get screenTitle =>
      _font(serif, 42, 46, 400).copyWith(letterSpacing: 42 * -.01);
  static TextStyle get screenSubtitle => _font(ui, 14, 19, 500);

  /// Kolom pencarian dan segmented control.
  static TextStyle get searchInput => _font(ui, 16, 21, 500);
  static TextStyle get segmentActive => _font(ui, 14, 18, 700);
  static TextStyle get segmentIdle => _font(ui, 14, 18, 600);

  /// Tautan teks seperti "Lihat semua" dan "Ganti kota".
  static TextStyle get linkLabel => _font(ui, 13, 17, 700);

  /// Baris daftar surah.
  static TextStyle get listName => _font(ui, 16, 21, 700);
  static TextStyle get listMeta => _font(ui, 12.5, 17, 500);

  /// Nomor di dalam rosette daftar.
  static TextStyle get rosetteNumber => _font(
    ui,
    12.5,
    14,
    800,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Kartu "terakhir dibaca" pada layar Qur'an.
  static TextStyle get recentName => _font(ui, 15, 20, 800);
  static TextStyle get recentMeta => _font(ui, 12, 16, 500);

  /// Baris pengaturan bergaya iOS.
  static TextStyle get settingTitle => _font(ui, 16, 21, 600);
  static TextStyle get settingValue => _font(ui, 15, 20, 500);

  /// Legenda heatmap.
  static TextStyle get legend => _font(ui, 11, 15, 600);

  /// Angka besar pada kartu Istiqamah di layar Progres.
  static TextStyle get statNumber => _font(ui, 30, 34, 800);
  static TextStyle get statUnit => _font(ui, 15, 20, 600);
  static TextStyle get statSide => _font(ui, 15, 20, 800);

  /// Judul kartu khatam dan nomor di dalam gridnya.
  static TextStyle get khatamTitle => _font(ui, 17, 22, 800);
  static TextStyle get khatamCell => _font(ui, 11.5, 14, 800);

  /// Navigasi pembaca.
  static TextStyle get backLabel => _font(ui, 17, 22, 600);
  static TextStyle get navTitle => _font(ui, 16, 21, 800);
  static TextStyle get navSubtitle => _font(ui, 12, 16, 600);

  /// Keterangan kecil pada plakat nama surah.
  static TextStyle get plateMeta => _font(ui, 12, 16, 700);

  /// Label nomor ayat "1:1" di kepala kartu ayat.
  static TextStyle get verseLabel =>
      _font(ui, 12, 16, 800).copyWith(letterSpacing: 12 * .04);

  /// Hitung mundur pada kartu salat berikutnya (Salat.html: 40/42, regular).
  static TextStyle get countdown => _font(serif, 40, 42, 400);

  /// Nama dan jam pada daftar salat.
  static TextStyle get prayerName => _font(ui, 16, 21, 600);

  /// Nama salat yang sedang disorot ditebalkan, bukan sekadar diberi warna.
  static TextStyle get prayerNameNext => _font(ui, 16, 21, 800);
  static TextStyle get prayerTime => _font(
    ui,
    17,
    22,
    800,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  // Gaya v2 (docs/design/v2/DESIGN.md §3).

  /// Baris list: judul 16/700 dan subjudul 13/500.
  static TextStyle get rowTitle => _font(ui, 16, 21, 700);
  static TextStyle get rowSubtitle => _font(ui, 13, 17, 500);

  /// Pill status 12/800, satu baris.
  static TextStyle get pill => _font(ui, 12, 16, 800);

  /// Label tab bar v2: 11, tebal 800 bila aktif dan 600 bila tidak.
  static TextStyle get tabActive => _font(ui, 11, 14, 800);
  static TextStyle get tabIdle => _font(ui, 11, 14, 600);

  /// Label tombol utama dan tombol lunak.
  static TextStyle get button => _font(ui, 15, 20, 800);
  static TextStyle get buttonSmall => _font(ui, 14, 18, 800);

  /// Beranda v2: nama pengguna 38/44 dan judul surah kartu hero 30/34.
  static TextStyle get homeName => _font(serif, 38, 44, 500);
  static TextStyle get heroTitleV2 => _font(serif, 30, 34, 500);

  /// Belajar v2: kotak info 13/18, angka node 15/800, kartu tahap aktif
  /// (judul 17/800, ringkasan 13/19).
  static TextStyle get infoBox => _font(ui, 13, 18, 600);
  static TextStyle get nodeNumber => _font(ui, 15, 18, 800);
  static TextStyle get stageTitle => _font(ui, 17, 22, 800);
  static TextStyle get stageSummary => _font(ui, 13, 19, 500);

  /// Pelajaran v2: penghitung "3/5", paragraf 15/22, kartu huruf, soal,
  /// pilihan, umpan balik.
  static TextStyle get stepCounter => _font(ui, 13, 17, 800);
  static TextStyle get lessonBody => _font(ui, 15, 22, 500);
  static TextStyle get letterName => _font(ui, 15, 19, 800);
  static TextStyle get letterNote => _font(ui, 11.5, 15, 600);
  static TextStyle get question => _font(ui, 17, 22, 800);
  static TextStyle get option => _font(ui, 15, 20, 700);
  static TextStyle get feedback => _font(ui, 13.5, 19, 700);
  static TextStyle get dashedNote => _font(ui, 13.5, 18, 700);

  /// Judul serif layar turunan (Pelajaran: 32/36).
  static TextStyle get lessonTitle => _font(serif, 32, 36, 500);
}

/// Warna lencana ikon kotak (baris Saya, Mode baca, Salat, Sesi hafalan).
///
/// Mockup memakai nilai yang sama di tema terang dan gelap: lencananya selalu
/// pekat dan glifnya putih, jadi kontrasnya tidak bergantung pada tema.
abstract final class SacredBadge {
  static const green = Color(0xFF0E6A4C);
  static const gold = Color(0xFF9A7415);
  static const blue = Color(0xFF2C6E8F);
  static const grey = Color(0xFF56635C);
  static const red = Color(0xFFB0533A);

  /// Glif di atas lencana.
  static const glyph = Color(0xFFFFFFFF);
}

/// Warna di atas kartu hero hijau dan strip langit. Latarnya selalu gelap di
/// kedua tema, jadi nilainya tetap (Beranda v2, Hafalan v2).
abstract final class SacredArt {
  /// Judul putih dan keterangan 82%.
  static const ink = Color(0xFFFFFFFF);
  static const inkSoft = Color(0xD1FFFFFF);

  /// Isi sampul mihrab kecil (hitam 22%).
  static const plate = Color(0x38000000);

  /// Tombol ikon kaca di atas kartu hero: isi 12%, garis 22%.
  static const glass = Color(0x1FFFFFFF);
  static const glassBorder = Color(0x38FFFFFF);

  /// Strip salat: lingkaran ikon 16%, ikon matahari, pill hitung mundur 28%,
  /// bayangan teks 30%.
  static const skyIconBg = Color(0x29FFFFFF);
  static const skyIcon = Color(0xFFFFF1C9);
  static const skyPill = Color(0x47000000);
  static const skyTextShadow = Color(0x4D000000);
}
