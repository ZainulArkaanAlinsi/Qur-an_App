// Generator gambar Play Store: 7 screenshot (1080×1920) dan feature graphic
// (1024×500) untuk tiap bahasa listing. Bukan tes aplikasi; jalankan manual:
//
//   flutter test --dart-define=STORE_SHOTS=true test/golden/screen_19_beranda_test.dart \
//     test/golden/screen_20_murottal_test.dart test/golden/screen_05_kartu_test.dart \
//     test/golden/screen_08_belajar_test.dart test/golden/screen_10_hafalan_test.dart \
//     test/golden/screen_14_salat_test.dart test/golden/screen_17_onboarding_test.dart
//   flutter test tool/store/store_assets_test.dart
//   python tool/store/to_jpeg.py
//
// Layar diambil dari build/store_shots/ (render asli dengan bayangan). Teks
// keterangan dirender Flutter supaya huruf Arab dan Urdu tersambung benar.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/features/onboarding/presentation/brand_art.dart';

import '../../test/golden/golden_harness.dart' show loadAppFonts, loadImages;

/// Layar yang dipakai, urut tampil di Play Store. `dark` = latar gelap.
/// v6 (1.11): Beranda & Murottal baru; kartu gelap diganti Murottal.
const _shots = [
  ('17_onboarding_1_light', false),
  ('05_kartu_light', false),
  ('19_beranda_baru_light', false),
  ('20_murottal_teks_light', false),
  ('08_belajar_light', false),
  ('10_hafalan_light', false),
  ('14_salat_light', false),
];

/// Keterangan v6 per bahasa: (Beranda, Murottal, Salat). Hanya fitur yang
/// ada di rilis 1.11; qari yang izinnya belum ada tidak disebut.
const _v6Copy =
    <String, ((String, String), (String, String), (String, String))>{
      'id': (
        (
          'Satu langkah untuk hari ini',
          'Salat berikutnya dan bacaan yang menunggu.',
        ),
        (
          'Dengar sambil mengikuti ayat',
          'Ayat yang dibaca qari tersorot dan ikut bergulir.',
        ),
        (
          'Waktu salat & arah kiblat',
          'Lokasi otomatis atau pilih kota, dengan pengingat.',
        ),
      ),
      'en': (
        ('One clear step for today', 'Your next prayer and what to read now.'),
        (
          'Listen and follow each verse',
          'The verse being recited is highlighted and scrolls along.',
        ),
        (
          'Prayer times & Qibla',
          'Automatic location or your city, with reminders.',
        ),
      ),
      'ar': (
        ('خطوة واحدة لليوم', 'الصلاة القادمة وما تقرؤه الآن.'),
        ('استمع وتابع كل آية', 'الآية التي يتلوها القارئ مميّزة وتتحرك معه.'),
        (
          'مواقيت الصلاة واتجاه القبلة',
          'موقع تلقائي أو اختر مدينتك، مع التنبيهات.',
        ),
      ),
      'ms': (
        (
          'Satu langkah untuk hari ini',
          'Solat seterusnya dan bacaan yang menanti.',
        ),
        (
          'Dengar sambil mengikuti ayat',
          'Ayat yang dibaca qari diserlahkan dan turut bergulir.',
        ),
        (
          'Waktu solat & arah kiblat',
          'Lokasi automatik atau pilih bandar, dengan peringatan.',
        ),
      ),
      'tr': (
        ('Bugün için tek bir adım', 'Sıradaki namaz ve şimdi okunacak bölüm.'),
        (
          'Dinlerken her ayeti takip et',
          'Okunan ayet vurgulanır ve kendiliğinden kayar.',
        ),
        (
          'Namaz vakitleri ve kıble',
          'Otomatik konum veya şehir seçimi, hatırlatıcılarla.',
        ),
      ),
      'ur': (
        ('آج کے لیے ایک قدم', 'اگلی نماز اور ابھی پڑھنے کا حصہ۔'),
        (
          'سنیں اور ہر آیت کے ساتھ چلیں',
          'قاری کی پڑھی جانے والی آیت نمایاں ہو کر ساتھ چلتی ہے۔',
        ),
        (
          'نماز کے اوقات اور قبلہ',
          'خودکار مقام یا اپنا شہر، یاد دہانی کے ساتھ۔',
        ),
      ),
      'fr': (
        (
          "Une étape claire pour aujourd'hui",
          'La prochaine prière et la lecture du moment.',
        ),
        (
          'Écoutez en suivant chaque verset',
          'Le verset récité est surligné et défile avec la voix.',
        ),
        (
          'Horaires de prière et qibla',
          'Position automatique ou ville au choix, avec rappels.',
        ),
      ),
    };

