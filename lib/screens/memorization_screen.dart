import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/sacred_shapes.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/features/hafalan/domain/murajaah_schedule.dart';
import 'package:quran_app_2025/models/memorization_status.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/screens/practice_screen.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Rentang ayat untuk satu sesi.
class HafalanRange {
  const HafalanRange(this.surah, this.from, this.to);

  final SurahMeta surah;
  final int from;
  final int to;

  int get count => to - from + 1;

  String get label => from == to
      ? '${surah.displayName} $from'
      : '${surah.displayName} $from–$to';
}

/// Ziyadah hari ini: surah berstatus Menghafal yang pertama, mulai dari ayat
/// yang belum punya catatan hafalan, sebanyak target harian.
HafalanRange? ziyadahToday({
  required List<int> tracked,
  required int dailyAyat,
}) {
  for (final number in tracked) {
    if (SharedPreferencesService.getMemorizationStatus(number) !=
        MemorizationStatus.learning) {
      continue;
    }
    final surah = surahCatalog[number - 1];
    final done = {
      for (final item in SharedPreferencesService.getAyahMemorization(number))
        item.ayah,
    };
    var next = 1;
    while (next <= surah.ayahCount && done.contains(next)) {
      next++;
    }
    if (next > surah.ayahCount) continue;
    final to = (next + dailyAyat - 1).clamp(next, surah.ayahCount);
    return HafalanRange(surah, next, to);
  }
  return null;
}

/// "1, 3, 7, 14, lalu 30" dari [MurajaahSchedule.ladder].
String _ladder() {
  const ladder = MurajaahSchedule.ladder;
  return '${ladder.take(ladder.length - 1).join(', ')}, lalu ${ladder.last}';
}

String _statusLabel(MemorizationStatus status) => switch (status) {
  MemorizationStatus.learning => 'Menghafal',
  MemorizationStatus.memorized => 'Hafal',
  MemorizationStatus.needsReview => 'Perlu murajaah',
  MemorizationStatus.notStarted => 'Belum mulai',
};

/// Tab Hafalan v2 (docs/design/v2/screens/10-hafalan.md, V2-Hafalan.png):
/// tujuan hafalan, apa yang dikerjakan hari ini, dan surah yang dihafal.
///
/// Status hafalan catatan pribadi; aplikasi tidak menilai bacaan
/// (docs/RELIGIOUS_CONTENT_GOVERNANCE.md).
class MemorizationScreen extends StatefulWidget {
  const MemorizationScreen({super.key, this.now});

  /// Hanya untuk tes: tanggal yang dibekukan.
  @visibleForTesting
  final DateTime Function()? now;

  @override
  State<MemorizationScreen> createState() => _MemorizationScreenState();
}

class _MemorizationScreenState extends State<MemorizationScreen> {
  final Future<List<String>> _arabicNames = SuraNamesRepository.load();

