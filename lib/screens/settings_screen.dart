import 'package:flutter/material.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _arabicFontSize = 24.0;
  double _translationFontSize = 16.0;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _arabicFontSize = SharedPreferencesService.getArabicFontSize();
      _translationFontSize = SharedPreferencesService.getTranslationFontSize();
      _darkMode = SharedPreferencesService.getDarkMode();
    });
  }

  void _saveArabicFontSize(double size) async {
    await SharedPreferencesService.setArabicFontSize(size);
    setState(() {
      _arabicFontSize = size;
    });
  }

  void _saveTranslationFontSize(double size) async {
    await SharedPreferencesService.setTranslationFontSize(size);
    setState(() {
      _translationFontSize = size;
    });
  }

  void _toggleDarkMode(bool value) async {
    await SharedPreferencesService.setDarkMode(value);
    setState(() {
      _darkMode = value;
    });
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Tampilan'),
          _buildFontSizeSetting(),
          _buildDarkModeSetting(),

          _buildSectionHeader('Audio'),
          _buildAudioSettings(),

          _buildSectionHeader('Tentang Aplikasi'),
          _buildAboutSettings(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2E7D32),
        ),
      ),
    );
  }

  Widget _buildFontSizeSetting() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ukuran Font Arab',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _arabicFontSize,
              min: 16.0,
              max: 32.0,
              divisions: 8,
              label: _arabicFontSize.round().toString(),
              onChanged: _saveArabicFontSize,
            ),
            Text(
              'Ukuran Font Terjemahan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _translationFontSize,
              min: 12.0,
              max: 20.0,
              divisions: 8,
              label: _translationFontSize.round().toString(),
              onChanged: _saveTranslationFontSize,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDarkModeSetting() {
    return Card(
      child: SwitchListTile(
        title: const Text('Mode Gelap'),
        subtitle: const Text('Aktifkan tampilan mode gelap'),
        value: _darkMode,
        onChanged: _toggleDarkMode,
      ),
    );
  }

  Widget _buildAudioSettings() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: const Text('Pengaturan Audio'),
            subtitle: const Text('Atur kualitas dan pengaturan audio'),
            onTap: () {
              // Navigate to audio settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Kecepatan Playback'),
            subtitle: const Text('Atur kecepatan pemutaran audio'),
            onTap: () {
              // Navigate to playback speed settings
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSettings() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Tentang Aplikasi'),
            subtitle: const Text('Versi 1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Quran App 2025',
                applicationVersion: '1.0.0',
                applicationIcon: const FlutterLogo(),
                children: [
                  const Text('Aplikasi Quran dengan fitur lengkap dan modern'),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Kebijakan Privasi'),
            onTap: () => _launchURL('https://example.com/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Syarat dan Ketentuan'),
            onTap: () => _launchURL('https://example.com/terms'),
          ),
          ListTile(
            leading: const Icon(Icons.contact_support),
            title: const Text('Bantuan & Dukungan'),
            onTap: () => _launchURL('https://example.com/support'),
          ),
        ],
      ),
    );
  }
}
