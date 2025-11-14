import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran_app_2025/core/config.dart' as app_config;
import 'package:quran_app_2025/models/surah_details.dart';
import 'package:quran_app_2025/widgets/ayah.dart';

class SurahDetailsScreen extends StatefulWidget {
  final int surahNumber;
  const SurahDetailsScreen({super.key, required this.surahNumber});

  static const String routeName = '/surah_details';

  @override
  State<SurahDetailsScreen> createState() => _SurahDetailsScreenState();
}

class _SurahDetailsScreenState extends State<SurahDetailsScreen> {
  late Future<SurahDetails> _surahFuture;
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  final Color _primaryColor = const Color(0xFF2E7D32);
  final Color _accentColor = const Color(0xFFE8F5E9);

  // Fallback data
  final Map<int, SurahDetails> _fallbackSurahs = {
    1: SurahDetails(
      surahName: "Al-Fatihah",
      surahNameArabic: "الفاتحة",
      surahNameTranslation: "The Opening",
      revelationPlace: "Mecca",
      totalAyah: 7,
      surahNo: 1,
      english: [
        "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
        "[All] praise is [due] to Allah, Lord of the worlds -",
        "The Entirely Merciful, the Especially Merciful,",
        "Sovereign of the Day of Recompense.",
        "It is You we worship and You we ask for help.",
        "Guide us to the straight path -",
        "The path of those upon whom You have bestowed favor, not of those who have evoked [Your] anger or of those who are astray.",
      ],
      arabic: [
        "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
        "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ",
        "الرَّحْمَٰنِ الرَّحِيمِ",
        "مَالِكِ يَوْمِ الدِّينِ",
        "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ",
        "اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ",
        "صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ",
      ],
    ),
  };

  @override
  void initState() {
    super.initState();
    _surahFuture = _fetchSurah();
    _initializeAudioPlayer();
  }

  Future<SurahDetails> _fetchSurah() async {
    for (final endpoint in app_config.Config.apiEndpoints) {
      try {
        final response = await http
            .get(Uri.parse('$endpoint/surah/${widget.surahNumber}'))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          return surahDetailsFromJson(response.body);
        }
      } catch (e) {
        print('Failed to fetch from $endpoint: $e');
        continue;
      }
    }

    // Fallback to local data
    return _fallbackSurahs[widget.surahNumber] ?? _fallbackSurahs[1]!;
  }

  void _initializeAudioPlayer() {
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isLoadingAudio = state.processingState == ProcessingState.loading;
        });
      }
    });

    _durationSubscription = _player.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration ?? Duration.zero);
      }
    });

    _positionSubscription = _player.positionStream.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });
  }

  Future<void> _toggleAudio() async {
    if (_isLoadingAudio) return;

    setState(() {
      _isLoadingAudio = true;
    });

    try {
      if (_isPlaying) {
        await _player.pause();
        setState(() {
          _isPlaying = false;
          _isLoadingAudio = false;
        });
      } else {
        if (_position >= _duration) {
          await _player.seek(Duration.zero);
        }

        // Use sample audio
        final audioUrl =
            'https://cdn.islamic.network/quran/audio/128/ar.alafasy/${widget.surahNumber}.mp3';
        await _player.setUrl(audioUrl);
        await _player.setSpeed(_playbackSpeed);
        await _player.play();

        setState(() {
          _isPlaying = true;
          _isLoadingAudio = false;
        });
      }
    } catch (e) {
      print('Audio error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memutar audio'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoadingAudio = false;
        });
      }
    }
  }

  Future<void> _changePlaybackSpeed() async {
    final newSpeed = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Playback Speed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSpeedOption(0.5, '0.5x'),
            _buildSpeedOption(0.75, '0.75x'),
            _buildSpeedOption(1.0, '1.0x'),
            _buildSpeedOption(1.25, '1.25x'),
            _buildSpeedOption(1.5, '1.5x'),
            _buildSpeedOption(2.0, '2.0x'),
          ],
        ),
      ),
    );

    if (newSpeed != null) {
      setState(() {
        _playbackSpeed = newSpeed;
      });
      await _player.setSpeed(newSpeed);
    }
  }

  Widget _buildSpeedOption(double speed, String label) {
    return ListTile(
      title: Text(label),
      trailing: _playbackSpeed == speed ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(speed),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Widget _buildBismillah() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _accentColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primaryColor.withOpacity(0.3)),
          ),
          child: Text(
            '﷽',
            style: GoogleFonts.amiri(
              fontSize: 32,
              color: _primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Di method _buildAyahList, ganti menjadi:
  Widget _buildAyahList(SurahDetails surahData) {
    final verseCount = surahData.arabic?.length ?? 0;

    if (verseCount == 0) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'Data ayat tidak tersedia',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Ayah(
            verseNumber: index + 1,
            verseArabic: surahData.arabic![index],
            verseEnglish: surahData.english![index],
            surahNumber: widget.surahNumber, // Tambahkan ini
          ),
        ),
        childCount: verseCount,
      ),
    );
  }

  Widget _buildHeader(SurahDetails surahData) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      expandedHeight: 280.0,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryColor, const Color(0xFF1B5E20)],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: Container(color: Colors.black.withOpacity(0.2)),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 48.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Surah ${surahData.surahNo}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      surahData.surahNameTranslation ?? 'Unknown',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${surahData.revelationPlace ?? 'Unknown'} • ${surahData.totalAyah ?? 0} Ayah',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      surahData.surahNameArabic ?? '...',
                      style: GoogleFonts.amiri(
                        fontSize: 42,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
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

  Widget _buildProgressSlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: _primaryColor,
        inactiveTrackColor: Colors.grey[300],
        thumbColor: _primaryColor,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayColor: _primaryColor.withOpacity(0.2),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      child: Slider(
        min: 0,
        max: _duration.inMilliseconds.toDouble(),
        value: _position.inMilliseconds.toDouble().clamp(
          0,
          _duration.inMilliseconds.toDouble(),
        ),
        onChanged: (value) async {
          await _player.seek(Duration(milliseconds: value.toInt()));
        },
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reciter Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.mic, color: _primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mishary Alafasy',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _changePlaybackSpeed,
                    icon: Text(
                      '${_playbackSpeed}x',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    tooltip: 'Change Speed',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Progress
            Row(
              children: [
                Text(
                  _formatDuration(_position),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDuration(_duration),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildProgressSlider(),
            const SizedBox(height: 16),

            // Play Button
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, const Color(0xFF1B5E20)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    onPressed: _toggleAudio,
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  if (_isLoadingAudio)
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahContent(SurahDetails surahData) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            final newData = await _fetchSurah();
            setState(() {
              _surahFuture = Future.value(newData);
            });
          },
          color: _primaryColor,
          child: CustomScrollView(
            slivers: [
              _buildHeader(surahData),
              if (surahData.surahNo != 1 && surahData.surahNo != 9)
                SliverToBoxAdapter(child: _buildBismillah()),
              _buildAyahList(surahData),
              const SliverPadding(padding: EdgeInsets.only(bottom: 180)),
            ],
          ),
        ),
        _buildAudioPlayer(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<SurahDetails>(
        future: _surahFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}\nMenggunakan data offline',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _surahFuture = _fetchSurah();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Coba Lagi', style: GoogleFonts.poppins()),
                    ),
                  ],
                ),
              ),
            );
          } else if (snapshot.hasData) {
            return _buildSurahContent(snapshot.data!);
          } else {
            return const Center(child: Text('Tidak ada data yang tersedia.'));
          }
        },
      ),
    );
  }
}
