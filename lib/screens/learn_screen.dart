import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/features/learn/data/curriculum_repository.dart';
import 'package:quran_app_2025/features/learn/domain/curriculum.dart';
import 'package:quran_app_2025/features/onboarding/domain/start_point.dart';
import 'package:quran_app_2025/screens/lesson_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Kelompok tahap pada segmented control Belajar.
enum LearnSegment {
  dasar('Dasar', 0, 9),
  tajwid('Tajwid', 10, 13),
  mahir('Mahir', 14, 16);

  const LearnSegment(this.label, this.firstLevel, this.lastLevel);

  final String label;
  final int firstLevel;
  final int lastLevel;

  bool contains(int level) => level >= firstLevel && level <= lastLevel;

  static LearnSegment of(int level) => values.firstWhere(
    (segment) => segment.contains(level),
    orElse: () => dasar,
  );
}

/// Tab Belajar v2 (docs/design/v2/screens/08-belajar.md, V2-Belajar.png):
/// satu jalur dari huruf sampai bacaan gharib. Akademi Tajwid tidak lagi
/// layar kosong terpisah; hukum tajwid adalah tahap 10–16 di jalur ini.
///
/// Materi yang belum ditinjau tetap terlihat di jalurnya (supaya orang tahu
/// apa yang akan datang) tetapi terkunci dan diberi keterangan jujur
/// (docs/RELIGIOUS_CONTENT_GOVERNANCE.md).
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key, this.includeDrafts});

  /// Hanya untuk tes: paksa tampilan rilis (false) atau debug (true).
  @visibleForTesting
  final bool? includeDrafts;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late Future<Curriculum> _curriculum = CurriculumRepository.load();

  /// Null = ikuti tahap yang sedang dijalani.
  LearnSegment? _segment;

  bool get _drafts => widget.includeDrafts ?? showDraftLessons;

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

  bool _available(Lesson lesson) => lesson.isPublished || _drafts;

  void _open(Lesson lesson) => Navigator.of(context)
      .push(
        MaterialPageRoute<void>(builder: (_) => LessonScreen(lesson: lesson)),
      )
      .then((_) => _refresh());

  void _explainLocked(Lesson lesson) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Tahap ${lesson.level} masih ditinjau guru sebelum bisa dibuka.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Curriculum>(
      future: _curriculum,
      builder: (context, snapshot) {
        final children = <Widget>[
          const ScreenHeader(
            title: 'Belajar',
            subtitle: 'Dari mengenal huruf sampai lancar bertajwid',
          ),
        ];
        if (snapshot.hasError) {
          children.add(
            _Message(
              text: 'Jalur belajar gagal dimuat.',
              actionLabel: 'Coba lagi',
              onAction: () =>
                  setState(() => _curriculum = CurriculumRepository.load()),
            ),
          );
        } else if (snapshot.data case final curriculum?) {
          children.addAll(_path(context, curriculum));
        }
        return ListView(
          physics: const BouncingScrollPhysics(),
          // Ruang untuk tab bar mengambang.
          padding: const EdgeInsets.only(bottom: 120),
          children: children,
        );
      },
    );
  }

  List<Widget> _path(BuildContext context, Curriculum curriculum) {
    final done = SharedPreferencesService.getCompletedLessons();
    final lessons = curriculum.lessons;
    bool open(Lesson lesson) => _available(lesson) && !done.contains(lesson.id);
    // Titik mulai pilihan onboarding (tahap 1 atau 10) menggeser tahap
    // sekarang ke sana; tahap sebelumnya tetap bisa dibuka.
    final floor = StartPoint.saved?.level ?? 0;
    final fromStart = lessons
        .where((lesson) => lesson.level >= floor && open(lesson))
        .firstOrNull;
    // Tahap sekarang: yang pertama belum selesai dan boleh dibuka.
    final current = fromStart ?? lessons.where(open).firstOrNull;
    // Bila tahap titik mulai masih ditinjau, bagiannya tetap yang dibuka
    // (dengan kartu "Materi sedang ditinjau"), bukan dilompati diam-diam.
    final segment =
        _segment ??
        (fromStart == null && floor > 0
            ? LearnSegment.of(floor)
            : LearnSegment.of(current?.level ?? lessons.last.level));
    final shown = [
      for (final lesson in lessons)
        if (segment.contains(lesson.level)) lesson,
    ];
    final anyOpen = shown.any(_available);
    final start = lessons.where((lesson) => lesson.level == 0).firstOrNull;

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: SegmentedPill<LearnSegment>(
          segments: {for (final item in LearnSegment.values) item: item.label},
          value: segment,
          onChanged: (value) => setState(() => _segment = value),
        ),
      ),
      if (!anyOpen)
        // Semua tahap di segmen ini masih ditinjau: katakan itu, jangan
        // tampilkan layar kosong, dan tawarkan tahap terbit berikutnya
        // (docs/design/v3/DESIGN.md §5b).
        _ReviewCard(
          next: current,
          onContinue: current == null ? null : () => _open(current),
        )
      else if (segment == LearnSegment.dasar &&
          (current == null || current.level <= 1) &&
          start != null &&
          _available(start))
        _InfoBox(
          text: 'Belajar berurutan lebih mudah. Kalau sudah bisa membaca, ',
          link: 'ikut tes penempatan',
          onLink: () => _open(start),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          children: [
            for (var i = 0; i < shown.length; i++)
              _PathStep(
                lesson: shown[i],
                state: _stateOf(shown[i], done, current),
                last: i == shown.length - 1,
                drafts: _drafts,
                onOpen: () => _available(shown[i])
                    ? _open(shown[i])
                    : _explainLocked(shown[i]),
              ),
          ],
        ),
      ),
    ];
  }

  _StepState _stateOf(Lesson lesson, Set<String> done, Lesson? current) {
    if (!_available(lesson)) return _StepState.locked;
    if (done.contains(lesson.id)) return _StepState.done;
    if (lesson.id == current?.id) return _StepState.current;
    return _StepState.upcoming;
  }
}

