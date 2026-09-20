import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _arabic;
  late int _targetSeconds;
  @override
  void initState() {
    super.initState();
    _arabic = SharedPreferencesService.getArabicFontSize();
    _targetSeconds = SharedPreferencesService.getDailyTargetSeconds();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Pengaturan',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 22),
        Text(
          'Tampilan',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Card(
          child: RadioGroup<ThemeMode>(
            groupValue: controller.themeMode,
            onChanged: (value) {
              if (value != null) controller.setThemeMode(value);
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: const Text('Ikuti sistem'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: const Text('Mode terang'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: const Text('Mode gelap'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Target membaca',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<int>(
              initialValue: _targetSeconds,
              decoration: const InputDecoration(labelText: 'Target harian'),
              items: const [300, 600, 900, 1800]
                  .map(
                    (seconds) => DropdownMenuItem(
                      value: seconds,
                      child: Text('${seconds ~/ 60} menit'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _targetSeconds = value);
                SharedPreferencesService.setDailyTargetSeconds(value);
              },
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Pembaca',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ukuran huruf Arab · ${_arabic.round()}'),
                Slider(
                  value: _arabic,
                  min: 22,
                  max: 42,
                  divisions: 10,
                  onChanged: (value) {
                    setState(() => _arabic = value);
                    SharedPreferencesService.setArabicFontSize(value);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Tentang konten',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Card(
          child: const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Sumber & atribusi'),
            subtitle: Text(
              'Dataset Qur’an offline beserta lisensi belum dibundel dalam tahap ini.',
            ),
          ),
        ),
      ],
    );
  }
}
