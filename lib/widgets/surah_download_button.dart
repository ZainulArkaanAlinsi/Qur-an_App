import 'package:flutter/material.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/services/audio_download_service.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';

/// Tombol unduh murottal satu surah untuk qari yang sedang dipilih.
/// Menampilkan kemajuan, dapat dibatalkan, dan menawarkan hapus bila sudah
/// tersedia offline.
class SurahDownloadButton extends StatefulWidget {
  const SurahDownloadButton({super.key, required this.surah, this.service});

  final int surah;

  /// Diisi pada tes; produksi memakai layanan bawaan.
  final AudioDownloadService? service;

  @override
  State<SurahDownloadButton> createState() => _SurahDownloadButtonState();
}

class _SurahDownloadButtonState extends State<SurahDownloadButton> {
  late final AudioDownloadService _service =
      widget.service ?? AudioDownloadService();
  late Reciter _reciter = SharedPreferencesService.getReciter();
  DownloadProgress? _progress;
  bool _downloaded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final reciter = SharedPreferencesService.getReciter();
    final complete = await _service.isComplete(reciter, widget.surah);
    if (!mounted) return;
    setState(() {
      _reciter = reciter;
      _downloaded = complete;
    });
  }

  Future<void> _download() async {
    setState(() => _progress = const DownloadProgress(done: 0, total: 1));
    final ok = await _service.download(
      _reciter,
      widget.surah,
      onProgress: (value) {
        if (mounted) setState(() => _progress = value);
      },
    );
    if (!mounted) return;
    setState(() => _progress = null);
    await _refresh();
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unduhan murottal belum lengkap. Coba lagi nanti.'),
      ),
    );
  }

  Future<void> _delete() async {
    await _service.delete(_reciter, widget.surah);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    if (progress != null) {
      return IconButton(
        tooltip:
            'Batalkan unduhan (${(progress.fraction * 100).round()}%)',
        onPressed: () => _service.cancel(_reciter, widget.surah),
        icon: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: progress.fraction == 0 ? null : progress.fraction,
              ),
            ),
            const Icon(Icons.close_rounded, size: 12),
          ],
        ),
      );
    }
    return IconButton(
      tooltip: _downloaded
          ? 'Hapus murottal offline surah ini'
          : 'Unduh murottal surah ini (${_reciter.displayName})',
      onPressed: _downloaded ? _delete : _download,
      icon: Icon(
        _downloaded
            ? Icons.offline_pin_rounded
            : Icons.download_for_offline_outlined,
      ),
    );
  }
}