enum _StepState { done, current, upcoming, locked }

/// Kartu "Materi sedang ditinjau": bagian ini belum terbit, dan "Lanjutkan"
/// membuka tahap terbit pertama yang belum selesai.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.next, required this.onContinue});

  final Lesson? next;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final lesson = next;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SacredCard(
        radius: 20,
        color: tokens.goldSoft,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LineIcon(SacredIcons.info, color: tokens.goldText, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Materi sedang ditinjau',
                      style: SacredText.stageTitle.copyWith(color: tokens.ink),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Materi di bagian ini sedang ditinjau guru bersanad. Tahapnya '
              'sudah terlihat di bawah dan akan terbuka satu per satu '
              'setelah diperiksa.',
              style: SacredText.infoBox.copyWith(color: tokens.ink),
            ),
            if (lesson != null) ...[
              const SizedBox(height: 12),
              Text(
                'Sementara itu, lanjutkan Tahap ${lesson.level}: '
                '${lesson.title}.',
                style: SacredText.stageSummary.copyWith(color: tokens.sec),
              ),
              const SizedBox(height: 10),
              SacredButton(
                label: 'Lanjutkan',
                icon: SacredIcons.play,
                iconFilled: true,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: SacredText.buttonSmall,
                onTap: onContinue,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kotak info emas: saran + tautan opsional.
class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text, this.link, this.onLink});

  final String text;
  final String? link;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final style = SacredText.infoBox.copyWith(color: tokens.ink);
    final body = Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text),
          if (link != null) ...[
            TextSpan(
              text: link,
              style: style.copyWith(
                color: tokens.primaryText,
                fontWeight: FontWeight.w800,
                fontVariations: const [FontVariation('wght', 800)],
              ),
            ),
            const TextSpan(text: '.'),
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Semantics(
        button: onLink != null,
        child: InkWell(
          onTap: onLink,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: tokens.goldSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                LineIcon(SacredIcons.info, color: tokens.goldText, size: 20),
                const SizedBox(width: 10),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu tahap pada jalur: node 44 + garis penghubung 2 px, lalu judul atau
/// kartu tahap aktif.
class _PathStep extends StatelessWidget {
  const _PathStep({
    required this.lesson,
    required this.state,
    required this.last,
    required this.drafts,
    required this.onOpen,
  });

  final Lesson lesson;
  final _StepState state;
  final bool last;
  final bool drafts;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                _Node(level: lesson.level, state: state, onTap: onOpen),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: state == _StepState.done
                          ? tokens.gold
                          : tokens.surf2,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: state == _StepState.current
                  ? _ActiveCard(lesson: lesson, drafts: drafts, onOpen: onOpen)
                  : _StepLabel(
                      lesson: lesson,
                      state: state,
                      drafts: drafts,
                      onTap: onOpen,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.level, required this.state, required this.onTap});

  final int level;
  final _StepState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final (Color bg, Color fg, Color? ring) = switch (state) {
      _StepState.done => (tokens.gold, tokens.onGold, null),
      _StepState.current => (tokens.cta, tokens.ctaInk, null),
      _StepState.upcoming => (tokens.surf, tokens.sec, tokens.sep),
      _StepState.locked => (tokens.surf, tokens.tertiary, tokens.sep),
    };
    return ExcludeSemantics(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: ring == null ? null : Border.all(color: ring, width: 1.5),
          ),
          child: state == _StepState.done
              ? LineIcon(SacredIcons.checkCircle, color: fg, size: 22)
              : Text(
                  '$level',
                  textScaler: TextScaler.noScaling,
                  style: SacredText.nodeNumber.copyWith(color: fg),
                ),
        ),
      ),
    );
  }
}

