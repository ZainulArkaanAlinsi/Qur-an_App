import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/screens/lesson_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Kartu jalur belajar di tab Belajar: kemajuan, tahap berikutnya, dan pintu
/// ke peta 16 tahap.
///
/// Di rilis hanya materi terbit yang dihitung, jadi selama seluruh materi
/// masih draf kartunya mengatakan itu apa adanya alih-alih menampilkan jalur
/// kosong.
class LearnPathCard extends StatelessWidget {
  const LearnPathCard({super.key, required this.future});

  final Future<Curriculum> future;

  @override
  Widget build(BuildContext context) => FutureBuilder<Curriculum>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const _Notice(
          title: 'Jalur belajar gagal dimuat',
          body: 'Materinya tidak terbaca, jadi tidak ada yang ditampilkan.',
        );
      }
      final curriculum = snapshot.data;
      if (curriculum == null) {
        return const _Notice(
          title: 'Belajar Membaca Al-Qur’an',
          body: 'Memuat jalur belajar…',
        );
      }
      final visible = curriculum.visible(includeDrafts: showDraftLessons);
      if (visible.isEmpty) {
        return const _Notice(
          title: 'Belajar Membaca Al-Qur’an',
          body:
              'Enam belas tahap, dari 28 huruf hijaiyah sampai bacaan gharib. '
              'Kerangkanya sudah ada, tapi belum ditampilkan karena materi '
              'agama wajib ditinjau guru bersanad lebih dulu.',
        );
      }
      return _Progress(lessons: visible);
    },
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.lessons});

  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final done = SharedPreferencesService.getCompletedLessons();
    final completed = lessons.where((item) => done.contains(item.id)).length;
    final next = lessons.where((item) => !done.contains(item.id)).firstOrNull;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: 'Belajar membaca, $completed dari ${lessons.length} tahap',
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LearnPathScreen(lessons: lessons),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Belajar Membaca Al-Qur’an',
                      style: SacredText.listName.copyWith(color: tokens.ink),
                    ),
                  ),
                  Text(
                    '$completed/${lessons.length}',
                    style: SacredText.chip.copyWith(color: tokens.primaryText),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: completed / lessons.length,
                  minHeight: 6,
                  backgroundColor: tokens.surf2,
                  valueColor: AlwaysStoppedAnimation<Color>(tokens.primaryText),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                next == null
                    ? 'Semua tahap sudah ditandai selesai.'
                    : 'Lanjut: tahap ${next.level} — ${next.title}',
                style: SacredText.cardNote.copyWith(color: tokens.sec),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Peta tahap, urut, dengan penanda mana yang sudah selesai.
class LearnPathScreen extends StatefulWidget {
  const LearnPathScreen({super.key, required this.lessons});

  final List<Lesson> lessons;

  @override
  State<LearnPathScreen> createState() => _LearnPathScreenState();
}

class _LearnPathScreenState extends State<LearnPathScreen> {
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
    final done = SharedPreferencesService.getCompletedLessons();
    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(title: const Text('Jalur belajar')),
      body: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: widget.lessons.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final lesson = widget.lessons[index];
          return _Tile(
            lesson: lesson,
            done: done.contains(lesson.id),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LessonScreen(lesson: lesson),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.lesson, required this.done, required this.onTap});

  final Lesson lesson;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label:
          'Tahap ${lesson.level}, ${lesson.title}, '
          '${done ? 'selesai' : 'belum selesai'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.surf,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: done ? tokens.primaryText : tokens.sep),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? tokens.toggleOn : tokens.fill,
                  shape: BoxShape.circle,
                ),
                child: done
                    ? Icon(Icons.check_rounded, size: 18, color: tokens.ctaInk)
                    : Text(
                        '${lesson.level}',
                        style: SacredText.chip.copyWith(color: tokens.sec),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: SacredText.listName.copyWith(color: tokens.ink),
                    ),
                    Text(
                      lesson.hasContent
                          ? lesson.summary
                          : 'Kerangka — materinya belum ditulis.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SacredText.cardNote.copyWith(color: tokens.sec),
                    ),
                  ],
                ),
              ),
              LineIcon(
                SacredIcons.chevronRight,
                color: tokens.sec,
                size: 18,
                strokeWidth: 2.2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: SacredText.listName.copyWith(color: tokens.ink)),
          const SizedBox(height: 4),
          Text(body, style: SacredText.cardNote.copyWith(color: tokens.sec)),
        ],
      ),
    );
  }
}
