import 'package:flutter/material.dart';
import 'package:quran_app_2025/app/sacred_tokens.dart';
import 'package:quran_app_2025/app/widgets/sacred_icons.dart';
import 'package:quran_app_2025/app/widgets/svg_path.dart';
import 'package:quran_app_2025/data/sura_names_repository.dart';
import 'package:quran_app_2025/data/surah_catalog.dart';
import 'package:quran_app_2025/models/surah_meta.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

/// Plakat mihrab pada Murottal.html (270×330), verbatim.
const _platePath =
    'M0 302 L0 128.0 C0 53.8 81.0 20.5 135.0 0 C189.0 20.5 270 53.8 270 128.0 '
    'L270 302 Q270 330 242 330 L28 330 Q0 330 0 302 Z';

/// Garis emas di dalamnya, digeser 10 px seperti di mockup.
const _plateInnerPath =
    'M0 290 L0 120.0 C0 50.4 75.0 19.2 125.0 0 C175.0 19.2 250 50.4 250 120.0 '
    'L250 290 Q250 310 230 310 L20 310 Q0 310 0 290 Z';

/// Layar murottal penuh, dibuka dari pemutar kecil.
class MurottalScreen extends StatefulWidget {
  const MurottalScreen({super.key});

  @override
  State<MurottalScreen> createState() => _MurottalScreenState();
}

class _MurottalScreenState extends State<MurottalScreen> {
  late Future<List<String>> _arabicNames = SuraNamesRepository.load();

