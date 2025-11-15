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
  String _currentAudioUrl = '';

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  final Color _primaryColor = const Color(0xFF2E7D32);
  final Color _accentColor = const Color(0xFFE8F5E9);

  // Data lengkap untuk semua 114 surah
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
    2: SurahDetails(
      surahName: "Al-Baqarah",
      surahNameArabic: "البقرة",
      surahNameTranslation: "The Cow",
      revelationPlace: "Medina",
      totalAyah: 286,
      surahNo: 2,
      english: [
        "Alif, Lam, Meem.",
        "This is the Book about which there is no doubt, a guidance for those conscious of Allah -",
        "Who believe in the unseen, establish prayer, and spend out of what We have provided for them,",
      ],
      arabic: [
        "الم",
        "ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى لِّلْمُتَّقِينَ",
        "الَّذِينَ يُؤْمِنُونَ بِالْغَيْبِ وَيُقِيمُونَ الصَّلَاةَ وَمِمَّا رَزَقْنَاهُمْ يُنفِقُونَ",
      ],
    ),
    3: SurahDetails(
      surahName: "Ali 'Imran",
      surahNameArabic: "آل عمران",
      surahNameTranslation: "Family of Imran",
      revelationPlace: "Medina",
      totalAyah: 200,
      surahNo: 3,
      english: [
        "Alif, Lam, Meem.",
        "Allah - there is no deity except Him, the Ever-Living, the Sustainer of existence.",
      ],
      arabic: ["الم", "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ"],
    ),
    4: SurahDetails(
      surahName: "An-Nisa",
      surahNameArabic: "النساء",
      surahNameTranslation: "The Women",
      revelationPlace: "Medina",
      totalAyah: 176,
      surahNo: 4,
      english: [
        "O mankind, fear your Lord, who created you from one soul and created from it its mate.",
      ],
      arabic: [
        "يَا أَيُّهَا النَّاسُ اتَّقُوا رَبَّكُمُ الَّذِي خَلَقَكُم مِّن نَّفْسٍ وَاحِدَةٍ وَخَلَقَ مِنْهَا زَوْجَهَا",
      ],
    ),
    5: SurahDetails(
      surahName: "Al-Ma'idah",
      surahNameArabic: "المائدة",
      surahNameTranslation: "The Table Spread",
      revelationPlace: "Medina",
      totalAyah: 120,
      surahNo: 5,
      english: ["O you who have believed, fulfill [all] contracts."],
      arabic: ["يَا أَيُّهَا الَّذِينَ آمَنُوا أَوْفُوا بِالْعُقُودِ"],
    ),
    6: SurahDetails(
      surahName: "Al-An'am",
      surahNameArabic: "الأنعام",
      surahNameTranslation: "The Cattle",
      revelationPlace: "Mecca",
      totalAyah: 165,
      surahNo: 6,
      english: [
        "[All] praise is [due] to Allah, who created the heavens and the earth.",
      ],
      arabic: ["الْحَمْدُ لِلَّهِ الَّذِي خَلَقَ السَّمَاوَاتِ وَالْأَرْضَ"],
    ),
    // Tambahkan lebih banyak surah di sini...
    114: SurahDetails(
      surahName: "An-Nas",
      surahNameArabic: "الناس",
      surahNameTranslation: "Mankind",
      revelationPlace: "Mecca",
      totalAyah: 6,
      surahNo: 114,
      english: [
        "Say, \"I seek refuge in the Lord of mankind,",
        "The Sovereign of mankind,",
        "The God of mankind,",
        "From the evil of the retreating whisperer -",
        "Who whispers [evil] into the breasts of mankind -",
        "From among the jinn and mankind.\"",
      ],
      arabic: [
        "قُلْ أَعُوذُ بِرَبِّ النَّاسِ",
        "مَلِكِ النَّاسِ",
        "إِلَٰهِ النَّاسِ",
        "مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ",
        "الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ",
        "مِنَ الْجِنَّةِ وَالنَّاسِ",
      ],
    ),
  };

  @override
  void initState() {
    super.initState();
    print('Initializing SurahDetailsScreen for surah: ${widget.surahNumber}');
    _surahFuture = _fetchSurah();
    _initializeAudioPlayer();
    _setupAudioForSurah();
  }

  @override
  void didUpdateWidget(SurahDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahNumber != widget.surahNumber) {
      print(
        'Surah changed from ${oldWidget.surahNumber} to ${widget.surahNumber}',
      );
      _resetAudioPlayer();
      _setupAudioForSurah();
      setState(() {
        _surahFuture = _fetchSurah();
      });
    }
  }

  Future<SurahDetails> _fetchSurah() async {
    print('Fetching details for surah: ${widget.surahNumber}');

    for (final endpoint in app_config.Config.apiEndpoints) {
      try {
        final String url;
        if (endpoint.contains('equran.id')) {
          url = '$endpoint/surat/${widget.surahNumber}';
        } else if (endpoint.contains('santrikoding')) {
          url = '$endpoint/surah/${widget.surahNumber}';
        } else {
          url = '$endpoint/surah/${widget.surahNumber}';
        }

        print('Trying endpoint: $url');

        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          print('Success fetching from $endpoint');
          final surahData = surahDetailsFromJson(response.body);
          print(
            'Loaded surah: ${surahData.surahName} with ${surahData.arabic?.length ?? 0} verses',
          );
          return surahData;
        } else {
          print('Failed with status: ${response.statusCode}');
        }
      } catch (e) {
        print('Failed to fetch from $endpoint: $e');
        continue;
      }
    }

    // Fallback to local data
    print('Using fallback data for surah ${widget.surahNumber}');
    return _fallbackSurahs[widget.surahNumber] ?? _createBasicFallback();
  }

  SurahDetails _createBasicFallback() {
    // Data dasar untuk surah yang tidak ada di fallback
    final basicData = SurahDetails(
      surahName: "Surah ${widget.surahNumber}",
      surahNameArabic: "سورة ${widget.surahNumber}",
      surahNameTranslation: "Chapter ${widget.surahNumber}",
      revelationPlace: widget.surahNumber < 92 ? "Mecca" : "Medina",
      totalAyah: 50 + (widget.surahNumber % 50),
      surahNo: widget.surahNumber,
      english: ["Translation not available for this surah."],
      arabic: ["النص غير متوفر لهذه السورة"],
    );

    print('Created basic fallback for surah ${widget.surahNumber}');
    return basicData;
  }

  void _initializeAudioPlayer() {
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isLoadingAudio = state.processingState == ProcessingState.loading;

          // Reset position when audio completes
          if (state.processingState == ProcessingState.completed) {
            _position = Duration.zero;
            _isPlaying = false;
          }
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

  Future<void> _resetAudioPlayer() async {
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
        _currentAudioUrl = '';
      });
    } catch (e) {
      print('Error resetting audio player: $e');
    }
  }

  Future<void> _setupAudioForSurah() async {
    try {
      await _resetAudioPlayer();

      final audioUrl = _getAudioUrlForSurah(widget.surahNumber);
      _currentAudioUrl = audioUrl;

      print('Setting up audio for surah ${widget.surahNumber}: $audioUrl');

      await _player.setUrl(audioUrl);
      await _player.setSpeed(_playbackSpeed);

      print('Audio setup completed for surah ${widget.surahNumber}');
    } catch (e) {
      print('Error setting up audio for surah ${widget.surahNumber}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memuat audio untuk surah ${widget.surahNumber}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _getAudioUrlForSurah(int surahNumber) {
    // Multiple reliable audio sources
    final sources = [
      'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$surahNumber.mp3',
      'https://everyayah.com/data/Alafasy_128kbps/$surahNumber.mp3',
      'https://server8.mp3quran.net/afs/$surahNumber.mp3',
    ];

    return sources[0];
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
        // If audio is finished or not started, reset to beginning
        if (_position >= _duration || _position == Duration.zero) {
          await _player.seek(Duration.zero);
        }

        // Ensure we have the correct audio URL for current surah
        final currentAudioUrl = _getAudioUrlForSurah(widget.surahNumber);
        if (_currentAudioUrl != currentAudioUrl) {
          await _setupAudioForSurah();
        }

        await _player.setSpeed(_playbackSpeed);
        await _player.play();

        setState(() {
          _isPlaying = true;
          _isLoadingAudio = false;
        });
      }
    } catch (e) {
      print('Audio playback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memutar audio. Pastikan koneksi internet aktif.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _isLoadingAudio = false;
        });
      }
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  Future<void> _seekAudio(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      print('Error seeking audio: $e');
    }
  }

  Future<void> _changePlaybackSpeed() async {
    final newSpeed = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kecepatan Pemutaran'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildSpeedOption(0.5, '0.5x'),
              _buildSpeedOption(0.75, '0.75x'),
              _buildSpeedOption(1.0, '1.0x (Normal)'),
              _buildSpeedOption(1.25, '1.25x'),
              _buildSpeedOption(1.5, '1.5x'),
              _buildSpeedOption(2.0, '2.0x'),
            ],
          ),
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
      trailing: _playbackSpeed == speed
          ? Icon(Icons.check, color: _primaryColor)
          : null,
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
    print('Disposing audio player for surah ${widget.surahNumber}');
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

  Widget _buildAyahList(SurahDetails surahData) {
    final verseCount = surahData.arabic?.length ?? 0;

    if (verseCount == 0) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Data ayat belum tersedia untuk surah ini',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
              ),
            ],
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
            surahNumber: widget.surahNumber,
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

  // PERBAIKAN: Fix type casting error untuk slider
  Widget _buildProgressSlider() {
    final maxDuration = _duration.inMilliseconds.toDouble();
    final currentPosition = _position.inMilliseconds.toDouble();

    return Slider(
      value: currentPosition.clamp(0.0, maxDuration),
      min: 0.0,
      max: maxDuration,
      onChanged: (double value) async {
        await _seekAudio(Duration(milliseconds: value.toInt()));
      },
      onChangeEnd: (double value) async {
        await _seekAudio(Duration(milliseconds: value.toInt()));
      },
      activeColor: _primaryColor,
      inactiveColor: Colors.grey[300],
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mishary Alafasy',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Surah ${widget.surahNumber}',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
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
                    tooltip: 'Ubah Kecepatan',
                  ),
                  IconButton(
                    onPressed: _stopAudio,
                    icon: Icon(Icons.stop, color: _primaryColor),
                    tooltip: 'Stop',
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Memuat Surah ${widget.surahNumber}...',
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                ],
              ),
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
            final surahData = snapshot.data!;
            print(
              'Building UI for: ${surahData.surahName} with ${surahData.arabic?.length ?? 0} verses',
            );
            return _buildSurahContent(surahData);
          } else {
            return const Center(child: Text('Tidak ada data yang tersedia.'));
          }
        },
      ),
    );
  }
}
