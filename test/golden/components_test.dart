import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';

import 'golden_harness.dart';

const _tabs = [
  SacredTab(icon: SacredIcons.home, label: 'Beranda'),
  SacredTab(icon: SacredIcons.book, label: 'Qur’an'),
  SacredTab(icon: SacredIcons.cap, label: 'Belajar'),
  SacredTab(icon: SacredIcons.layers, label: 'Hafalan'),
  SacredTab(icon: SacredIcons.user, label: 'Saya'),
];

/// Galeri komponen dasar v2. Isinya meniru potongan mockup supaya bisa
/// dibandingkan langsung: grup HARI INI (Beranda), baris Saya, pill Hafalan,
/// tombol, dan tab bar.
class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 140),
              children: [
                const ScreenHeader(
                  title: 'Qari',
                  subtitle: 'Riwayat Hafs · 40+ qari',
                  backLabel: 'Saya',
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: SacredSearchField(hint: 'Cari qari'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: GroupedList(
                    label: 'Hari ini',
                    children: [
                      ListRow(
                        leading: ProgressRing(
                          value: 2 / 6,
                          size: 44,
                          stroke: 5,
                          child: LineIcon(
                            SacredIcons.cap,
                            color: tokens.primaryText,
                            size: 18,
                          ),
                        ),
                        title: 'Lanjutkan belajar',
                        subtitle: 'Tahap 1 · Huruf hijaiyah · 2 dari 6',
                        chevron: true,
                        onTap: () {},
                      ),
                      const ListRow(
                        leading: SoftIconCircle(icon: SacredIcons.layers),
                        title: 'Murajaah hari ini',
                        subtitle: 'An-Naba’ 1–10 · jatuh tempo',
                        trailing: StatusPill('10 ayat'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: GroupedList(
                    label: 'Membaca',
                    children: [
                      ListRow(
                        leading: const IconBadge(
                          icon: SacredIcons.pageSingle,
                          color: SacredBadge.green,
                        ),
                        title: 'Mode bawaan',
                        trailing: const RowValue('1 Halaman'),
                        chevron: true,
                        onTap: () {},
                      ),
                      ListRow(
                        leading: const IconBadge(
                          icon: SacredIcons.palette,
                          color: SacredBadge.gold,
                        ),
                        title: 'Tajwid berwarna',
                        trailing: IosToggle(value: true, onChanged: (_) {}),
                      ),
                      // Nama sangat panjang: harus elipsis satu baris, pill
                      // tetap utuh (bug "turun huruf per huruf").
                      const ListRow(
                        leading: IconBadge(
                          icon: SacredIcons.translate,
                          color: SacredBadge.blue,
                        ),
                        title: 'Muhammad Siddiq Al-Minshawi (Mujawwad)',
                        subtitle: 'Nama sangat panjang tetap satu baris',
                        trailing: StatusPill(
                          'Perlu murajaah',
                          tone: PillTone.neutral,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusPill('Menghafal', tone: PillTone.primary),
                      StatusPill('Hafal'),
                      StatusPill('Perlu murajaah', tone: PillTone.neutral),
                      StatusPill('berikutnya', tone: PillTone.solid),
                      StatusPill('MENUNGGU'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Row(
                    children: [
                      SacredButton(
                        label: 'Lanjutkan',
                        icon: SacredIcons.play,
                        iconFilled: true,
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      SacredButton(
                        label: 'Kiblat',
                        icon: SacredIcons.compass,
                        tone: ButtonTone.surface,
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: SacredText.buttonSmall,
                        onTap: () {},
                      ),
                      const SizedBox(width: 8),
                      RoundIconButton(
                        icon: SacredIcons.search,
                        tooltip: 'Cari',
                        surface: true,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.art,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: SacredButton(
                      label: 'Mulai sesi',
                      icon: SacredIcons.play,
                      iconFilled: true,
                      tone: ButtonTone.gold,
                      expand: true,
                      onTap: () {},
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SacredButton(
                    label: 'Buka kata berikutnya',
                    icon: SacredIcons.eyeOff,
                    tone: ButtonTone.soft,
                    height: 40,
                    textStyle: SacredText.buttonSmall,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingTabBar(
              tabs: _tabs,
              currentIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  for (final variant in GoldenVariant.all) {
    testWidgets('komponen dasar v2 · ${variant.suffix}', (tester) async {
      await pumpGolden(tester, const _Gallery(), variant: variant);
      expect(tester.takeException(), isNull);
      expectNotTruncated(tester, [
        'Beranda',
        'Qur’an',
        'Belajar',
        'Hafalan',
        'Saya',
        'Lanjutkan',
        'Kiblat',
        'Mulai sesi',
        'Buka kata berikutnya',
        '10 ayat',
        'Perlu murajaah',
        'berikutnya',
      ]);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/00_components_${variant.suffix}.png'),
      );
    });
  }
}
