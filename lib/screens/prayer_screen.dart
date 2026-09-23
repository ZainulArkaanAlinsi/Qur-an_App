import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/screens/qibla_screen.dart';
import 'package:quran_app_2025/services/prayer_service.dart';
import 'package:quran_app_2025/services/reminder_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Jadwal salat & Hijriah'),
      actions: [
        IconButton(
          tooltip: 'Arah kiblat',
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const QiblaScreen())),
          icon: const Icon(Icons.explore_outlined),
        ),
      ],
    ),
    body: FutureBuilder<PrayerDay>(
      future: _day,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Error(onRetry: () => setState(() => _day = _load()));
        }
        final day = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                day.hijriDate,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kalender Hijriah dari AlAdhan untuk ${SharedPreferencesService.getPrayerCity()}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _changePlace,
                          tooltip: 'Ubah kota',
                          icon: const Icon(Icons.edit_location_alt_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Salat berikutnya: ${day.nextLabel}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Waktu salat',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...PrayerService.prayerNames.map(
              (name) => Card(
                child: SwitchListTile(
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(day.prayers[name]!),
                  value: _enabled.contains(name),
                  onChanged: (enabled) async {
                    setState(() {
                      enabled ? _enabled.add(name) : _enabled.remove(name);
                    });
                    await _saveReminders(day);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.menu_book_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text(
                  'Pengingat tilawah',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  _quranMinutes == null
                      ? 'Belum diaktifkan'
                      : 'Setiap hari pukul ${_format(_quranMinutes!)}',
                ),
                trailing: Wrap(
                  spacing: 2,
                  children: [
                    if (_quranMinutes != null)
                      IconButton(
                        onPressed: () async {
                          setState(() => _quranMinutes = null);
                          await _saveReminders(day);
                        },
                        icon: const Icon(Icons.notifications_off_outlined),
                      ),
                    IconButton(
                      onPressed: () => _chooseQuranTime(day),
                      icon: const Icon(Icons.alarm_add_outlined),
                    ),
                  ],
                ),
              ),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  _message!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                'Alarm salat disiapkan untuk 14 hari ke depan. Buka aplikasi kembali sebelum periode itu berakhir agar jadwal terbaru diperbarui. Ketepatan notifikasi bergantung pada pengaturan baterai perangkat.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        );
      },
    ),
  );

  String _format(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Muat ulang jadwal'),
    ),
  );
}
