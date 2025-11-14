import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran_app_2025/services/shared_preferences_service.dart';
import 'package:share_plus/share_plus.dart';

class Ayah extends StatefulWidget {
  final int verseNumber;
  final String verseArabic;
  final String verseEnglish;
  final int surahNumber;

  const Ayah({
    super.key,
    required this.verseNumber,
    required this.verseArabic,
    required this.verseEnglish,
    required this.surahNumber,
  });

  @override
  State<Ayah> createState() => _AyahState();
}

class _AyahState extends State<Ayah> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isBookmarked = false;

  final Color _primaryColor = const Color(0xFF2E7D32);
  final Color _accentColor = const Color(0xFFE8F5E9);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.98,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.value = 1.0;
    _checkBookmarkStatus();
  }

  void _checkBookmarkStatus() {
    setState(() {
      _isBookmarked = SharedPreferencesService.isBookmarked(
        widget.surahNumber,
        widget.verseNumber,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.reverse();
  void _onTapUp(TapUpDetails _) => _controller.forward();
  void _onTapCancel() => _controller.forward();

  void _handleBookmark() async {
    if (_isBookmarked) {
      await SharedPreferencesService.removeBookmark(
        widget.surahNumber,
        widget.verseNumber,
      );
    } else {
      await SharedPreferencesService.saveBookmark(
        widget.surahNumber,
        widget.verseNumber,
      );
    }

    setState(() {
      _isBookmarked = !_isBookmarked;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBookmarked
              ? 'Ayat ${widget.verseNumber} di-bookmark!'
              : 'Bookmark dihapus!',
        ),
        backgroundColor: _primaryColor,
      ),
    );
  }

  void _handleShare() async {
    final text =
        '''
${widget.verseArabic}

${widget.verseEnglish}

— Quran App 2025
    ''';

    await Share.share(text);
  }

  void _handleCopy() {
    final text = '${widget.verseArabic}\n\n${widget.verseEnglish}';
    // Implement copy to clipboard
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ayat ${widget.verseNumber} disalin!'),
        backgroundColor: _primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arabicFontSize = SharedPreferencesService.getArabicFontSize();
    final translationFontSize =
        SharedPreferencesService.getTranslationFontSize();

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header dengan nomor ayat dan actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nomor ayat
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accentColor,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.verseNumber}',
                      style: GoogleFonts.poppins(
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  // Tombol aksi
                  Row(
                    children: [
                      // Tombol Copy
                      IconButton(
                        onPressed: _handleCopy,
                        icon: Icon(
                          Icons.content_copy,
                          color: _primaryColor,
                          size: 18,
                        ),
                        tooltip: 'Salin Ayat',
                      ),
                      // Tombol Bookmark
                      IconButton(
                        onPressed: _handleBookmark,
                        icon: Icon(
                          _isBookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: _isBookmarked ? _primaryColor : _primaryColor,
                          size: 18,
                        ),
                        tooltip: _isBookmarked
                            ? 'Hapus Bookmark'
                            : 'Tandai Ayat',
                      ),
                      // Tombol Share
                      IconButton(
                        onPressed: _handleShare,
                        icon: Icon(Icons.share, color: _primaryColor, size: 18),
                        tooltip: 'Bagikan Ayat',
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Teks Arab
              Text(
                widget.verseArabic,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.amiri(
                  fontSize: arabicFontSize,
                  height: 1.8,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 20),

              Divider(color: Colors.grey.shade200, thickness: 1),

              const SizedBox(height: 20),

              // Terjemahan
              Text(
                '${widget.verseNumber}. ${widget.verseEnglish}',
                textAlign: TextAlign.left,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: translationFontSize,
                  height: 1.6,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