/// Keterangan 7 layar [_shots]: onboarding & kartu dari [_copy], lalu
/// Beranda & Murottal v6, Belajar & Hafalan dari [_copy], lalu Salat v6.
List<(String, String)> _captions(String lang) {
  final old = _copy[lang]!.$1;
  final (home, murottal, prayer) = _v6Copy[lang]!;
  return [old[0], old[1], home, murottal, old[3], old[4], prayer];
}

/// Keterangan per bahasa: [judul, anak judul] untuk tiap layar di [_shots],
/// lalu tagline dan kalimat feature graphic.
const _copy = <String, (List<(String, String)>, String, String)>{
  'id': (
    [
      (
        'Baca, belajar, hafal Al-Qur\'an',
        'Satu aplikasi yang tenang, tetap bisa tanpa internet.',
      ),
      ('Tajwid berwarna di setiap huruf', 'Kartu per ayat dengan terjemahan.'),
      (
        'Lanjutkan bacaan setiap hari',
        'Target harian, istiqamah, dan jadwal salat.',
      ),
      ('Belajar membaca dari nol', 'Jalur bertahap mulai dari huruf hijaiyah.'),
      (
        'Hafalan yang terjadwal',
        'Ziyadah, murajaah, dan tasmi\' di satu tempat.',
      ),
      ('Waktu salat & arah kiblat', 'Pengingat untuk kotamu.'),
      ('Nyaman dibaca malam hari', 'Mode gelap untuk tilawah malam.'),
    ],
    'Baca · Belajar · Hafal',
    'Al-Qur\'an dengan tajwid berwarna, jalur belajar, dan hafalan terjadwal.',
  ),
  'en': (
    [
      (
        'Read, learn & memorize the Qur\'an',
        'One calm app that also works offline.',
      ),
      (
        'Color-coded tajweed on every letter',
        'Verse-by-verse cards with translation.',
      ),
      ('Keep up your daily reading', 'Daily goal, streak and prayer times.'),
      (
        'Learn to read from zero',
        'A step-by-step path from the Arabic alphabet.',
      ),
      (
        'Memorization on a schedule',
        'New verses, review and self-test in one place.',
      ),
      ('Prayer times & Qibla', 'Reminders for your city.'),
      ('Easy on the eyes at night', 'Dark mode for night recitation.'),
    ],
    'Read · Learn · Memorize',
    'The Qur\'an with color-coded tajweed, a learning path and scheduled memorization.',
  ),
  'ar': (
    [
      (
        'اقرأ وتعلّم واحفظ القرآن',
        'تطبيق هادئ يعمل أيضًا دون اتصال بالإنترنت.',
      ),
      ('تجويد ملوّن على كل حرف', 'بطاقة لكل آية مع ترجمة المعاني.'),
      ('واظب على وردك اليومي', 'هدف يومي، ومواظبة، ومواقيت الصلاة.'),
      ('تعلّم القراءة من البداية', 'مسار متدرّج يبدأ بالحروف الهجائية.'),
      ('حفظ منظّم بجدول', 'حفظ جديد ومراجعة وتسميع في مكان واحد.'),
      ('مواقيت الصلاة واتجاه القبلة', 'تنبيهات لمدينتك.'),
      ('مريح للعين ليلًا', 'الوضع الداكن لتلاوة الليل.'),
    ],
    'اقرأ · تعلّم · احفظ',
    'القرآن مع تجويد ملوّن، ومسار تعليمي، وحفظ منظّم بجدول.',
  ),
  'ms': (
    [
      (
        'Baca, belajar & hafaz al-Quran',
        'Satu aplikasi yang tenang, boleh digunakan tanpa internet.',
      ),
      (
        'Tajwid berwarna pada setiap huruf',
        'Kad setiap ayat dengan terjemahan.',
      ),
      (
        'Teruskan bacaan setiap hari',
        'Sasaran harian, istiqamah dan waktu solat.',
      ),
      (
        'Belajar membaca dari asas',
        'Laluan berperingkat bermula dengan huruf hijaiyah.',
      ),
      (
        'Hafazan mengikut jadual',
        'Ziyadah, murajaah dan tasmi\' di satu tempat.',
      ),
      ('Waktu solat & arah kiblat', 'Peringatan untuk bandar anda.'),
      ('Selesa dibaca pada waktu malam', 'Mod gelap untuk tilawah malam.'),
    ],
    'Baca · Belajar · Hafaz',
    'Al-Quran dengan tajwid berwarna, laluan pembelajaran dan hafazan berjadual.',
  ),
  'tr': (
    [
      (
        'Kur\'an\'ı oku, öğren, ezberle',
        'İnternetsiz de çalışan sade bir uygulama.',
      ),
      ('Her harfte renkli tecvid', 'Meali ile ayet ayet kartlar.'),
      ('Günlük okumanı sürdür', 'Günlük hedef, seri ve namaz vakitleri.'),
      ('Sıfırdan okumayı öğren', 'Elifbadan başlayan adım adım bir yol.'),
      ('Planlı ezber', 'Yeni ezber, tekrar ve kendini sınama tek yerde.'),
      ('Namaz vakitleri ve kıble', 'Şehrin için hatırlatıcılar.'),
      ('Gece de göz yormaz', 'Gece okuması için karanlık mod.'),
    ],
    'Oku · Öğren · Ezberle',
    'Renkli tecvid, öğrenme yolu ve planlı ezberle Kur\'an.',
  ),
  'ur': (
    [
      (
        'قرآن پڑھیں، سیکھیں اور حفظ کریں',
        'ایک پُرسکون ایپ جو انٹرنیٹ کے بغیر بھی چلتی ہے۔',
      ),
      ('ہر حرف پر رنگین تجوید', 'ہر آیت کا کارڈ، ترجمے کے ساتھ۔'),
      ('روزانہ تلاوت جاری رکھیں', 'روزانہ ہدف، استقامت اور نماز کے اوقات۔'),
      ('شروع سے پڑھنا سیکھیں', 'حروفِ تہجی سے شروع ہونے والا مرحلہ وار راستہ۔'),
      ('منظم حفظ', 'نیا حفظ، دہرائی اور خود جانچ ایک جگہ۔'),
      ('نماز کے اوقات اور قبلہ', 'آپ کے شہر کے لیے یاد دہانیاں۔'),
      ('رات میں آنکھوں کے لیے آرام دہ', 'رات کی تلاوت کے لیے ڈارک موڈ۔'),
    ],
    'پڑھیں · سیکھیں · حفظ کریں',
    'رنگین تجوید، سیکھنے کا راستہ اور منظم حفظ کے ساتھ قرآن۔',
  ),
  'fr': (
    [
      (
        'Lire, apprendre et mémoriser le Coran',
        'Une application sereine, même hors ligne.',
      ),
      (
        'Le tajwid en couleur sur chaque lettre',
        'Une carte par verset, avec traduction.',
      ),
      (
        'Gardez votre lecture quotidienne',
        'Objectif du jour, régularité et horaires de prière.',
      ),
      (
        'Apprendre à lire depuis zéro',
        'Un parcours progressif dès l\'alphabet arabe.',
      ),
      (
        'Une mémorisation planifiée',
        'Nouveaux versets, révision et auto-évaluation.',
      ),
      ('Horaires de prière et qibla', 'Des rappels pour votre ville.'),
      ('Confortable la nuit', 'Mode sombre pour la récitation nocturne.'),
    ],
    'Lire · Apprendre · Mémoriser',
    'Le Coran avec tajwid en couleur, un parcours d\'apprentissage et une mémorisation planifiée.',
  ),
};

