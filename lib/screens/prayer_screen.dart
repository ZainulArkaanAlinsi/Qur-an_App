import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_buttons.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/sacred_list.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/screens/qibla_screen.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/reminder_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:timezone/timezone.dart' as tz;

/// Menjadwalkan pengingat; mengembalikan false bila izin notifikasi ditolak.
typedef ReminderScheduler =
    Future<bool> Function(
      PrayerDay day,
      Set<String> prayers,
      int? quranAt,
      int? sessionAt,
    );

Future<bool> _scheduleWithService(
  PrayerDay day,
  Set<String> prayers,
  int? quranAt,
  int? sessionAt,
) async {
  final wantsAny = prayers.isNotEmpty || quranAt != null || sessionAt != null;
  if (wantsAny && !await ReminderService.instance.requestPermission()) {
    return false;
  }
  await ReminderService.instance.schedule(
    day: day,
    prayerNames: prayers,
    quranReminderMinutes: quranAt,
    sessionReminderMinutes: sessionAt,
    city: SharedPreferencesService.getPrayerCity(),
    country: SharedPreferencesService.getPrayerCountry(),
  );
  return true;
}

/// Waktu [hhmm] pada hari [day] di zona kota itu (bukan zona ponsel), supaya
/// hitung mundur tetap benar untuk kota di zona lain.
DateTime? prayerClock(PrayerDay day, String? hhmm) {
  if (hhmm == null) return null;
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmm);
  if (match == null) return null;
  final date = day.gregorianDate;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  final zone = day.timezone;
  if (zone != null) {
    try {
      return tz.TZDateTime(
        tz.getLocation(zone),
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
    } on Object {
      // Zona tidak dikenal: pakai jam dinding ponsel.
    }
  }
  return DateTime(date.year, date.month, date.day, hour, minute);
}

/// "2 j 24 m", "24 m", atau "sebentar lagi".
String prayerCountdown(Duration left) {
  final hours = left.inHours;
  final minutes = left.inMinutes % 60;
  if (hours == 0 && minutes == 0) return 'sebentar lagi';
  return hours == 0 ? '$minutes m' : '$hours j $minutes m';
}

