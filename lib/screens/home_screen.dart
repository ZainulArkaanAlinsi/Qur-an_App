import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quran_app_2025/core/config.dart' as core_config;
import 'package:quran_app_2025/models/surahs.dart';
import 'package:quran_app_2025/screens/surah_details_screen.dart';
import 'package:quran_app_2025/screens/search_screen.dart';
import 'package:quran_app_2025/screens/bookmark_screen.dart';
import 'package:quran_app_2025/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const String routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Surahs>> data;
  final Color _primaryColor = const Color(0xFF2E7D32);
  final Color _secondaryColor = const Color(0xFF1B5E20);
  final Color _accentColor = const Color(0xFFE8F5E9);
  final Color _goldColor = const Color(0xFFD4AF37);

  // Fallback data untuk offline mode
  final List<Surahs> _fallbackSurahs = List.generate(114, (index) {
    return Surahs(
      number: index + 1,
      surahName: "Surah ${index + 1}",
      surahNameArabic: "سورة ${index + 1}",
      surahNameTranslation: "Chapter ${index + 1}",
      revelationPlace: index < 92 ? "Mecca" : "Medina",
      totalAyah: 50 + (index % 50),
    );
  });

  Future<List<Surahs>> _fetchChapters() async {
    for (final endpoint in core_config.Config.apiEndpoints) {
      try {
        final response = await http
            .get(Uri.parse('$endpoint/surahs'))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
          final List<dynamic> dataList = jsonResponse['data'] ?? [];
          if (dataList.isNotEmpty) {
            return dataList.map((e) => Surahs.fromJson(e)).toList();
          }
        }
      } catch (e) {
        print('Failed to fetch from $endpoint: $e');
        continue;
      }
    }

    // Jika semua API gagal, gunakan fallback data
    return _fallbackSurahs;
  }

  @override
  void initState() {
    super.initState();
    data = _fetchChapters();
  }

  Future<void> _refreshData() async {
    final newData = await _fetchChapters();
    setState(() {
      data = Future.value(newData);
    });
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      floating: true,
      pinned: true,
      snap: false,
      expandedHeight: 120.0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Al-Qur\'an Kareem',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryColor, _secondaryColor],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            Navigator.pushNamed(context, '/search');
          },
          icon: const Icon(Icons.search),
          tooltip: 'Search',
        ),
        IconButton(
          onPressed: () {
            Navigator.pushNamed(context, '/settings');
          },
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, _secondaryColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('114', 'Surah', Icons.book),
          _buildStatItem('6236', 'Ayat', Icons.format_quote),
          _buildStatItem('30', 'Juz', Icons.library_books),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionCard(
              'Last Read',
              Icons.bookmark,
              _primaryColor,
              () {
                // Navigate to last read
                Navigator.pushNamed(context, '/surah_details', arguments: 1);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionCard(
              'Bookmarks',
              Icons.bookmarks,
              _goldColor,
              () {
                Navigator.pushNamed(context, '/bookmarks');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSurahTile(Surahs surah, int index, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(SurahDetailsScreen.routeName, arguments: surah.number);
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_accentColor, _accentColor.withOpacity(0.7)],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${surah.number}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          surah.surahName ?? 'Unknown',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${surah.revelationPlace ?? 'Unknown'} • ${surah.totalAyah ?? 0} Ayat',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              surah.surahNameArabic ?? '...',
              style: const TextStyle(
                fontFamily: 'Amiri',
                fontSize: 20,
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: _primaryColor,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsCard(),
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Daftar Surah',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              FutureBuilder<List<Surahs>>(
                future: data,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Gagal memuat data\nMenggunakan data offline',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(child: Text('Tidak ada data surah.')),
                    );
                  }

                  final surahs = snapshot.data!;
                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final surah = surahs[index];
                      return _buildSurahTile(surah, index, theme);
                    }, childCount: surahs.length),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
