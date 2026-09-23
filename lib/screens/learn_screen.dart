import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/chip_palette.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/screens/learn_path.dart';
import 'package:quran_app_2025/screens/memorization_screen.dart';
import 'package:quran_app_2025/screens/tajweed_lessons_screen.dart';
import 'package:quran_app_2025/widgets/memorization_tile.dart';

/// Ruang di bawah daftar supaya tab bar mengambang tidak menutupi isinya.
const _bottomInset = 132.0;

/// Tab Belajar: jalur belajar membaca, Akademi Tajwid, lalu hafalan.
///
/// Urutannya mengikuti tujuan revisi v2 — belajar dulu sampai lancar, baru
/// menghafal. Materi tajwid dan materi belajar membaca ditulis dan ditinjau
/// manusia (`docs/RELIGIOUS_CONTENT_GOVERNANCE.md`); yang belum ditinjau tidak
/// ditampilkan sebagai kartu kosong, melainkan disebut apa adanya.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  /// Juz 30 dimulai dari An-Naba (78) sampai An-Nas (114).
  static const _juzAmmaStart = 78;
  static const _juzAmmaEnd = 114;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final Future<Curriculum> _curriculum = CurriculumRepository.load();

  @override
  void initState() {
    super.initState();
    learnRevision.addListener(_refresh);
  }

  @override
  void dispose() {
    learnRevision.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

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
                  LearnPathCard(future: _curriculum),
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: SettingsRow.separatorInset,
                    color: tokens.sep,
                  ),
                  SettingsRow(
                    icon: SacredIcons.palette,
                    chipColor: ChipTone.gold.of(context),
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
                chipColor: ChipTone.green.of(context),
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
                      '${LearnScreen._juzAmmaEnd - LearnScreen._juzAmmaStart + 1} surah.',
                      style: SacredText.cardNote.copyWith(color: tokens.sec),
                    ),
                  ),
                  for (
                    var surah = LearnScreen._juzAmmaStart;
                    surah <= LearnScreen._juzAmmaEnd;
                    surah++
                  )
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