/// Salat (docs/design/v2/screens/14-salat.md).
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({
    super.key,
    this.loader,
    this.clock = DateTime.now,
    this.scheduler,
  });

  /// Hanya untuk tes: jadwal buatan untuk [date] (null = hari ini).
  @visibleForTesting
  final Future<PrayerDay> Function(DateTime? date)? loader;

  /// Hanya untuk tes: jam tetap.
  @visibleForTesting
  final DateTime Function() clock;

  /// Hanya untuk tes: penjadwal pengingat buatan.
  @visibleForTesting
  final ReminderScheduler? scheduler;

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  late Future<PrayerDay> _day = _load(null);
  late final Set<String> _enabled =
      SharedPreferencesService.getPrayerReminders();
  int? _quranMinutes = SharedPreferencesService.getQuranReminderMinutes();
  int? _sessionMinutes = SharedPreferencesService.getSessionReminderMinutes();

  /// Jadwal besok, dimuat hanya setelah Isya untuk hitung mundur Subuh.
  Future<PrayerDay>? _tomorrow;
  PrayerDay? _tomorrowDay;
  String? _notice;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Hitung mundur dan sorotan salat berikutnya ikut berjalan.
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<PrayerDay> _load(DateTime? date) =>
      widget.loader?.call(date) ??
      PrayerService.fetch(
        city: SharedPreferencesService.getPrayerCity(),
        country: SharedPreferencesService.getPrayerCountry(),
        date: date,
      );

  void _reload() => setState(() {
    _day = _load(null);
    _tomorrow = null;
    _tomorrowDay = null;
  });

  void _loadTomorrow(PrayerDay today) {
    if (_tomorrow != null) return;
    final date = today.gregorianDate.add(const Duration(days: 1));
    _tomorrow = _load(DateTime(date.year, date.month, date.day))
      ..then((day) {
        if (mounted) setState(() => _tomorrowDay = day);
      }, onError: (_) {});
  }

  /// Menyimpan pilihan pengingat. Bila izin ditolak, tampilan dikembalikan
  /// ke keadaan sebelumnya supaya tidak ada toggle yang pura-pura aktif.
  Future<void> _saveReminders(
    PrayerDay day, {
    required Set<String> previous,
    required int? previousQuran,
    int? previousSession,
    bool sessionChanged = false,
  }) async {
    final schedule = widget.scheduler ?? _scheduleWithService;
    final ok = await schedule(
      day,
      Set.of(_enabled),
      _quranMinutes,
      _sessionMinutes,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _enabled
          ..clear()
          ..addAll(previous);
        _quranMinutes = previousQuran;
        if (sessionChanged) _sessionMinutes = previousSession;
        _notice =
            'Izin notifikasi belum diberikan, jadi pengingat tidak '
            'diaktifkan. Izinkan notifikasi di pengaturan ponsel.';
      });
      return;
    }
    await SharedPreferencesService.setPrayerReminders(_enabled);
    await SharedPreferencesService.setQuranReminderMinutes(_quranMinutes);
    await SharedPreferencesService.setSessionReminderMinutes(_sessionMinutes);
    if (mounted) setState(() => _notice = null);
  }

  Future<void> _toggle(PrayerDay day, String name, bool on) async {
    final previous = Set.of(_enabled);
    setState(() => on ? _enabled.add(name) : _enabled.remove(name));
    await _saveReminders(day, previous: previous, previousQuran: _quranMinutes);
  }

  Future<void> _changePlace() async {
    final place = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).extension<SacredTokens>()!.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _PlaceSheet(
        city: SharedPreferencesService.getPrayerCity(),
        country: SharedPreferencesService.getPrayerCountry(),
      ),
    );
    if (place == null || !mounted) return;
    await SharedPreferencesService.setPrayerPlace(place.$1, place.$2);
    _reload();
    // Pengingat yang sudah aktif dijadwalkan ulang untuk kota baru.
    try {
      final day = await _day;
      if (mounted &&
          (_enabled.isNotEmpty ||
              _quranMinutes != null ||
              _sessionMinutes != null)) {
        await _saveReminders(
          day,
          previous: Set.of(_enabled),
          previousQuran: _quranMinutes,
        );
      }
    } on Object {
      // Kota tidak ditemukan atau luring: pesan galat sudah tampil.
    }
  }

  /// Pengingat harian Sesi hari ini (docs/design/v5-sesi-harian §4): jam
  /// sendiri, dijadwalkan bersama pengingat lain.
  Future<void> _sessionReminder(PrayerDay day) async {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final active = _sessionMinutes != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: tokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GroupedList(
            label: 'Pengingat Sesi hari ini',
            children: [
              ListRow(
                title: active ? 'Ubah jam' : 'Pilih jam',
                subtitle: active
                    ? 'Sekarang setiap hari pukul ${_format(_sessionMinutes!)}'
                    : 'Sekitar 10 menit belajar setiap hari',
                chevron: true,
                onTap: () => Navigator.pop(context, 'time'),
              ),
              if (active)
                ListRow(
                  title: 'Matikan pengingat',
                  titleColor: tokens.danger,
                  onTap: () => Navigator.pop(context, 'off'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    final previous = _sessionMinutes;
    if (action == 'off') {
      setState(() => _sessionMinutes = null);
    } else {
      final initial = previous ?? 7 * 60;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
        helpText: 'Jam pengingat Sesi hari ini',
      );
      if (time == null || !mounted) return;
      setState(() => _sessionMinutes = time.hour * 60 + time.minute);
    }
    await _saveReminders(
      day,
      previous: Set.of(_enabled),
      previousQuran: _quranMinutes,
      previousSession: previous,
      sessionChanged: true,
    );
  }

  Future<void> _quranReminder(PrayerDay day) async {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final active = _quranMinutes != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: tokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GroupedList(
            label: 'Pengingat tilawah',
            children: [
              ListRow(
                title: active ? 'Ubah jam' : 'Pilih jam',
                subtitle: active
                    ? 'Sekarang setiap hari pukul ${_format(_quranMinutes!)}'
                    : 'Satu pengingat setiap hari',
                chevron: true,
                onTap: () => Navigator.pop(context, 'time'),
              ),
              if (active)
                ListRow(
                  title: 'Matikan pengingat',
                  titleColor: tokens.danger,
                  onTap: () => Navigator.pop(context, 'off'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    final previous = _quranMinutes;
    if (action == 'off') {
      setState(() => _quranMinutes = null);
    } else {
      final initial = previous ?? 20 * 60;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
        helpText: 'Jam pengingat tilawah',
      );
      if (time == null || !mounted) return;
      setState(() => _quranMinutes = time.hour * 60 + time.minute);
    }
    await _saveReminders(
      day,
      previous: Set.of(_enabled),
      previousQuran: previous,
    );
  }

  static String _format(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<PrayerDay>(
          future: _day,
          builder: (context, snapshot) => ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              ScreenHeader(
                title: 'Salat',
                backLabel: 'Beranda',
                trailing: _QiblaButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const QiblaScreen(),
                    ),
                  ),
                ),
              ),
              _PlaceRow(
                city: SharedPreferencesService.getPrayerCity(),
                onChange: _changePlace,
              ),
              ..._body(context, tokens, snapshot),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    SacredTokens tokens,
    AsyncSnapshot<PrayerDay> snapshot,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text(
            'Memuat jadwal salat…',
            style: SacredText.listMeta.copyWith(color: tokens.sec),
          ),
        ),
      ];
    }
    if (snapshot.hasError) {
      return [
        _Notice(
          text:
              'Jadwal salat belum bisa dimuat. Periksa koneksi internet dan '
              'nama kota, lalu coba lagi.',
          action: 'Coba lagi',
          onAction: _reload,
        ),
      ];
    }

    final day = snapshot.data!;
    final now = widget.clock();
    final next = day.nextLabelAt(now);
    final tomorrow = next == 'Subuh besok';
    if (tomorrow) _loadTomorrow(day);
    final target = tomorrow
        ? (_tomorrowDay == null
              ? null
              : prayerClock(_tomorrowDay!, _tomorrowDay!.prayers['Subuh']))
        : prayerClock(day, day.prayers[next]);

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
        child: Text(
          // Cara jadwal ini dihitung; zona waktu dari respons AlAdhan.
          [
            'Metode ${PrayerService.methodShort} '
                '(AlAdhan #${PrayerService.methodId})',
            ?day.timezone,
          ].join(' · '),
          style: SacredText.listMeta.copyWith(color: tokens.sec),
        ),
      ),
      if (day.fromCache)
        const _Notice(
          text:
              'Sedang luring. Jadwal ini tersimpan dari pemuatan terakhir '
              'untuk hari ini.',
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: _SkyCard(day: day, next: next, target: target, now: now),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: _PrayerList(
          day: day,
          next: next,
          enabled: _enabled,
          onToggle: (name, on) => _toggle(day, name, on),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: InsetGroupedList(
          radius: 22,
          children: [
            SettingsRow(
              icon: SacredIcons.bell,
              chipColor: SacredBadge.red,
              title: 'Pengingat tilawah',
              value: _quranMinutes == null
                  ? 'Nonaktif'
                  : _format(_quranMinutes!),
              subtitle: _quranMinutes == null
                  ? 'Belum diaktifkan'
                  : 'Setiap hari',
              onTap: () => _quranReminder(day),
            ),
            SettingsRow(
              icon: SacredIcons.cap,
              chipColor: SacredBadge.green,
              title: 'Sesi hari ini',
              value: _sessionMinutes == null
                  ? 'Nonaktif'
                  : _format(_sessionMinutes!),
              subtitle: _sessionMinutes == null
                  ? 'Belum diaktifkan'
                  : 'Setiap hari',
              onTap: () => _sessionReminder(day),
            ),
          ],
        ),
      ),
      if (_notice != null) _Notice(text: _notice!),
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 14, 32, 0),
        child: Text(
          'Pengingat salat disiapkan untuk 14 hari ke depan. Buka aplikasi '
          'sebelum periode itu habis agar jadwalnya diperbarui. Ketepatan '
          'notifikasi bergantung pada pengaturan baterai ponsel.',
          style: SacredText.cardNote.copyWith(color: tokens.sec),
        ),
      ),
    ];
  }
}

