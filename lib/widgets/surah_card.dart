import 'package:flutter/material.dart';
import 'dart:ui';

class SurahCard extends StatelessWidget {
  final String surahName;
  final String surahNameTranslation;
  final int totalVerses;
  final String revelationPlace;

  const SurahCard({
    super.key,
    required this.surahName,
    required this.surahNameTranslation,
    required this.totalVerses,
    required this.revelationPlace,
  });

  @override
  Widget build(BuildContext context) {
    // Memperbaiki masalah ukuran dengan menggunakan nilai tetap yang responsif
    const double cardHeight = 160.0;
    final width = MediaQuery.of(context).size.width;
    final imageSize = cardHeight * 0.7;

    return Container(
      height: cardHeight,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepOrange.shade800.withOpacity(0.40),
                      Colors.deepOrange.shade400.withOpacity(0.22),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          surahName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: cardHeight * 0.16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.black38,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          surahNameTranslation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: cardHeight * 0.09,
                            fontStyle: FontStyle.italic,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.menu_book,
                              size: cardHeight * 0.08,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$totalVerses verses',
                              style: TextStyle(
                                fontSize: cardHeight * 0.09,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 18),
                            Icon(
                              Icons.location_on,
                              size: cardHeight * 0.08,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                revelationPlace,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: cardHeight * 0.09,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: width * 0.04),
                  Container(
                    width: imageSize,
                    height: imageSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepOrange.shade300.withOpacity(0.6),
                          blurRadius: 18,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/${revelationPlace.toLowerCase() == 'mecca' ? 'mecca' : 'madina'}.png',
                        fit: BoxFit.cover,
                        color: Colors.white.withOpacity(0.92),
                        colorBlendMode: BlendMode.modulate,
                      ),
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
}