/// Judul + keterangan tahap yang bukan tahap aktif.
class _StepLabel extends StatelessWidget {
  const _StepLabel({
    required this.lesson,
    required this.state,
    required this.drafts,
    required this.onTap,
  });

  final Lesson lesson;
  final _StepState state;
  final bool drafts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final locked = state == _StepState.locked;
    final draft = !lesson.isPublished && drafts && !locked;
    final String note = switch (state) {
      _StepState.done => 'Selesai',
      _StepState.locked => 'Materi sedang ditinjau',
      _ when draft => 'Tahap ${lesson.level} · draf',
      _ => 'Tahap ${lesson.level}',
    };
    return Semantics(
      button: true,
      label: 'Tahap ${lesson.level}, ${lesson.title}, $note',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lesson.title,
                style: SacredText.rowTitle.copyWith(
                  color: locked ? tokens.sec : tokens.ink,
                ),
              ),
              Text(
                note,
                style: SacredText.listMeta.copyWith(
                  color: draft ? tokens.goldText : tokens.sec,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu tahap aktif: judul, pill bagian "2 / 6", ringkasan, bar progres,
/// tombol Mulai/Lanjutkan.
class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.lesson,
    required this.drafts,
    required this.onOpen,
  });

  final Lesson lesson;
  final bool drafts;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final total = lesson.stepCount;
    final step = SharedPreferencesService.getLessonStep(
      lesson.id,
    ).clamp(0, total);
    final started = step > 0;
    return SacredCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  lesson.title,
                  style: SacredText.stageTitle.copyWith(color: tokens.ink),
                ),
              ),
              if (total > 0) ...[
                const SizedBox(width: 8),
                StatusPill('$step / $total', tone: PillTone.primary),
              ],
            ],
          ),
          if (!lesson.isPublished && drafts) ...[
            const SizedBox(height: 4),
            Text(
              'Draf · belum ditinjau',
              style: SacredText.listMeta.copyWith(color: tokens.goldText),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            lesson.summary,
            style: SacredText.stageSummary.copyWith(color: tokens.sec),
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            ProgressBar(value: step / total, height: 5),
          ],
          const SizedBox(height: 8),
          SacredButton(
            label: !lesson.hasContent
                ? 'Lihat kerangka'
                : started
                ? 'Lanjutkan'
                : 'Mulai',
            icon: SacredIcons.play,
            iconFilled: true,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            textStyle: SacredText.buttonSmall,
            onTap: onOpen,
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: SacredText.body.copyWith(color: tokens.sec)),
          const SizedBox(height: 12),
          SacredButton(
            label: actionLabel,
            tone: ButtonTone.soft,
            height: 40,
            textStyle: SacredText.buttonSmall,
            onTap: onAction,
          ),
        ],
      ),
    );
  }
}