bool _rtl(String lang) => lang == 'ar' || lang == 'ur';

/// Bagian layar yang dipakai: tanpa bilah status (47 dp) dan bilah gestur
/// (24 dp) render golden 390×844 @3x.
const _crop = (top: 141.0, bottom: 72.0, width: 1170.0, height: 2532.0);

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return ColoredBox(
      color: tokens.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: FadingPattern(
              color: tokens.gold.withValues(alpha: tokens.isDark ? .07 : .09),
              height: 320,
            ),
          ),
          EllipseGlow(
            inner: tokens.isDark
                ? SacredGlow.pagesDark.first
                : SacredGlow.pagesLight.first,
            center: const Offset(.5, .12),
            radii: const Offset(1.1, .45),
            stop: .7,
          ),
          child,
        ],
      ),
    );
  }
}

class _Screenshot extends StatelessWidget {
  const _Screenshot({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.rtl,
  });

  final Uint8List image;
  final String title;
  final String subtitle;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final direction = rtl ? TextDirection.rtl : TextDirection.ltr;
    final visible = _crop.height - _crop.top - _crop.bottom;
    final cropAlign = -1 + 2 * _crop.top / (_crop.top + _crop.bottom);
    return _Backdrop(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 40, 26, 0),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              textDirection: direction,
              maxLines: 2,
              style: SacredText.onboardingTitle.copyWith(
                color: tokens.ink,
                fontSize: rtl ? 27 : 29,
                height: rtl ? 1.5 : 34 / 29,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              textDirection: direction,
              maxLines: 2,
              style: SacredText.body.copyWith(
                color: tokens.sec,
                height: rtl ? 1.7 : 21 / 15,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: AspectRatio(
                  aspectRatio: _crop.width / visible,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: tokens.floatShadows,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.memory(
                        image,
                        fit: BoxFit.fitWidth,
                        alignment: Alignment(0, cropAlign),
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic({
    required this.tagline,
    required this.line,
    required this.rtl,
  });

  final String tagline;
  final String line;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final direction = rtl ? TextDirection.rtl : TextDirection.ltr;
    return _Backdrop(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: .38,
                  child: EightPointStar(size: 214, color: tokens.gold),
                ),
                const BrandLogo(width: 200),
              ],
            ),
            const SizedBox(width: 26),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tagline,
                    textDirection: direction,
                    textAlign: TextAlign.start,
                    style: SacredText.onboardingTitle.copyWith(
                      color: tokens.ink,
                      fontSize: rtl ? 27 : 30,
                      height: rtl ? 1.6 : 36 / 30,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    line,
                    textDirection: direction,
                    textAlign: TextAlign.start,
                    style: SacredText.body.copyWith(
                      color: tokens.sec,
                      fontSize: 14,
                      height: rtl ? 1.8 : 20 / 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menulis tangkapan ke [golden] (path relatif akar proyek), bukan
/// membandingkan: jalur yang sama dengan golden test, jadi pasti terekam.
class _Writer extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    await update(golden, imageBytes);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    final file = File(golden.toFilePath());
    await file.parent.create(recursive: true);
    await file.writeAsBytes(imageBytes);
  }
}

// Tangkap dari akar tampilan supaya resolusinya piksel fisik (1080×1920).
Future<void> _capture(WidgetTester tester, String path) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile(path));

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size pixels,
  required double ratio,
  required bool dark,
}) async {
  tester.view.physicalSize = pixels;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  debugDisableShadows = false;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SacredTheme.themeFor(
        AppPalette.sacred,
        dark ? Brightness.dark : Brightness.light,
      ),
      // Material: gaya teks bawaan (tanpa garis bawah kuning peringatan).
      home: Material(type: MaterialType.transparency, child: child),
    ),
  );
  await tester.pump();
  await loadImages(tester);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    goldenFileComparator = _Writer();
  });

  for (final MapEntry(key: lang, value: copy) in _copy.entries) {
    testWidgets('store assets · $lang', (tester) async {
      for (var i = 0; i < _shots.length; i++) {
        final (name, dark) = _shots[i];
        final (title, subtitle) = _captions(lang)[i];
        await _pump(
          tester,
          _Screenshot(
            image: File('build/store_shots/$name.png').readAsBytesSync(),
            title: title,
            subtitle: subtitle,
            rtl: _rtl(lang),
          ),
          pixels: const Size(1080, 1920),
          ratio: 2.5,
          dark: dark,
        );
        expect(tester.takeException(), isNull, reason: '$lang $name');
        await _capture(
          tester,
          'build/play-store-raw/$lang/screenshot-${i + 1}.png',
        );
      }
      await _pump(
        tester,
        _FeatureGraphic(tagline: copy.$2, line: copy.$3, rtl: _rtl(lang)),
        pixels: const Size(1024, 500),
        ratio: 2,
        dark: false,
      );
      expect(tester.takeException(), isNull, reason: '$lang feature');
      await _capture(tester, 'build/play-store-raw/$lang/feature-graphic.png');
      debugDisableShadows = true;
    });
  }
}
