import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:quran_app_2025/core/config.dart';
import 'package:quran_app_2025/models/surah_details.dart';
import 'package:quran_app_2025/widgets/ayah.dart';

// Catatan: Pastikan Ayah dan SurahCard sudah menggunakan desain yang lebih baik

class SurahDetailsScreen extends StatefulWidget {
  final int surahNumber;
  const SurahDetailsScreen({super.key, required this.surahNumber});

  static const String routeName = '/surah_details';

  @override
  State<SurahDetailsScreen> createState() => _SurahDetailsScreenState();
}

class _SurahDetailsScreenState extends State<SurahDetailsScreen> {
  late Future<SurahDetails> data;
  final AudioPlayer player = AudioPlayer();

  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  late StreamSubscription<PlayerState> _playerStateSubscription;
  late StreamSubscription<Duration?> _durationSubscription;
  late StreamSubscription<Duration> _positionSubscription;

  @override
  void initState() {
    super.initState();
    data = _fetchSurah();

    _playerStateSubscription = player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    _durationSubscription = player.durationStream.listen((duration) {
      if (duration != null) {
        setState(() {
          _duration = duration;
        });
        if (player.processingState == ProcessingState.completed) {
          player.seek(Duration.zero);
          player.pause();
        }
      }
    });

    _positionSubscription = player.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
  }

  Future<SurahDetails> _fetchSurah() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseApiUrl}/${widget.surahNumber}.json'),
      );
      if (response.statusCode == 200) {
        return surahDetailsFromJson(response.body);
      } else {
        throw Exception('Failed to load surah details');
      }
    } catch (e) {
      log(e.toString());
      throw Exception('Failed to load surah details');
    }
  }

  Future<void> _toggleAudio(String audioUrl) async {
    try {
      if (_isPlaying) {
        await player.pause();
      } else {
        if (player.processingState == ProcessingState.idle ||
            player.processingState == ProcessingState.completed) {
          await player.setUrl(audioUrl);
        }
        await player.play();
      }
    } catch (e) {
      log('Audio play error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to play audio. Please check your internet connection.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _playerStateSubscription.cancel();
    _durationSubscription.cancel();
    _positionSubscription.cancel();
    player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  final accentColor = Colors.green.shade600;
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = Colors.green.shade600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: FutureBuilder<SurahDetails>(
        future: data,
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (asyncSnapshot.hasError) {
            return Center(child: Text('Error: ${asyncSnapshot.error}'));
          } else if (asyncSnapshot.hasData) {
            final surahData = asyncSnapshot.data!;
            final firstReciterAudio =
                (surahData.audio != null && surahData.audio!.isNotEmpty)
                ? surahData.audio!.values.first
                : null;
            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      data = _fetchSurah();
                    });
                  },
                  child: CustomScrollView(
                    slivers: [
                      _buildSliverAppBar(surahData),
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 150),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Tampilkan Bismillah jika surah bukan Al-Fatihah atau At-Tawbah
                            if (surahData.surahNo != 1 &&
                                surahData.surahNo != 9)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/images/Bismillah.png', // Pastikan aset ini ada
                                    height: 80,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            _buildAyahList(surahData),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),

                /// Audio Player Sticky
                _buildAudioPlayer(theme, accentColor, firstReciterAudio),
              ],
            );
          } else {
            return const Center(child: Text('No data available.'));
          }
        },
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(SurahDetails surahData) {
    return SliverAppBar(
      expandedHeight: 200,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.black,
      elevation: 0,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(bottom: 16),
        title: Text(
          surahData.surahNameTranslation!,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        centerTitle: true,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/quran_bg.jpg', // Ganti dengan gambar latar yang sesuai
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  Text(
                    surahData.surahName!,
                    style: const TextStyle(
                      fontFamily: 'ScheherazadeNew',
                      fontSize: 48,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${surahData.revelationPlace!} | ${surahData.totalAyah!} Ayah',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAyahList(SurahDetails surahData) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: surahData.arabic1!.length,
      itemBuilder: (context, index) {
        return Ayah(
          verseNumber: index + 1,
          verseArabic: surahData.arabic1![index],
          verseEnglish: surahData.english![index],
        );
      },
    );
  }

  Widget _buildAudioPlayer(
    ThemeData theme,
    Color accentColor,
    dynamic firstReciterAudio,
  ) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  firstReciterAudio?.reciter ?? 'No Reciter',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: accentColor,
                inactiveTrackColor: accentColor.withOpacity(0.2),
                thumbColor: accentColor,
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                min: 0,
                max: _duration.inMilliseconds.toDouble(),
                value: _position.inMilliseconds.toDouble(),
                onChanged: (value) async {
                  final position = Duration(milliseconds: value.toInt());
                  await player.seek(position);
                },
              ),
            ),
            IconButton(
              onPressed: firstReciterAudio?.url != null
                  ? () => _toggleAudio(firstReciterAudio!.url!)
                  : null,
              icon: Icon(
                _isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 50,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
