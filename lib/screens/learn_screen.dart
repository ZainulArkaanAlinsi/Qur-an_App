import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/screens/memorization_screen.dart';
import 'package:quran_app_2025/screens/tajweed_lessons_screen.dart';
import 'package:quran_app_2025/widgets/memorization_tile.dart';

/// Warna lencana ikon; sementara sejajar dengan Pengaturan sampai warnanya
/// dipindahkan ke token tema (revisi v2 Tahap 6).
const _chipGold = Color(0xFF9A7415);
const _chipGreen = Color(0xFF0E6A4C);
const _chipSlate = Color(0xFF56635C);

/// Ruang di bawah daftar supaya tab bar mengambang tidak menutupi isinya.
const _bottomInset = 132.0;

/// Tab Belajar: jalur belajar membaca, Akademi Tajwid, lalu hafalan.
///
/// Urutannya mengikuti tujuan revisi v2 — belajar dulu sampai lancar, baru
/// menghafal. Materi tajwid dan materi belajar membaca ditulis dan ditinjau
/// manusia (`docs/RELIGIOUS_CONTENT_GOVERNANCE.md`); yang belum ditinjau tidak
/// ditampilkan sebagai kartu kosong, melainkan disebut apa adanya.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  /// Juz 30 dimulai dari An-Naba (78) sampai An-Nas (114).
  static const _juzAmmaStart = 78;
  static const _juzAmmaEnd = 114;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: _bottomInset),
      children: [
        const LargeTitle(
          'Belajar',
          subtitle: 'Dari mengenal huruf sampai lancar dan hafal.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: InsetGroupedList(
            header: 'Jalur belajar',
            radius: 22,
            separatorInset: SettingsRow.separatorInset,
            children: [
              Column(
                children: [
                  const _PendingRow(
                    icon: SacredIcons.book,
                    chipColor: _chipSlate,
                    title: 'Belajar Membaca Al-Qur’an',
                    subtitle:
                        'Enam belas tahap, dari 28 huruf hijaiyah sampai '
                        'bacaan gharib.',
                    reason:
                        'Materinya sedang disusun dan wajib ditinjau guru '
                        'bersanad sebelum ditampilkan.',
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: SettingsRow.separatorInset,
                    color: tokens.sep,
                  ),
                  SettingsRow(
                    icon: SacredIcons.palette,
                    chipColor: _chipGold,
                    title: 'Akademi Tajwid',
                    subtitle:
                        'Hukum bacaan beserta contoh ayatnya, dari materi '
                        'yang ditinjau manusia.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TajweedLessonsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: InsetGroupedList(
            header: 'Hafalan',
            radius: 22,
            separatorInset: SettingsRow.separatorInset,
            children: [
              SettingsRow(
                icon: SacredIcons.checkCircle,
                chipColor: _chipGreen,
                title: 'Hafalan saya',
                subtitle: 'Surah yang sedang dihafal dan perlu diulang.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MemorizationScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: InsetGroupedList(
            header: 'Juz Amma',
            radius: 22,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Surah pendek yang paling sering dibaca — '
                      '${_juzAmmaEnd - _juzAmmaStart + 1} surah.',
                      style: SacredText.cardNote.copyWith(color: tokens.sec),
                    ),
                  ),
                  for (var surah = _juzAmmaStart; surah <= _juzAmmaEnd; surah++)
                    MemorizationTile(surah: surah),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Baris untuk materi yang memang belum ada. Dinonaktifkan beserta alasannya,
/// bukan tombol yang tidak melakukan apa-apa.
class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.icon,
    required this.chipColor,
    required this.title,
    required this.subtitle,
    required this.reason,
  });

  final List<String> icon;
  final Color chipColor;
  final String title;
  final String subtitle;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      container: true,
      excludeSemantics: true,
      enabled: false,
      label: '$title. $subtitle $reason',
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: .55,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: LineIcon(icon, color: const Color(0xFFFFFFFF), size: 17),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 9, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: SacredText.settingTitle.copyWith(
                              color: tokens.sec,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.fill,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Sedang disusun',
                            style: SacredText.cardNote.copyWith(
                              color: tokens.sec,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: SacredText.cardNote.copyWith(color: tokens.sec),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: SacredText.cardNote.copyWith(color: tokens.sec),
                    ),
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