  static String _clock(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _chooseSleepTimer() async {
    final audio = QuranAudioService.instance;
    final picked = await showModalBottomSheet<Duration>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final minutes in const [10, 20, 30, 60])
              ListTile(
                title: Text('Berhenti setelah $minutes menit'),
                onTap: () => Navigator.pop(context, Duration(minutes: minutes)),
              ),
            ListTile(
              title: const Text('Matikan timer'),
              onTap: () => Navigator.pop(context, Duration.zero),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    audio.setSleepTimer(picked == Duration.zero ? null : picked);
  }

  Future<void> _cycleSpeed() async {
    final audio = QuranAudioService.instance;
    const steps = [1.0, 1.25, 1.5, 0.75];
    final current = audio.speed.value;
    final index = steps.indexWhere((step) => (step - current).abs() < .01);
    await audio.setSpeed(steps[(index + 1) % steps.length]);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final audio = QuranAudioService.instance;
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            audio.queue,
            audio.playingVerse,
            audio.isPlaying,
            audio.buffering,
            audio.repeat,
            audio.speed,
            audio.sleepAt,
          ]),
          builder: (context, _) {
            final queue = audio.queue.value;
            final key = audio.playingVerse.value;
            if (queue == null || key == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'Murottal sedang tidak diputar.',
                    textAlign: TextAlign.center,
                    style: SacredText.body.copyWith(color: tokens.sec),
                  ),
                ),
              );
            }
            final surah = surahCatalog[queue.surah - 1];
            final ayah = int.parse(key.split(':').last);
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                _TopBar(onClose: () => Navigator.of(context).pop()),
                const SizedBox(height: 26),
                Center(
                  child: _Plate(
                    names: _arabicNames,
                    surah: surah,
                    onRetry: () => setState(
                      () => _arabicNames = SuraNamesRepository.load(),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                _TrackLine(surah: surah, ayah: ayah),
                const SizedBox(height: 18),
                // Mockup menggambar bentuk gelombang; di sini yang ditampilkan
                // kemajuan sungguhan dari pemutar, bukan gelombang karangan.
                StreamBuilder<Duration>(
                  stream: audio.positionStream,
                  builder: (context, positionSnapshot) =>
                      StreamBuilder<Duration?>(
                        stream: audio.durationStream,
                        builder: (context, durationSnapshot) {
                          final position =
                              positionSnapshot.data ?? Duration.zero;
                          final total = durationSnapshot.data;
                          final left = total == null ? null : total - position;
                          return Column(
                            children: [
                              _Progress(
                                value:
                                    total == null || total.inMilliseconds == 0
                                    ? 0
                                    : (position.inMilliseconds /
                                              total.inMilliseconds)
                                          .clamp(0.0, 1.0),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _clock(position),
                                    style: SacredText.legend.copyWith(
                                      color: tokens.sec,
                                    ),
                                  ),
                                  Text(
                                    left == null ? '—' : '−${_clock(left)}',
                                    style: SacredText.legend.copyWith(
                                      color: tokens.sec,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                ),
                const SizedBox(height: 12),
                _Transport(onSpeed: _cycleSpeed, speed: audio.speed.value),
                const SizedBox(height: 18),
                _Chips(onTimer: _chooseSleepTimer),
                const SizedBox(height: 12),
                Text(
                  'Waktu mendengar belum dicatat terpisah dari streak membaca.',
                  textAlign: TextAlign.center,
                  style: SacredText.cardNote.copyWith(color: tokens.sec),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Row(
      children: [
        _SoftCircle(
          size: 40,
          semanticsLabel: 'Tutup',
          onTap: onClose,
          child: LineIcon(
            SacredIcons.chevronDown,
            color: tokens.ink,
            size: 22,
            strokeWidth: 2.2,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'MUROTTAL',
                style: SacredText.eyebrow.copyWith(color: tokens.sec),
              ),
              Text(
                'Per ayat · ${QuranAudioService.reciterName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SacredText.stripTitle.copyWith(color: tokens.ink),
              ),
            ],
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }
}

/// Plakat mihrab berisi nama surah dalam aksara Arab.
class _Plate extends StatelessWidget {
  const _Plate({
    required this.names,
    required this.surah,
    required this.onRetry,
  });

  final Future<List<String>> names;
  final SurahMeta surah;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return SizedBox(
      width: 270,
      height: 330,
      child: ClipPath(
        clipper: const _PathClipper(_platePath, Size(270, 330)),
        child: Container(
          color: tokens.art,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _PlateOutline()),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 108, 16, 16),
                child: Column(
                  children: [
                    FutureBuilder<List<String>>(
                      future: names,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return TextButton(
                            onPressed: onRetry,
                            child: const Text('Muat ulang nama surah'),
                          );
                        }
                        final arabic = snapshot.data == null
                            ? ''
                            : snapshot.data![surah.number - 1];
                        return Text(
                          arabic,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: SacredText.quran,
                            fontSize: 56,
                            height: 90 / 56,
                            color: tokens.gold,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'SURAH KE-${surah.number} · '
                      '${surah.revelation.toUpperCase()}',
                      textAlign: TextAlign.center,
                      style: SacredText.eyebrow.copyWith(color: tokens.artInk),
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

/// Judul lagu: nama surah, nomor ayat, lalu nama qari.
class _TrackLine extends StatelessWidget {
  const _TrackLine({required this.surah, required this.ayah});

  final SurahMeta surah;
  final int ayah;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${surah.displayName} '),
              TextSpan(
                text: '· $ayah',
                style: SacredText.cardTitle.copyWith(
                  color: tokens.goldText,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SacredText.cardTitle.copyWith(color: tokens.ink),
        ),
        const SizedBox(height: 2),
        Text(
          QuranAudioService.reciterName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SacredText.chipLabel.copyWith(color: tokens.sec),
        ),
      ],
    );
  }
}

/// Bar kemajuan tipis menggantikan bentuk gelombang mockup.
class _Progress extends StatelessWidget {
  const _Progress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 4,
        backgroundColor: tokens.surf2,
        valueColor: AlwaysStoppedAnimation<Color>(tokens.gold),
      ),
    );
  }
}

/// Deretan tombol putar, sesuai ukuran pada mockup.
class _Transport extends StatelessWidget {
  const _Transport({required this.onSpeed, required this.speed});

  final VoidCallback onSpeed;
  final double speed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final audio = QuranAudioService.instance;
    final playing = audio.isPlaying.value;
    final repeat = audio.repeat.value;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SoftCircle(
          size: 44,
          background: tokens.goldSoft,
          // Labelnya menyebut apa yang akan terjadi, bukan keadaan sekarang.
          // Hanya dua keadaan yang bisa dipindah dari sini: mengulang rentang
          // butuh ayat awal dan akhir, jadi itu dipilih dari layar latihan.
          semanticsLabel: repeat == AudioRepeat.verse
              ? 'Putar berurutan'
              : 'Ulangi ayat ini',
          onTap: () => audio.setRepeat(
            repeat == AudioRepeat.verse ? AudioRepeat.off : AudioRepeat.verse,
          ),
          child: LineIcon(
            SacredIcons.repeat,
            color: repeat == AudioRepeat.off ? tokens.sec : tokens.goldText,
            size: 20,
            strokeWidth: 2,
          ),
        ),
        _SoftCircle(
          size: 56,
          background: const Color(0x00000000),
          semanticsLabel: 'Ayat sebelumnya',
          onTap: audio.previous,
          child: LineIcon(
            SacredIcons.previous,
            color: tokens.ink,
            size: 28,
            filled: true,
          ),
        ),
        _SoftCircle(
          size: 76,
          background: tokens.cta,
          semanticsLabel: playing ? 'Jeda' : 'Putar',
          onTap: audio.togglePlayPause,
          child: audio.buffering.value
              ? SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: tokens.ctaInk,
                  ),
                )
              : LineIcon(
                  playing ? SacredIcons.pause : SacredIcons.play,
                  color: tokens.ctaInk,
                  size: 28,
                  filled: true,
                ),
        ),
        _SoftCircle(
          size: 56,
          background: const Color(0x00000000),
          semanticsLabel: 'Ayat berikutnya',
          onTap: audio.next,
          child: LineIcon(
            SacredIcons.next,
            color: tokens.ink,
            size: 28,
            filled: true,
          ),
        ),
        _SoftCircle(
          size: 44,
          semanticsLabel: 'Kecepatan putar',
          onTap: onSpeed,
          child: Text(
            '${speed == speed.roundToDouble() ? speed.toStringAsFixed(0) : speed.toStringAsFixed(2)}×',
            style: SacredText.chip.copyWith(color: tokens.ink),
          ),
        ),
      ],
    );
  }
}

/// Pil di bawah tombol putar.
class _Chips extends StatelessWidget {
  const _Chips({required this.onTimer});

  final VoidCallback onTimer;

  @override
  Widget build(BuildContext context) {
    final sleepAt = QuranAudioService.instance.sleepAt.value;
    return Row(
      children: [
        Expanded(
          child: _Chip(
            icon: SacredIcons.timer,
            label: sleepAt == null
                ? 'Timer'
                : 'Berhenti ${sleepAt.hour.toString().padLeft(2, '0')}:'
                      '${sleepAt.minute.toString().padLeft(2, '0')}',
            onTap: onTimer,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: _Chip(
            icon: SacredIcons.download,
            label: 'Unduh',
            // Aturan desainnya: tombol tanpa fungsi dinonaktifkan beserta
            // alasannya. Unduhan murottal dilakukan dari daftar surah.
            reason: 'Unduhan murottal dilakukan dari daftar surah.',
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    this.onTap,
    this.reason,
  });

  final List<String> icon;
  final String label;
  final VoidCallback? onTap;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    final enabled = onTap != null;
    final content = Container(
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? tokens.surf : const Color(0x00000000),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.sep),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LineIcon(
            icon,
            color: enabled ? tokens.goldText : tokens.sec,
            size: 15,
            strokeWidth: 2,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SacredText.chipLabel.copyWith(
                color: enabled ? tokens.ink : tokens.sec,
              ),
            ),
          ),
        ],
      ),
    );
    if (!enabled) {
      return Tooltip(
        message: reason ?? '',
        child: Semantics(
          container: true,
          excludeSemantics: true,
          enabled: false,
          label: '$label. ${reason ?? ''}',
          child: content,
        ),
      );
    }
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Tombol bulat; yang kecil tetap mendapat target sentuh 44 px.
class _SoftCircle extends StatelessWidget {
  const _SoftCircle({
    required this.size,
    required this.child,
    required this.semanticsLabel,
    required this.onTap,
    this.background,
  });

  final double size;
  final Widget child;
  final String semanticsLabel;
  final VoidCallback onTap;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SacredTokens>()!;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: semanticsLabel,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: size < 44 ? 44 : size,
          child: Center(
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background ?? tokens.fill,
                shape: BoxShape.circle,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Memotong kotak mengikuti jalur SVG mockup.
class _PathClipper extends CustomClipper<Path> {
  const _PathClipper(this.d, this.design);

  final String d;
  final Size design;

  @override
  Path getClip(Size size) => parseSvgPath(d).transform(
    Matrix4.diagonal3Values(
      size.width / design.width,
      size.height / design.height,
      1,
    ).storage,
  );

  @override
  bool shouldReclip(_PathClipper old) => old.d != d || old.design != design;
}

class _PlateOutline extends CustomPainter {
  const _PlateOutline();

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 270;
    final scaleY = size.height / 330;
    final matrix = Matrix4.identity()
      ..translateByDouble(10 * scaleX, 10 * scaleY, 0, 1)
      ..scaleByDouble(scaleX, scaleY, 1, 1);
    canvas.drawPath(
      parseSvgPath(_plateInnerPath).transform(matrix.storage),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xCCFED65B),
    );
  }

  @override
  bool shouldRepaint(_PlateOutline old) => false;
}