  DateTime get _today => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    memorizationRevision.addListener(_refresh);
  }

  @override
  void dispose() {
    memorizationRevision.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _practice(HafalanRange range) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(
          surah: range.surah,
          fromAyah: range.from,
          toAyah: range.to,
        ),
      ),
    );
    _refresh();
  }

  /// Rentang murajaah yang jatuh tempo pada surah pertama.
  HafalanRange? _firstDue(List<AyahMemorization> due) {
    if (due.isEmpty) return null;
    final surah = due.first.surah;
    final ayat = [
      for (final item in due)
        if (item.surah == surah) item.ayah,
    ]..sort();
    return HafalanRange(surahCatalog[surah - 1], ayat.first, ayat.last);
  }

  Future<void> _tasmi(List<int> tracked) async {
    final memorized = [
      for (final surah in tracked)
        if (SharedPreferencesService.getMemorizationStatus(surah) ==
            MemorizationStatus.memorized)
          surah,
    ];
    if (memorized.isEmpty) {
      _say(
        'Tasmi’ untuk surah yang sudah hafal. Tandai sebuah surah "Hafal" '
        'dulu lewat pill statusnya.',
      );
      return;
    }
    final chosen = memorized.length == 1
        ? memorized.single
        : await _pickSurah(context, title: 'Setor hafalan', numbers: memorized);
    if (chosen == null) return;
    final surah = surahCatalog[chosen - 1];
    await _practice(HafalanRange(surah, 1, surah.ayahCount));
  }

  Future<void> _addSurah(List<int> tracked) async {
    final chosen = await _pickSurah(
      context,
      title: 'Tambah surah',
      numbers: [
        for (var n = 1; n <= surahCatalog.length; n++)
          if (!tracked.contains(n)) n,
      ],
      searchable: true,
    );
    if (chosen == null) return;
    await SharedPreferencesService.setMemorizationStatus(
      chosen,
      MemorizationStatus.learning,
    );
    _refresh();
  }

  Future<void> _changeStatus(int surah) async {
    final current = SharedPreferencesService.getMemorizationStatus(surah);
    final next = await showModalBottomSheet<MemorizationStatus>(
      context: context,
      backgroundColor: Theme.of(context).extension<SacredTokens>()!.bg,
      shape: _sheetShape,
      builder: (context) {
        final tokens = Theme.of(context).extension<SacredTokens>()!;
        return _Sheet(
          title: surahCatalog[surah - 1].displayName,
          child: GroupedList(
            children: [
              for (final status in [
                MemorizationStatus.learning,
                MemorizationStatus.memorized,
                MemorizationStatus.needsReview,
              ])
                ListRow(
                  title: _statusLabel(status),
                  trailing: status == current
                      ? LineIcon(
                          SacredIcons.checkCircle,
                          color: tokens.primaryText,
                          size: 22,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, status),
                ),
              ListRow(
                title: 'Hapus dari daftar',
                subtitle: 'Catatan murajaah ayatnya tetap disimpan',
                titleColor: tokens.danger,
                onTap: () =>
                    Navigator.pop(context, MemorizationStatus.notStarted),
              ),
            ],
          ),
        );
      },
    );
    if (next == null || next == current) return;
    await SharedPreferencesService.setMemorizationStatus(surah, next);
    _refresh();
  }

  Future<void> _setTarget() async {
    final current = SharedPreferencesService.getHafalanDailyAyat();
    final value = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).extension<SacredTokens>()!.bg,
      shape: _sheetShape,
      builder: (context) {
        final tokens = Theme.of(context).extension<SacredTokens>()!;
        return _Sheet(
          title: 'Ayat baru per hari',
          child: GroupedList(
            children: [
              for (final count in const [3, 5, 7, 10])
                ListRow(
                  title: '$count ayat',
                  subtitle: '± ${count * 3} menit',
                  trailing: count == current
                      ? LineIcon(
                          SacredIcons.checkCircle,
                          color: tokens.primaryText,
                          size: 22,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, count),
                ),
            ],
          ),
        );
      },
    );
    if (value != null) {
      await SharedPreferencesService.setHafalanDailyAyat(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final tracked = SharedPreferencesService.memorizationTracked();
    final daily = SharedPreferencesService.getHafalanDailyAyat();
    final all = SharedPreferencesService.allAyahMemorization();
    final due = dueForReview(all, _today);
    final today = ziyadahToday(tracked: tracked, dailyAyat: daily);
    final firstDue = _firstDue(due);

    return ListView(
      physics: const BouncingScrollPhysics(),
      // Ruang untuk tab bar mengambang.
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        ScreenHeader(
          title: 'Hafalan',
          subtitle: 'Target: $daily ayat baru per hari',
          trailing: RoundIconButton(
            icon: SacredIcons.sliders,
            tooltip: 'Atur target hafalan',
            surface: true,
            onTap: _setTarget,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _GoalCards(
            cards: [
              _GoalCard(
                icon: SacredIcons.plus,
                title: 'Ziyadah',
                body: 'tambah hafalan baru',
                onTap: today == null
                    ? () => _addSurah(tracked)
                    : () => _practice(today),
              ),
              _GoalCard(
                icon: SacredIcons.repeat,
                title: 'Murajaah',
                body: 'ulang agar tak lupa',
                onTap: firstDue == null
                    ? () => _say('Belum ada ayat yang jatuh tempo hari ini.')
                    : () => _practice(firstDue),
              ),
              _GoalCard(
                icon: SacredIcons.mic,
                title: 'Tasmi’',
                body: 'setor / uji diri',
                onTap: () => _tasmi(tracked),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<String>>(
          future: _arabicNames,
          builder: (context, snapshot) => _ZiyadahCard(
            range: today,
            arabicName: today == null
                ? null
                : snapshot.data?.elementAtOrNull(today.surah.number - 1),
            onStart: today == null
                ? () => _addSurah(tracked)
                : () => _practice(today),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GroupedList(
            children: [
              _MurajaahRow(
                all: all,
                due: due,
                onTap: firstDue == null ? null : () => _practice(firstDue),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
          child: Text(
            // Font UI tidak punya glif panah, jadi tangganya ditulis kata.
            'Jarak murajaah naik ${_ladder()} hari saat lancar, tetap saat '
            'ragu, dan kembali ke 1 hari saat salah.',
            style: SacredText.cardNote.copyWith(color: tokens.sec),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GroupedList(
            label: 'Surah yang dihafal',
            children: [
              for (final surah in tracked)
                _SurahRow(
                  key: ValueKey(surah),
                  surah: surahCatalog[surah - 1],
                  status: SharedPreferencesService.getMemorizationStatus(surah),
                  memorized: SharedPreferencesService.getAyahMemorization(
                    surah,
                  ).length,
                  onOpen: () {
                    final meta = surahCatalog[surah - 1];
                    _practice(
                      today != null && today.surah.number == surah
                          ? today
                          : HafalanRange(meta, 1, meta.ayahCount),
                    );
                  },
                  onStatus: () => _changeStatus(surah),
                ),
              _AddRow(empty: tracked.isEmpty, onTap: () => _addSurah(tracked)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Teks sangat besar (aksesibilitas)?
bool _largeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6;

/// Tiga kartu tujuan sejajar; pada teks sangat besar ditumpuk supaya kata
/// seperti "Ziyadah" tidak dipecah.
class _GoalCards extends StatelessWidget {
  const _GoalCards({required this.cards});

  final List<_GoalCard> cards;

  @override
  Widget build(BuildContext context) {
    if (_largeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            cards[i],
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

/// Kartu tujuan kecil: ikon, judul, keterangan.
class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final List<String> icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SacredText.goalTitle.copyWith(color: tokens.ink)),
        const SizedBox(height: 6),
        Text(body, style: SacredText.goalBody.copyWith(color: tokens.sec)),
      ],
    );
    return Semantics(
      button: true,
      label: '$title, $body',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SacredCard(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: _largeText(context)
                ? Row(
                    children: [
                      LineIcon(icon, color: tokens.primaryText, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: text),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LineIcon(icon, color: tokens.primaryText, size: 20),
                      const SizedBox(height: 6),
                      text,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Kartu hero ZIYADAH HARI INI.
class _ZiyadahCard extends StatelessWidget {
  const _ZiyadahCard({
    required this.range,
    required this.arabicName,
    required this.onStart,
  });

  final HafalanRange? range;
  final String? arabicName;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final range = this.range;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: tokens.art,
                child: GeometricPattern(
                  tile: 46,
                  opacity: .10,
                  color: tokens.artInk,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ZIYADAH HARI INI',
                              style: SacredText.eyebrow.copyWith(
                                color: tokens.artInk,
                              ),
                            ),
                            Text(
                              range?.label ?? 'Pilih surah pertama',
                              style: SacredText.cardTitle.copyWith(
                                color: SacredArt.ink,
                              ),
                            ),
                            Text(
                              range == null
                                  ? 'Juz ’Amma cocok untuk memulai'
                                  : '${range.count} ayat baru · '
                                        '± ${range.count * 3} menit',
                              style: SacredText.dateSub.copyWith(
                                color: SacredArt.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (arabicName != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          arabicName!,
                          textDirection: TextDirection.rtl,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: SacredText.quran,
                            fontSize: 26,
                            height: 1.6,
                            color: tokens.artInk,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  SacredButton(
                    label: range == null ? 'Tambah surah' : 'Mulai sesi',
                    icon: range == null ? SacredIcons.plus : SacredIcons.play,
                    iconFilled: range != null,
                    tone: ButtonTone.gold,
                    expand: true,
                    height: 46,
                    onTap: onStart,
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

/// Murajaah jatuh tempo: surah + jumlah ayat, atau kapan jadwal berikutnya.
class _MurajaahRow extends StatelessWidget {
  const _MurajaahRow({
    required this.all,
    required this.due,
    required this.onTap,
  });

  final List<AyahMemorization> all;
  final List<AyahMemorization> due;
  final VoidCallback? onTap;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  @override
  Widget build(BuildContext context) {
    final String subtitle;
    if (due.isNotEmpty) {
      subtitle = _summary(due);
    } else if (all.isEmpty) {
      subtitle = 'Jadwal mulai setelah sesi pertama';
    } else {
      final next = all
          .map((item) => item.dueOn)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final count = all.where((item) => item.dueOn == next).length;
      subtitle =
          'Berikutnya ${next.day} ${_months[next.month - 1]} · $count ayat';
    }
    return ListRow(
      leading: const SoftIconCircle(
        icon: SacredIcons.calendar,
        size: 40,
        iconSize: 19,
      ),
      title: due.isEmpty
          ? 'Tidak ada murajaah hari ini'
          : 'Murajaah jatuh tempo',
      subtitle: subtitle,
      trailing: due.isEmpty ? null : StatusPill('${due.length} ayat'),
      chevron: due.isNotEmpty,
      onTap: onTap,
    );
  }

  /// "An-Naba’ 1–10 · Al-Ikhlas": surah pertama dengan rentangnya, lalu
  /// nama surah lain.
  static String _summary(List<AyahMemorization> due) {
    final bySurah = <int, List<int>>{};
    for (final item in due) {
      bySurah.putIfAbsent(item.surah, () => []).add(item.ayah);
    }
    final parts = <String>[];
    for (final entry in bySurah.entries) {
      final name = surahCatalog[entry.key - 1].displayName;
      if (parts.isEmpty) {
        final ayat = entry.value..sort();
        parts.add(
          ayat.first == ayat.last
              ? '$name ${ayat.first}'
              : '$name ${ayat.first}–${ayat.last}',
        );
      } else {
        parts.add(name);
      }
    }
    return parts.join(' · ');
  }
}

/// Baris surah: rosette nomor, nama (1 baris), "18/40 ayat", bar progres,
/// pill status. Teks selalu [Expanded]; pill berukuran intrinsik — nama
/// surah tidak lagi turun huruf per huruf.
class _SurahRow extends StatelessWidget {
  const _SurahRow({
    super.key,
    required this.surah,
    required this.status,
    required this.memorized,
    required this.onOpen,
    required this.onStatus,
  });

  final SurahMeta surah;
  final MemorizationStatus status;
  final int memorized;
  final VoidCallback onOpen;
  final VoidCallback onStatus;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final (tone, bar) = switch (status) {
      MemorizationStatus.memorized => (PillTone.gold, tokens.gold),
      MemorizationStatus.needsReview => (
        PillTone.neutral,
        tokens.gold.withValues(alpha: .55),
      ),
      _ => (PillTone.primary, tokens.primaryText),
    };
    final count = '$memorized/${surah.ayahCount} ayat';
    final progress = ProgressBar(
      value: memorized / surah.ayahCount,
      height: 4,
      color: bar,
    );
    final statusPill = Tooltip(
      message: 'Ubah status hafalan',
      child: InkWell(
        onTap: onStatus,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          // Target sentuh lebih tinggi dari pill 24.
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: StatusPill(_statusLabel(status), tone: tone),
        ),
      ),
    );
    return Semantics(
      container: true,
      label:
          '${surah.displayName}, $count, ${_statusLabel(status)}. '
          'Ketuk untuk berlatih.',
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Row(
            children: [
              MediaQuery.withNoTextScaling(
                child: RosetteBadge(
                  label: '${surah.number}',
                  outlined: true,
                  textStyle: SacredText.rosetteNumber,
                  textColor: tokens.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: tokens.sep, width: .5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 14, 12),
                    child: _largeText(context)
                        // Teks sangat besar: nama selebar penuh, lalu jumlah
                        // ayat dan pill, lalu bar — tidak ada yang terpotong.
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                surah.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: SacredText.rowTitle.copyWith(
                                  color: tokens.ink,
                                ),
                              ),
                              Wrap(
                                spacing: 10,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    count,
                                    style: SacredText.surahCount.copyWith(
                                      color: tokens.sec,
                                    ),
                                  ),
                                  statusPill,
                                ],
                              ),
                              const SizedBox(height: 4),
                              progress,
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final name = Text(
                                      surah.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: SacredText.rowTitle.copyWith(
                                        color: tokens.ink,
                                      ),
                                    );
                                    final counter = Text(
                                      count,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: SacredText.surahCount.copyWith(
                                        color: tokens.sec,
                                      ),
                                    );
                                    // Kolom sempit (layar kecil): jumlah ayat
                                    // pindah ke bawah nama, bukan meluber.
                                    final narrow = constraints.maxWidth < 130;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (narrow) ...[
                                          name,
                                          counter,
                                        ] else
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.baseline,
                                            textBaseline:
                                                TextBaseline.alphabetic,
                                            children: [
                                              Expanded(child: name),
                                              const SizedBox(width: 8),
                                              counter,
                                            ],
                                          ),
                                        const SizedBox(height: 6),
                                        progress,
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              statusPill,
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris terakhir daftar: tambah surah. Saat daftar kosong ia menjadi
/// ajakan memulai.
class _AddRow extends StatelessWidget {
  const _AddRow({required this.empty, required this.onTap});

  final bool empty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return ListRow(
      leading: const SoftIconCircle(
        icon: SacredIcons.plus,
        size: 34,
        iconSize: 18,
        gold: false,
      ),
      title: 'Tambah surah',
      titleColor: tokens.primaryText,
      subtitle: empty ? 'Belum ada surah. Juz ’Amma cocok untuk memulai' : null,
      onTap: onTap,
    );
  }
}

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
);

/// Lembar bawah bergaya v2: latar layar, radius atas 28, grabber, judul.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return DecoratedBox(
      decoration: const BoxDecoration(),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: tokens.surf2,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
                child: Text(
                  title,
                  style: SacredText.stageTitle.copyWith(color: tokens.ink),
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pilih satu surah dari [numbers]. Juz ’Amma didahulukan; bisa dicari.
Future<int?> _pickSurah(
  BuildContext context, {
  required String title,
  required List<int> numbers,
  bool searchable = false,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Theme.of(context).extension<SacredTokens>()!.bg,
  shape: _sheetShape,
  builder: (context) =>
      _SurahPicker(title: title, numbers: numbers, searchable: searchable),
);

class _SurahPicker extends StatefulWidget {
  const _SurahPicker({
    required this.title,
    required this.numbers,
    required this.searchable,
  });

  final String title;
  final List<int> numbers;
  final bool searchable;

  @override
  State<_SurahPicker> createState() => _SurahPickerState();
}

class _SurahPickerState extends State<_SurahPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final q = _query.trim().toLowerCase();
    bool matches(int n) =>
        q.isEmpty ||
        '$n' == q ||
        surahCatalog[n - 1].displayName.toLowerCase().contains(q);
    final amma = [
      for (final n in widget.numbers)
        if (n >= 78 && matches(n)) n,
    ];
    final rest = [
      for (final n in widget.numbers)
        if (n < 78 && matches(n)) n,
    ];
    Widget row(int n) {
      final meta = surahCatalog[n - 1];
      return ListRow(
        leading: MediaQuery.withNoTextScaling(
          child: RosetteBadge(
            label: '$n',
            outlined: true,
            textStyle: SacredText.rosetteNumber,
            textColor: tokens.ink,
          ),
        ),
        title: meta.displayName,
        subtitle: '${meta.ayahCount} ayat',
        onTap: () => Navigator.pop(context, n),
      );
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: _Sheet(
        title: widget.title,
        child: ListView(
          children: [
            if (widget.searchable) ...[
              SacredSearchField(
                hint: 'Cari surah',
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 14),
            ],
            if (amma.isNotEmpty)
              GroupedList(
                label: 'Juz ’Amma',
                children: [for (final n in amma) row(n)],
              ),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 18),
              GroupedList(
                label: 'Surah lain',
                children: [for (final n in rest) row(n)],
              ),
            ],
            if (amma.isEmpty && rest.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Surah tidak ditemukan.',
                  style: SacredText.body.copyWith(color: tokens.sec),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
