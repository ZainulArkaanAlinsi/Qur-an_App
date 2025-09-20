import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:quran_app_2025/core/config.dart' as core_config;
import 'package:quran_app_2025/models/surahs.dart';
import 'package:quran_app_2025/screens/surah_details_screen.dart';
import 'package:quran_app_2025/widgets/quran_tile.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const String routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Surahs>> data;

  Future<List<Surahs>> _fetchChapters() async {
    try {
      // logic fect
      final response = await http.get(
        Uri.parse('${core_config.Config.baseApiUrl}/surah.json'),
      );

      //success -> nganu
      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        final List<Surahs> chapters = json
            .map((e) => Surahs.fromJson(e))
            .toList();
        return chapters;
      } else {
        throw Exception('Failed to load chapters');
      }
    } catch (e) {
      log(e.toString());
      throw Exception('Failed to load chapters');
    }
  }

  @override
  void initState() {
    super.initState();
    data = _fetchChapters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            try {
              // Ambil data terbaru dari _fetchChapters() yang mengembalikan Future
              final newData = await _fetchChapters();

              // Update state dengan data baru setelah selesai fetch
              setState(() {
                data = newData as Future<List<Surahs>>;
              });
            } catch (e) {
              // Tangani error jika fetch gagal misalnya tampilkan snackbar atau log
              log(e.toString());
            }
          },

          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'welcome to AL-Quran Kareem',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              FutureBuilder<List<Surahs>>(
                future: data,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // loading
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    // error
                    return Center(child: Text(snapshot.error.toString()));
                  } else if (snapshot.hasData) {
                    // success
                    return ListView.separated(
                      separatorBuilder: (context, index) {
                        return const Divider(height: 1);
                      },
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final Surahs surah = snapshot.data![index];
                        return QuranTile(
                          verseNumber: index + 1,
                          surahName: surah.surahName!,
                          revelationPlace: surah.revelationPlace!,
                          totalAyah: surah.totalAyah!,
                          surahNameArabic: surah.surahNameArabic!,
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              SurahDetailsScreen.routeName,
                              arguments: index + 1,
                            );
                          },
                        );
                      },
                    );
                  } else {
                    return const Center(child: Text('No data available'));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
