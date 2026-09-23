import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_controls.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/screens/qibla_screen.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/reminder_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Warna kartu "salat berikutnya" (Salat.html). Warnanya tetap dan tidak
/// mengklaim apa pun tentang langit sungguhan.
const _skyStops = [
  Color(0xFF0B3F48),
  Color(0xFF2E7078),
  Color(0xFFB7A383),
  Color(0xFFF2C98A),
];
const _skyPositions = [0.0, .44, .76, 1.0];

/// Jalur mihrab kartu hero, disalin apa adanya dari mockup (358×196).
const _mihrabPath =
    'M0 170 L0 82.3 C0 34.6 107.4 13.2 179.0 0 C250.6 13.2 358 34.6 358 82.3 '
    'L358 170 Q358 196 332 196 L26 196 Q0 196 0 170 Z';

/// Garis tipis di dalamnya, juga verbatim.
const _mihrabInnerPath =
    'M0 164 L0 77.3 C0 32.5 103.8 12.4 173.0 0 C242.2 12.4 346 32.5 346 77.3 '
    'L346 164 Q346 184 326 184 L20 184 Q0 184 0 164 Z';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  late Future<PrayerDay> _day;
  late Set<String> _enabled;
  int? _quranMinutes;
  String? _message;

  @override
  void initState() {
    super.initState();
    _enabled = SharedPreferencesService.getPrayerReminders();
    _quranMinutes = SharedPreferencesService.getQuranReminderMinutes();
    _day = _load();
  }

  Future<PrayerDay> _load() => PrayerService.fetch(
    city: SharedPreferencesService.getPrayerCity(),
    country: SharedPreferencesService.getPrayerCountry(),
  );

  Future<void> _saveReminders(PrayerDay day) async {
    final allowed = await ReminderService.instance.requestPermission();
    if (!allowed) {
      if (mounted) {
        setState(() => _message = 'Izin notifikasi belum diberikan.');
      }
      return;
    }
    await SharedPreferencesService.setPrayerReminders(_enabled);
    await SharedPreferencesService.setQuranReminderMinutes(_quranMinutes);
    await ReminderService.instance.schedule(
      day: day,
      prayerNames: _enabled,
      quranReminderMinutes: _quranMinutes,
      city: SharedPreferencesService.getPrayerCity(),
      country: SharedPreferencesService.getPrayerCountry(),
    );
    if (mounted) {
      setState(
        () => _message =
            'Pengingat salat untuk 14 hari dan tilawah harian telah diperbarui.',
      );
    }
  }

  Future<void> _changePlace() async {
    final city = TextEditingController(
      text: SharedPreferencesService.getPrayerCity(),
    );
    final country = TextEditingController(
      text: SharedPreferencesService.getPrayerCountry(),
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lokasi jadwal salat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: city,
              decoration: const InputDecoration(labelText: 'Kota'),
            ),
            TextField(
              controller: country,
              decoration: const InputDecoration(labelText: 'Negara'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != true ||
        city.text.trim().isEmpty ||
        country.text.trim().isEmpty) {
      return;
    }
    await SharedPreferencesService.setPrayerPlace(city.text, country.text);
    if (mounted) {
      setState(() {
        _message = null;
        _day = _load();
      });
    }
  }

  Future<void> _chooseQuranTime(PrayerDay day) async {
    final initial = TimeOfDay(
      hour: (_quranMinutes ?? 1200) ~/ 60,
      minute: (_quranMinutes ?? 1200) % 60,
    );
    final time = await showTimePicker(context: context, initialTime: initial);
    if (time == null) return;
    setState(() => _quranMinutes = time.hour * 60 + time.minute);
    await _saveReminders(day);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<PrayerDay>(
          future: _day,
          builder: (context, snapshot) {
            final header = <Widget>[
              _BackBar(label: 'Beranda', onTap: () => Navigator.pop(context)),
              LargeTitle(
                'Salat',
                trailing: _QiblaPill(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const QiblaScreen(),
                    ),
                  ),
                ),
              ),
            ];

            if (snapshot.connectionState != ConnectionState.done) {
              return ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  ...header,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      'Memuat jadwal salat…',
                      style: SacredText.cardNote.copyWith(color: tokens.sec),
                    ),
                  ),
                ],
              );
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  ...header,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jadwal salat belum bisa dimuat. Periksa koneksi, '
                          'lalu coba lagi.',
                          style: SacredText.cardNote.copyWith(
                            color: tokens.sec,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => setState(() => _day = _load()),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Muat ulang jadwal'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final day = snapshot.data!;
            final next = day.nextLabel;
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                ...header,
                _PlaceRow(
                  city: SharedPreferencesService.getPrayerCity(),
                  country: SharedPreferencesService.getPrayerCountry(),
                  onChange: _changePlace,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                  child: Text(
                    // Cara jadwal ini dihitung, bukan angka yang muncul entah
                    // dari mana. Zona waktu diambil dari respons AlAdhan.
                    'Metode ${PrayerService.methodName} '
                    '(AlAdhan #${PrayerService.methodId}) · '
                    '${day.timezone ?? 'zona waktu tidak dilaporkan'}',
                    style: SacredText.cardNote.copyWith(color: tokens.sec),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _NextPrayerCard(day: day, next: next),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _PrayerList(
                    day: day,
                    next: next,
                    enabled: _enabled,
                    onToggle: (name, on) async {
                      setState(() {
                        on ? _enabled.add(name) : _enabled.remove(name);
                      });
                      await _saveReminders(day);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: InsetGroupedList(
                    radius: 22,
                    children: [
                      SettingsRow(
                        icon: SacredIcons.bell,
                        chipColor: const Color(0xFFB0533A),
                        title: 'Pengingat tilawah',
                        value: _quranMinutes == null
                            ? 'Nonaktif'
                            : _format(_quranMinutes!),
                        subtitle: _quranMinutes == null
                            ? 'Belum diaktifkan'
                            : 'Setiap hari pada jam itu',
                        trailing: _quranMinutes == null
                            ? null
                            : IconButton(
                                tooltip: 'Matikan pengingat tilawah',
                                onPressed: () async {
                                  setState(() => _quranMinutes = null);
                                  await _saveReminders(day);
                                },
                                icon: const Icon(
                                  Icons.notifications_off_outlined,
                                ),
                              ),
                        onTap: () => _chooseQuranTime(day),
                      ),
                    ],
                  ),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                    child: Text(
                      _message!,
                      style: SacredText.cardNote.copyWith(
                        color: tokens.primaryText,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Text(
                    'Alarm salat disiapkan untuk 14 hari ke depan. Buka '
                    'aplikasi kembali sebelum periode itu berakhir agar '
                    'jadwalnya diperbarui. Ketepatan notifikasi bergantung '
                    'pada pengaturan baterai perangkat.',
                    style: SacredText.cardNote.copyWith(color: tokens.sec),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _format(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';
}

/// Tautan kembali gaya iOS: chevron lalu nama layar asal.
class _BackBar extends StatelessWidget {
  const _BackBar({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        container: true,
        excludeSemantics: true,
        label: 'Kembali ke $label',
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LineIcon(
                  SacredIcons.chevronLeft,
                  color: tokens.primaryText,
                  size: 26,
                  strokeWidth: 2.2,
                ),
                Text(
                  label,
                  style: SacredText.backLabel.copyWith(
                    color: tokens.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pil arah kiblat di kanan judul.
class _QiblaPill extends StatelessWidget {
  const _QiblaPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: 'Arah kiblat',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
          decoration: BoxDecoration(
            color: tokens.surf,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.sep),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LineIcon(
                SacredIcons.pin,
                color: tokens.goldText,
                size: 18,
                strokeWidth: 2,
              ),
              const SizedBox(width: 6),
              Text(
                'Kiblat',
                style: SacredText.chip.copyWith(color: tokens.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris lokasi beserta tautan ganti kota.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.city,
    required this.country,
    required this.onChange,
  });

  final String city;
  final String country;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          LineIcon(
            SacredIcons.pin,
            color: tokens.sec,
            size: 15,
            strokeWidth: 2,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$city, $country',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SacredText.chip.copyWith(color: tokens.sec),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            button: true,
            container: true,
            excludeSemantics: true,
            label: 'Ganti kota',
            child: InkWell(
              onTap: onChange,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Ganti kota',
                  style: SacredText.linkLabel.copyWith(
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

/// Kartu salat berikutnya: mihrab bergradasi, hitung mundur, terbit/terbenam.
class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard({required this.day, required this.next});

  final PrayerDay day;
  final String next;

  /// Sisa waktu menuju [next]; null bila waktunya tidak bisa dihitung
  /// (misalnya salat berikutnya sudah jatuh di hari esok).
  Duration? _remaining() {
    final at = day.timeFor(next);
    if (at == null) return null;
    final left = at.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  static String _countdown(Duration left) {
    final hours = left.inHours;
    final minutes = left.inMinutes % 60;
    return hours == 0 ? '$minutes m' : '$hours j $minutes m';
  }

  @override
  Widget build(BuildContext context) {
    final left = _remaining();
    return AspectRatio(
      aspectRatio: 358 / 196,
      child: ClipPath(
        clipper: const _MihrabClipper(),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _skyStops,
              stops: _skyPositions,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _MihrabOutline()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MENUJU ${next.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SacredText.eyebrow.copyWith(
                              color: const Color(0xFFF6E3B4),
                            ),
                          ),
                          Text(
                            left == null ? next : _countdown(left),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SacredText.countdown.copyWith(
                              color: const Color(0xFFFFFFFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Terbit dan terbenam hanya tampil kalau AlAdhan
                    // benar-benar melaporkannya.
                    if (day.sunrise != null || day.sunset != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (day.sunrise != null)
                            Text(
                              'Terbit ${day.sunrise}',
                              style: SacredText.heroAction.copyWith(
                                color: const Color(0xE6FFFFFF),
                              ),
                            ),
                          if (day.sunset != null)
                            Text(
                              'Terbenam ${day.sunset}',
                              style: SacredText.heroAction.copyWith(
                                color: const Color(0xE6FFFFFF),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Memotong kotak mengikuti jalur mihrab mockup, diskalakan ke lebar layar.
class _MihrabClipper extends CustomClipper<Path> {
  const _MihrabClipper();

  @override
  Path getClip(Size size) => parseSvgPath(_mihrabPath).transform(
    Matrix4.diagonal3Values(size.width / 358, size.height / 196, 1).storage,
  );

  @override
  bool shouldReclip(_MihrabClipper old) => false;
}

/// Garis tipis di dalam mihrab plus busur lintasan matahari.
class _MihrabOutline extends CustomPainter {
  const _MihrabOutline();

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 358;
    final scaleY = size.height / 196;
    final matrix = Matrix4.identity()
      ..translateByDouble(6 * scaleX, 6 * scaleY, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1);
    canvas.drawPath(
      parseSvgPath(_mihrabInnerPath).transform(matrix.storage),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x8CFFECC4),
    );

    final arc = Path()
      ..moveTo(26 * scaleX, 100 * scaleY)
      ..quadraticBezierTo(179 * scaleX, -scaleY, 332 * scaleX, 100 * scaleY);
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x73FFFFFF);
    for (final metric in arc.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 2, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), dash);
        distance += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_MihrabOutline old) => false;
}

/// Daftar waktu salat. Baris salat berikutnya diberi latar hijau muda.
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
    final names = PrayerService.prayerNames;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.sep),
      ),
      child: Column(
        children: [
          for (var i = 0; i < names.length; i++) ...[
            // Baris yang disorot berdiri sendiri, jadi garis di atas dan di
            // bawahnya dilepas supaya tidak memotong sudut membulatnya.
            if (i > 0 && names[i] != next && names[i - 1] != next)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, thickness: 1, color: tokens.sep),
              ),
            _PrayerRow(
              name: names[i],
              time: day.prayers[names[i]]!,
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
    return Semantics(
      container: true,
      label: isNext ? '$name $time, salat berikutnya' : '$name $time',
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: isNext ? 6 : 0),
        padding: EdgeInsets.symmetric(horizontal: isNext ? 10 : 16),
        decoration: isNext
            ? BoxDecoration(
                color: tokens.primarySoft,
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: ExcludeSemantics(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (isNext
                              ? SacredText.prayerNameNext
                              : SacredText.prayerName)
                          .copyWith(color: accent),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SacredText.prayerTime.copyWith(color: accent),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IosToggle(
              value: enabled,
              semanticsLabel: 'Adzan $name',
              onChanged: (on) => onToggle(name, on),
            ),
          ],
        ),
      ),
    );
  }
}
