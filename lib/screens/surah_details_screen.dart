import 'dart:async';
import 'dart:developer';
import 'dart:ui';
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
  final List<Audio> _reciters = [];
  Audio? _selectedReciter;

  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _surahFuture = _fetchSurah();
    _initializeAudioPlayer();
  }

  Future<SurahDetails> _fetchSurah() async {
    try {
      final response = await http.get(
        Uri.parse('${app_config.Config.baseApiUrl}/${widget.surahNumber}.json'),
      );

      if (response.statusCode == 200) {
        final surahDetails = surahDetailsFromJson(response.body);
        _initializeReciters(surahDetails);
        return surahDetails;
      } else {
        throw Exception('Failed to load surah details');
      }
    } catch (e) {
      log('Fetch error: $e');
      throw Exception('Failed to load surah details');
    }
  }

  void _initializeReciters(SurahDetails surahDetails) {
    if (surahDetails.audio != null && surahDetails.audio!.isNotEmpty) {
      _reciters.addAll(surahDetails.audio!.values);
      if (_reciters.isNotEmpty) {
        _selectedReciter = _reciters.first;
      }
    }
  }

  void _initializeAudioPlayer() {
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
      }
    });

    _durationSubscription = _player.durationStream.listen((duration) {
      if (duration != null && mounted) {
        setState(() => _duration = duration);
      }
    });

    _positionSubscription = _player.positionStream.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });
  }

  Future<void> _toggleAudio() async {
    if (_selectedReciter == null) return;

    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.idle ||
            _player.processingState == ProcessingState.completed) {
          await _player.setUrl(_selectedReciter!.url!);
        }
        await _player.play();
      }
    } catch (e) {
      log('Audio error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to play audio. Please check your connection.',
            ),
          ),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<SurahDetails>(
        future: _surahFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            return _buildSurahContent(snapshot.data!);
          } else {
            return const Center(child: Text('No data available.'));
          }
        },
      ),
    );
  }

  Widget _buildSurahContent(SurahDetails surahData) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            setState(() => _surahFuture = _fetchSurah());
          },
          child: CustomScrollView(
            slivers: [
              _buildHeader(surahData),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 150),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (surahData.surahNo != 1 && surahData.surahNo != 9)
                      _buildBismillah(),
                    const SizedBox(height: 12),
                    _buildAyahList(surahData),
                  ]),
                ),
              ),
            ],
          ),
        ),
        _buildAudioPlayer(),
      ],
    );
  }

  Widget _buildBismillah() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Image.asset(
          'assets/images/Bismillah.png',
          height: 80,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildAyahList(SurahDetails surahData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: surahData.arabic1!.length,
        itemBuilder: (context, index) => Ayah(
          verseNumber: index + 1,
          verseArabic: surahData.arabic1![index],
          verseEnglish: surahData.english![index],
        ),
      ),
    );
  }

  Widget _buildHeader(SurahDetails surahData) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      expandedHeight: 250.0,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade700, Colors.green.shade900],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/quran_bg.jpg',
                  fit: BoxFit.cover,
                  colorBlendMode: BlendMode.modulate,
                  color: Colors.black.withOpacity(0.5),
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
                    Text(
                      surahData.surahNameTranslation!,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${surahData.revelationPlace!} - ${surahData.totalAyah!} Ayah',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      surahData.surahNameArabic!,
                      style: GoogleFonts.amiri(
                        fontSize: 60,
                        color: Colors.white,
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

  Widget _buildAudioPlayer() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
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
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    _buildReciterDropdown(),
                    Text(
                      _formatDuration(_duration),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                _buildProgressSlider(),
                IconButton(
                  onPressed: _selectedReciter != null ? _toggleAudio : null,
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 50,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Colors.green.shade800,
        inactiveTrackColor: Colors.green.shade800.withOpacity(0.2),
        thumbColor: Colors.green.shade800,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      child: Slider(
        min: 0,
        max: _duration.inMilliseconds.toDouble(),
        value: _position.inMilliseconds.toDouble(),
        onChanged: (value) async {
          await _player.seek(Duration(milliseconds: value.toInt()));
        },
      ),
    );
  }

  Widget _buildReciterDropdown() {
    return DropdownButton<Audio>(
      value: _selectedReciter,
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.green),
      underline: const SizedBox(),
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      onChanged: (Audio? newReciter) {
        if (newReciter != null) {
          setState(() {
            _selectedReciter = newReciter;
            _player.pause();
            _player.seek(Duration.zero);
          });
        }
      },
      items: _reciters.map<DropdownMenuItem<Audio>>((Audio reciter) {
        return DropdownMenuItem<Audio>(
          value: reciter,
          child: Text(reciter.reciter ?? 'Unknown Reciter'),
        );
      }).toList(),
    );
  }
}
