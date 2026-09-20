import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quran_app_2025/app/sacred_theme.dart';
import 'package:quran_app_2025/services/qibla_service.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<CompassEvent>? _compassSubscription;
  double? _heading;
  double? _bearing;
  double? _accuracy;
  String? _message;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (mounted) setState(() => _heading = event.heading);
    });
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _QiblaException('Nyalakan layanan lokasi, lalu coba lagi.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _QiblaException('Izin lokasi belum diberikan.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _QiblaException(
          'Izin lokasi diblokir. Aktifkan kembali dari Pengaturan perangkat.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _bearing = QiblaService.bearingFrom(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _accuracy = position.accuracy;
      });
    } on _QiblaException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on TimeoutException {
      if (mounted) {
        setState(() => _message = 'Lokasi belum ditemukan. Coba di area terbuka.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Lokasi tidak dapat dibaca. Periksa izin lalu coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = _heading != null && _bearing != null
        ? QiblaService.shortestAngle(_heading!, _bearing!)
        : null;
    final aligned = delta != null && delta <= 5;

    return Scaffold(
      appBar: AppBar(title: const Text('Arah Kiblat')),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              'Arahkan ponsel ke Ka’bah',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Gunakan lokasi presisi dan sensor kompas perangkat. Tidak ada lokasi yang disimpan atau dikirim dari halaman ini.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            Center(child: _QiblaDial(heading: _heading, bearing: _bearing, aligned: aligned)),
            const SizedBox(height: 24),
            Center(
              child: Text(
                _bearing == null
                    ? 'Perbarui lokasi untuk mulai'
                    : aligned
                        ? 'Arah kiblat ditemukan'
                        : 'Putar perangkat hingga penanda berada di atas',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: aligned ? SacredTheme.primary : null,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_bearing != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_bearing!.round()}° dari utara sejati${_accuracy == null ? '' : ' · akurasi lokasi ±${_accuracy!.round()} m'}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _loading ? null : _locate,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded),
              label: Text(_loading ? 'Mencari lokasi…' : 'Gunakan lokasi saya'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              _InfoPanel(icon: Icons.info_outline_rounded, text: _message!, color: theme.colorScheme.error),
            ],
            const SizedBox(height: 18),
            _InfoPanel(
              icon: Icons.explore_outlined,
              text: _heading == null
                  ? 'Sensor kompas tidak tersedia pada perangkat ini. Arah kiblat tetap dihitung setelah lokasi diperbarui.'
                  : 'Untuk hasil terbaik, jauhkan dari magnet atau casing logam dan gerakkan ponsel membentuk angka 8 bila arah belum stabil.',
              color: SacredTheme.primary,
            ),
            const SizedBox(height: 12),
            const _InfoPanel(
              icon: Icons.lock_outline_rounded,
              text: 'Arah dihitung secara lokal ke koordinat Ka’bah (21.422487, 39.826206). Perangkat dan sensor menentukan ketelitian akhir.',
              color: SacredTheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _QiblaDial extends StatelessWidget {
  const _QiblaDial({required this.heading, required this.bearing, required this.aligned});
  final double? heading;
  final double? bearing;
  final bool aligned;

  @override
  Widget build(BuildContext context) {
    final relativeBearing = heading != null && bearing != null ? (bearing! - heading!) * math.pi / 180 : 0.0;
    return Container(
      width: 276,
      height: 276,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Color(0xFF176753), SacredTheme.primaryContainer]),
        border: Border.all(color: SacredTheme.gold.withValues(alpha: .7), width: 2),
        boxShadow: [BoxShadow(color: SacredTheme.primary.withValues(alpha: .22), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(top: 20, child: _Cardinal(label: 'U')),
          const Positioned(bottom: 20, child: _Cardinal(label: 'S')),
          const Positioned(left: 20, child: _Cardinal(label: 'B')),
          const Positioned(right: 20, child: _Cardinal(label: 'T')),
          Container(width: 184, height: 184, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .17)))),
          Transform.rotate(
            angle: relativeBearing,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.navigation_rounded, size: 84, color: bearing == null ? Colors.white.withValues(alpha: .32) : SacredTheme.gold),
                const SizedBox(height: 8),
                Text('KIBLAT', style: TextStyle(color: Colors.white.withValues(alpha: .9), fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 11)),
              ],
            ),
          ),
          if (aligned)
            Positioned(
              bottom: 58,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: SacredTheme.gold, borderRadius: BorderRadius.circular(99)),
                child: const Text('SEARAH', style: TextStyle(color: SacredTheme.primaryContainer, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cardinal extends StatelessWidget {
  const _Cardinal({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .74), fontSize: 12, fontWeight: FontWeight.w800));
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withValues(alpha: .07), borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      );
}

class _QiblaException implements Exception {
  const _QiblaException(this.message);
  final String message;
}
