import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';

void main() {
  group('pengurai path SVG', () {
    test('garis relatif dan absolut menghasilkan kotak yang sama', () {
      final absolute = parseSvgPath('M0 0 L10 0 L10 10 L0 10 Z');
      final relative = parseSvgPath('m0 0 l10 0 l0 10 l-10 0 z');
      expect(absolute.getBounds(), relative.getBounds());
      expect(absolute.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
    });

    test('h dan v memakai koordinat berjalan', () {
      final path = parseSvgPath('M2 3 h6 v4');
      expect(path.getBounds(), const Rect.fromLTRB(2, 3, 8, 7));
    });

    test('busur a membentuk lingkaran penuh', () {
      // Dua setengah lingkaran berjari-jari 5 dari (5,10) ke (15,10).
      final path = parseSvgPath('M5 10 a5 5 0 1 0 10 0 a5 5 0 1 0 -10 0');
      final bounds = path.getBounds();
      expect(bounds.width, closeTo(10, 0.01));
      expect(bounds.height, closeTo(10, 0.01));
    });

    test('angka tanpa nol di depan dan tanda minus terbaca', () {
      final path = parseSvgPath('M0 0 l.5-.5');
      expect(path.getBounds(), const Rect.fromLTRB(0, -0.5, 0.5, 0));
    });

    test('perintah yang tidak didukung ditolak, bukan digambar salah', () {
      expect(() => parseSvgPath('M0 0 X5 5'), throwsFormatException);
    });

    test('path tanpa perintah pembuka ditolak', () {
      expect(() => parseSvgPath('5 5'), throwsFormatException);
    });
  });

  group('ikon desain', () {
    const icons = {
      'bookmark': SacredIcons.bookmark,
      'book': SacredIcons.book,
      'checkCircle': SacredIcons.checkCircle,
      'home': SacredIcons.home,
      'chart': SacredIcons.chart,
      'sliders': SacredIcons.sliders,
      'search': SacredIcons.search,
      'headphones': SacredIcons.headphones,
      'play': SacredIcons.play,
      'flame': SacredIcons.flame,
      'sun': SacredIcons.sun,
    };

    test('semuanya terurai dan berada di dalam viewBox 24x24', () {
      for (final entry in icons.entries) {
        for (final d in entry.value) {
          final bounds = parseSvgPath(d).getBounds();
          // Ikon seperti batang grafik berupa garis lurus: lebarnya nol,
          // jadi yang diperiksa panjang sisi terpanjang, bukan isEmpty.
          expect(
            bounds.longestSide,
            greaterThan(0),
            reason: '${entry.key}: path kosong',
          );
          expect(
            bounds.left >= -0.5 &&
                bounds.top >= -0.5 &&
                bounds.right <= 24.5 &&
                bounds.bottom <= 24.5,
            isTrue,
            reason: '${entry.key}: keluar viewBox ($bounds)',
          );
        }
      }
    });

    testWidgets('LineIcon menggambar tanpa galat pada ukuran kecil', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            children: [
              for (final entry in icons.entries)
                LineIcon(
                  entry.value,
                  color: const Color(0xFF00513B),
                  size: 19,
                  filled: entry.key == 'play',
                ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