/// Tombol Kiblat di kanan judul: 38 tinggi, kartu berbayang.
class _QiblaButton extends StatelessWidget {
  const _QiblaButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Arah kiblat',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: tokens.surf,
              borderRadius: BorderRadius.circular(19),
              boxShadow: tokens.cardShadows,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LineIcon(
                  SacredIcons.compass,
                  color: tokens.primaryText,
                  size: 18,
                  strokeWidth: 2,
                ),
                const SizedBox(width: 6),
                Text(
                  'Kiblat',
                  style: SacredText.buttonSmall.copyWith(color: tokens.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lokasi dan tautan Ganti kota.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.city, required this.onChange});

  final String city;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          LineIcon(
            SacredIcons.pin,
            color: tokens.sec,
            size: 16,
            strokeWidth: 2,
          ),
          Text(city, style: SacredText.segmentIdle.copyWith(color: tokens.ink)),
          Semantics(
            button: true,
            excludeSemantics: true,
            label: 'Ganti kota, sekarang $city',
            child: InkWell(
              onTap: onChange,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Ganti kota',
                  style: SacredText.buttonSmall.copyWith(
                    color: tokens.primaryText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu langit mihrab: hitung mundur di kiri bawah, satu keterangan waktu
/// di kanan bawah, tanpa teks di bagian lengkung.
class _SkyCard extends StatelessWidget {
  const _SkyCard({
    required this.day,
    required this.next,
    required this.target,
    required this.now,
  });

  final PrayerDay day;
  final String next;
  final DateTime? target;
  final DateTime now;

  /// Posisi matahari 0–1 antara terbit dan terbenam; null di malam hari
  /// atau bila AlAdhan tidak melaporkannya.
  double? _sun() {
    final rise = prayerClock(day, day.sunrise);
    final set = prayerClock(day, day.sunset);
    if (rise == null || set == null || !set.isAfter(rise)) return null;
    if (now.isBefore(rise) || now.isAfter(set)) return null;
    return now.difference(rise).inSeconds / set.difference(rise).inSeconds;
  }

  /// Terbit sebelum matahari muncul, terbenam selama siang.
  String? _info() {
    final rise = prayerClock(day, day.sunrise);
    final set = prayerClock(day, day.sunset);
    if (rise != null && now.isBefore(rise)) return 'Terbit ${day.sunrise}';
    if (set != null && now.isBefore(set)) return 'Terbenam ${day.sunset}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final left = target?.difference(now);
    final counting = left != null && !left.isNegative;
    final info = _info();
    final label = counting
        ? 'Menuju $next, ${prayerCountdown(left)}'
        : 'Salat berikutnya $next';
    // Teks sangat besar: keterangan pindah ke bawah dan hitung mundur tetap
    // satu baris (diperkecil seperlunya, tetap jauh di atas ukuran normal).
    final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6;
    final eyebrow = Text(
      counting ? 'MENUJU ${next.toUpperCase()}' : 'SALAT BERIKUTNYA',
      style: SacredText.eyebrow.copyWith(color: SacredArt.salatEyebrow),
    );
    final countdown = Text(
      counting ? prayerCountdown(left) : next,
      maxLines: 1,
      softWrap: false,
      style: SacredText.countdown.copyWith(color: SacredArt.ink),
    );
    final infoText = info == null
        ? null
        : Text(
            info,
            style: SacredText.surahCount.copyWith(color: SacredArt.salatInfo),
          );
    final content = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              eyebrow,
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: countdown,
              ),
              if (infoText != null) ...[const SizedBox(height: 4), infoText],
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [eyebrow, countdown],
                ),
              ),
              if (infoText != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: infoText,
                ),
              ],
            ],
          );
    return Semantics(
      container: true,
      label: [label, ?info].join('. '),
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: _SkyPainter(sun: _sun()),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 190),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 104, 20, 18),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bentuk mihrab V2-Salat.html (358×190): lengkung atas tetap, bagian bawah
/// ikut memanjang bila teks membesar.
Path _mihrab(Size size, {double inset = 0}) {
  final w = size.width - inset * 2;
  final h = size.height - inset * 2;
  final k = w / 358;
  final corner = 26 * k;
  return (Path()
        ..moveTo(0, h - corner)
        ..lineTo(0, 79.8 * k)
        ..cubicTo(0, 33.5 * k, 107.4 * k, 12.8 * k, w / 2, 0)
        ..cubicTo(w - 107.4 * k, 12.8 * k, w, 33.5 * k, w, 79.8 * k)
        ..lineTo(w, h - corner)
        ..quadraticBezierTo(w, h, w - corner, h)
        ..lineTo(corner, h)
        ..quadraticBezierTo(0, h, 0, h - corner)
        ..close())
      .shift(Offset(inset, inset));
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter({required this.sun});

  final double? sun;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipPath(_mihrab(size));
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: SacredArt.salatSky,
          stops: SacredArt.salatSkyStops,
        ).createShader(Offset.zero & size),
    );
    _pattern(canvas, size);

    final k = size.width / 358;
    final start = Offset(26 * k, 94 * k);
    final control = Offset(size.width / 2, 4 * k);
    final end = Offset(size.width - 26 * k, 94 * k);
    final arc = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = SacredArt.salatArc;
    for (final metric in arc.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 2, metric.length)),
          dash,
        );
      }
    }
    final dot = Paint()..color = SacredArt.salatArcEnd;
    canvas
      ..drawCircle(start, 3, dot)
      ..drawCircle(end, 3, dot);

    final t = sun;
    if (t != null) {
      final u = 1 - t;
      final at = start * (u * u) + control * (2 * u * t) + end * (t * t);
      canvas
        ..drawCircle(
          at,
          30,
          Paint()..color = SacredArt.sunGlow.withValues(alpha: .18),
        )
        ..drawCircle(
          at,
          17,
          Paint()..color = SacredArt.sunGlow.withValues(alpha: .35),
        )
        ..drawCircle(at, 9, Paint()..color = SacredArt.sunCore);
    }

    canvas
      ..drawPath(
        _mihrab(size, inset: 6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = SacredArt.salatOutline,
      )
      ..restore();
  }

  /// Pola bintang delapan tipis (kotak + kotak diputar 45°), petak 40.
  void _pattern(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..color = SacredArt.salatPattern;
    for (var y = 0.0; y < size.height; y += 40) {
      for (var x = 0.0; x < size.width; x += 40) {
        canvas
          ..drawRect(Rect.fromLTWH(x + 8, y + 8, 24, 24), line)
          ..save()
          ..translate(x + 20, y + 20)
          ..rotate(math.pi / 4)
          ..drawRect(
            Rect.fromCenter(center: Offset.zero, width: 24, height: 24),
            line,
          )
          ..restore();
      }
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.sun != sun;
}

/// Daftar waktu salat. Salat berikutnya berlatar hijau muda dan berlabel.
class _PrayerList extends StatelessWidget {
  const _PrayerList({
    required this.day,
    required this.next,
    required this.enabled,
    required this.onToggle,
  });

  final PrayerDay day;
  final String next;
  final Set<String> enabled;
  final void Function(String name, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    const names = PrayerService.prayerNames;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(24),
        boxShadow: tokens.cardShadows,
      ),
      child: Column(
        children: [
          for (var i = 0; i < names.length; i++) ...[
            // Baris yang disorot berdiri sendiri, jadi garis di atas dan di
            // bawahnya dilepas supaya tidak memotong sudut membulatnya.
            if (i > 0 && names[i] != next && names[i - 1] != next)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, thickness: .5, color: tokens.sep),
              ),
            _PrayerRow(
              name: names[i],
              time: day.prayers[names[i]] ?? '—',
              isNext: names[i] == next,
              enabled: enabled.contains(names[i]),
              onToggle: onToggle,
            ),
          ],
        ],
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.name,
    required this.time,
    required this.isNext,
    required this.enabled,
    required this.onToggle,
  });

  final String name;
  final String time;
  final bool isNext;
  final bool enabled;
  final void Function(String name, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final accent = isNext ? tokens.primaryText : tokens.ink;
    // Teks sangat besar: nama di atas jam, supaya nama salat tidak pernah
    // terpotong di kolom 88.
    final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6;
    final nameText = Text(
      name,
      style: (isNext ? SacredText.prayerNameNext : SacredText.prayerName)
          .copyWith(color: accent),
    );
    final timeText = Text(
      time,
      style: SacredText.prayerTime.copyWith(color: accent),
    );
    const pill = StatusPill('berikutnya', tone: PillTone.solid);
    return Semantics(
      container: true,
      label: isNext ? '$name $time, salat berikutnya' : '$name $time',
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        margin: EdgeInsets.symmetric(horizontal: isNext ? 6 : 0),
        padding: EdgeInsets.symmetric(
          horizontal: isNext ? 10 : 16,
          vertical: stacked ? 8 : 0,
        ),
        decoration: isNext
            ? BoxDecoration(
                color: tokens.primarySoft,
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Row(
          children: [
            if (stacked)
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      nameText,
                      timeText,
                      if (isNext) ...[const SizedBox(height: 4), pill],
                    ],
                  ),
                ),
              )
            else ...[
              ExcludeSemantics(child: SizedBox(width: 88, child: nameText)),
              const SizedBox(width: 10),
              ExcludeSemantics(child: timeText),
              const Spacer(),
              if (isNext) ...[
                const ExcludeSemantics(child: pill),
                const SizedBox(width: 10),
              ],
            ],
            const SizedBox(width: 10),
            IosToggle(
              value: enabled,
              semanticsLabel: 'Pengingat $name',
              onChanged: (on) => onToggle(name, on),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lembar Ganti kota: dua isian dan tombol Simpan yang aktif bila keduanya
/// terisi.
class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet({required this.city, required this.country});

  final String city;
  final String country;

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  late final _city = TextEditingController(text: widget.city);
  late final _country = TextEditingController(text: widget.country);

  @override
  void dispose() {
    _city.dispose();
    _country.dispose();
    super.dispose();
  }

  bool get _valid =>
      _city.text.trim().isNotEmpty && _country.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Lokasi jadwal salat',
                style: SacredText.stageTitle.copyWith(color: tokens.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Tulis nama kota dan negara, misalnya Bandung, Indonesia.',
                style: SacredText.cardNote.copyWith(color: tokens.sec),
              ),
              const SizedBox(height: 14),
              _Field(
                label: 'Kota',
                controller: _city,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              _Field(
                label: 'Negara',
                controller: _country,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              SacredButton(
                label: 'Simpan',
                expand: true,
                onTap: _valid
                    ? () => Navigator.pop(context, (
                        _city.text.trim(),
                        _country.text.trim(),
                      ))
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: tokens.fill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.words,
        style: SacredText.searchInput.copyWith(color: tokens.ink),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: SacredText.listMeta.copyWith(color: tokens.sec),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.goldSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: SacredText.infoBox.copyWith(color: tokens.ink)),
            if (action != null) ...[
              const SizedBox(height: 10),
              SacredButton(
                label: action!,
                tone: ButtonTone.soft,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: SacredText.buttonSmall,
                onTap: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
