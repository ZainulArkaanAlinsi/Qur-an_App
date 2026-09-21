import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/app_controller.dart';
import 'package:quran_app_2025/app/glass_surface.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _arabic;
  late double _translation;
  late int _targetSeconds;

  @override
  void initState() {
    super.initState();
    _arabic = SharedPreferencesService.getArabicFontSize();
    _translation = SharedPreferencesService.getTranslationFontSize();
    _targetSeconds = SharedPreferencesService.getDailyTargetSeconds();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final theme = Theme.of(context);
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        Text(
          'Pengaturan',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Atur ruang baca agar nyaman untukmu.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 26),
        const _SectionTitle('Tampilan'),
        const SizedBox(height: 10),
        GlassSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tema aplikasi',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_rounded),
                    label: Text('Sistem'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Terang'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Gelap'),
                  ),
                ],
                selected: {controller.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    controller.setThemeMode(value.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const _SectionTitle('Pembaca'),
        const SizedBox(height: 10),
        GlassSurface(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ukuran huruf Arab',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: SacredTheme.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${_arabic.round()} px',
                      style: const TextStyle(
                        color: SacredTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
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
              Text(
                'Gunakan mode fokus di Reader untuk pengalaman baca yang lebih hening.',
                style: theme.textTheme.bodySmall,
              ),
              const Divider(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ukuran terjemahan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: SacredTheme.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${_translation.round()} px',
                      style: const TextStyle(
                        color: SacredTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _translation,
                min: 14,
                max: 24,
                divisions: 10,
                onChanged: (value) {
                  setState(() => _translation = value);
                  SharedPreferencesService.setTranslationFontSize(value);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const _SectionTitle('Target harian'),
        const SizedBox(height: 10),
        GlassSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Waktu membaca',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Perubahan target berlaku besok. Riwayat hari sebelumnya tetap tersimpan.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [300, 600, 900, 1800]
                    .map(
                      (seconds) => ChoiceChip(
                        label: Text('${seconds ~/ 60} menit'),
                        selected: _targetSeconds == seconds,
                        onSelected: (_) {
                          setState(() => _targetSeconds = seconds);
                          SharedPreferencesService.setDailyTargetSeconds(
                            seconds,
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const _SectionTitle('Konten & sumber'),
        const SizedBox(height: 10),
        const _SourceCard(
          icon: Icons.verified_outlined,
          title: 'Teks Arab offline',
          body:
              'Tanzil Quran Text, Uthmani v1.0.2 (CC BY 3.0). Disimpan tanpa perubahan.',
          url: 'https://tanzil.net/',
        ),
        const SizedBox(height: 10),
        const _SourceCard(
          icon: Icons.translate_rounded,
          title: 'Terjemahan Indonesia',
          body:
              'Edisi “Bahasa Indonesia” dari Tanzil (pembaruan 4 Juni 2010), penerjemah Kementerian Agama RI. Tersimpan offline tanpa perubahan; untuk penggunaan non-komersial.',
          url: 'https://tanzil.net/trans/',
        ),
        const SizedBox(height: 10),
        const _SourceCard(
          icon: Icons.graphic_eq_rounded,
          title: 'Murottal',
          body:
              'Mishary Rashid Alafasy, per ayat 128 kbps, di-streaming dari CDN Islamic Network (Al Quran Cloud). Hak cipta rekaman milik qari.',
          url: 'https://alquran.cloud/terms-and-conditions',
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.url,
  });
  final IconData icon;
  final String title;
  final String body;
  final String url;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: SacredTheme.gold.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: SacredTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(body),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              semanticLabel: 'Buka sumber',
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );
}
