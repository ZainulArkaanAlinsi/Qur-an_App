import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app_2025/data/audio_sources.dart';
import 'package:quran_app_2025/data/qari_catalog.dart';
import 'package:quran_app_2025/features/murottal/presentation/murottal_panel.dart';
import 'package:quran_app_2025/models/reciter.dart';
import 'package:quran_app_2025/services/quran_audio_service.dart';

/// docs/design/v6/screens/23-qari.md "Selesai jika" (a)–(f).
void main() {
  final raw = File(QariCatalog.asset).readAsStringSync();
  final catalog = QariCatalog.parse(raw);

  List<String> ids(Iterable<QariEntry> entries) => [
    for (final entry in entries) entry.id,
  ];

  test('katalog utuh: 35 qari, kurasi tidak berubah', () {
    expect(catalog.entries, hasLength(35));
    expect(catalog.updated, '2026-10-02');
    expect(catalog.popular.first, 'yasser');
  });

  test('(a) mode rilis tidak pernah menampilkan qari tanpa sumber granted', () {
    final release = catalog.visible(allowPending: false);
    // 17 dari Islamic Network + 4 dari equran.id (granted sejak 15 Nov 2026).
    expect(release, hasLength(21));
    for (final entry in release) {
      expect(
        entry.sources.any((s) => s.granted && s.ref != null),
        isTrue,
        reason: entry.id,
      );
      expect(entry.toReciter(allowPending: false), isNotNull);
    }
    for (final filter in QariFilter.values) {
      for (final entry in catalog.filtered(filter, allowPending: false)) {
        expect(entry.granted, isTrue, reason: '${filter.name} ${entry.id}');
      }
    }
    expect(ids(catalog.popularNow(allowPending: false)), contains('yasser'));
    // Debug: semua 35.
    expect(catalog.visible(allowPending: true), hasLength(35));
  });

  test('(b) status sumber di JSON sama dengan audio_sources.dart', () {
    final json = (jsonDecode(raw) as Map)['sumber'] as Map;
    expect(json.keys.toSet(), {for (final s in AudioSources.all) s.id});
    for (final source in AudioSources.all) {
      expect(
        catalog.sourceStatus[source.id],
        source.status.name,
        reason: source.id,
      );
    }
    expect(
      [
        for (final s in AudioSources.all)
          if (s.granted) s.id,
      ],
      ['islamic_network', 'equran', 'quran_foundation', 'qul', 'mp3quran'],
    );
  });

  test('(c) filter & urutan Populer stabil', () {
    // Rilis, Adem: urutan kurasi katalog (acuan V6-Qari.png).
    expect(
      ids(
        catalog.filtered(
          QariFilter.adem,
          allowPending: false,
          exceptId: 'hudhaify',
        ),
      ),
      [
        'maher',
        'husary',
        'shaatree',
        'hanirifai',
        'basfar',
        'akhdar',
        'ayyoub',
        'parhizgar',
        // equran.id, granted sejak 15 Nov 2026: urutan kurasi katalog.
        'yasser',
        'juhany',
        'ibrahim_dossari',
        'qasim',
      ],
    );
    // "Populer sekarang": urutan daftar `populer`, hanya yang tampil.
    // Mengikuti daftar `populer` di katalog; Yasser dan Al-Juhany kini tampil
    // karena equran.id granted.
    expect(ids(catalog.popularNow(allowPending: false)), [
      'yasser',
      'alafasy',
      'maher',
      'juhany',
      'sudais',
      'hanirifai',
    ]);
    expect(ids(catalog.filtered(QariFilter.populer, allowPending: false)), [
      'yasser',
      'alafasy',
      'maher',
      'juhany',
      'sudais',
      'hanirifai',
    ]);
    // Debug: yang menunggu izin dulu, lalu A–Z.
    final debug = catalog.filtered(QariFilter.adem, allowPending: true);
    // Abdul Muhsin Al-Qasim kini granted (equran.id), jadi yang pertama menunggu izin berikutnya.
    expect(debug.first.name, 'Ali Jaber');
    expect(debug.first.granted, isFalse);
    expect(debug.indexWhere((e) => e.granted), greaterThan(0));
    expect(debug.skipWhile((e) => !e.granted).every((e) => e.granted), isTrue);
    // Pencarian nama Latin, tanpa peduli huruf besar.
    expect(
      ids(
        catalog.filtered(
          QariFilter.semua,
          allowPending: false,
          query: 'HUSARY',
        ),
      ),
      ['husary', 'husary_mujawwad'],
    );
    expect(QariFilter.parse('adem'), QariFilter.adem);
    expect(QariFilter.parse('rusak'), QariFilter.semua);
  });

  test('(d) ref null tidak pernah dipakai untuk membentuk URL', () {
    for (final allowPending in [false, true]) {
      for (final entry in catalog.entries) {
        final source = entry.playableSource(allowPending: allowPending);
        if (source != null) expect(source.ref, isNotNull, reason: entry.id);
        final reciter = entry.toReciter(allowPending: allowPending);
        if (reciter == null) continue;
        final url = QuranAudioService.urlFor(1, 1, reciter: reciter);
        expect(url.toString(), isNot(contains('null')), reason: entry.id);
      }
    }
    // Qari yang hanya punya sumber dengan ref null tidak bisa diputar.
    final ghamdi = catalog.entries.firstWhere((e) => e.id == 'ghamdi');
    expect(ghamdi.toReciter(allowPending: true), isNull);
    final sobhi = catalog.entries.firstWhere((e) => e.id == 'islam_sobhi');
    expect(sobhi.toReciter(allowPending: true), isNull);
  });

  test('(e) qari per surah: keterangan di Murottal, sesi tetap per ayat', () {
    final perSurah = catalog.entries.where((e) => e.perSurahOnly).toList();
    expect(ids(perSurah), containsAll(['abkar', 'luhaidan', 'muzammil']));
    const reciter = Reciter(
      identifier: 'mp3quran:12',
      name: '',
      englishName: 'Idris Abkar',
      perAyat: false,
    );
    expect(
      MurottalPanel.perSurahNote(reciter),
      'Qari ini per surah. Ulang ayat memakai Mishary Rashid Alafasy.',
    );
    expect(MurottalPanel.perSurahNote(defaultReciter), isNull);
    expect(Reciter.fromJson(reciter.toJson()).perAyat, isFalse);
  });

  test('(f) qari Quran Foundation tidak menampilkan Unduh', () {
    expect(AudioSources.quranFoundation.downloadable, isFalse);
    const qf = Reciter(
      identifier: 'qf:7',
      name: '',
      englishName: 'Saad Al-Ghamdi',
      provider: AudioProvider.quranFoundation,
    );
    expect(qf.downloadable, isFalse);
    expect(defaultReciter.downloadable, isTrue);
  });

  test('equran.id bisa diputar di rilis maupun debug', () {
    final yasser = catalog.entries.firstWhere((e) => e.id == 'yasser');
    expect(yasser.toReciter(allowPending: false), isNotNull);
    final reciter = yasser.toReciter(allowPending: true)!;
    expect(reciter.provider, AudioProvider.equran);
    expect(
      QuranAudioService.urlFor(1, 1, reciter: reciter).toString(),
      'https://cdn.equran.id/audio-partial/Yasser-Al-Dosari/001001.mp3',
    );
    expect(reciter.downloadable, isFalse);
  });

  test(
    'granted tidak cukup: qari tanpa sumber yang tersambung tidak tampil',
    () {
      // MP3Quran, QUL, dan Quran Foundation berstatus granted tetapi belum punya
      // jalur pemutaran di kode (8b/8c). Qari yang hanya bergantung pada mereka
      // tidak boleh muncul di rilis sebagai entri yang tak bisa diputar.
      final stranded = [
        for (final e in catalog.entries)
          if (e.granted && e.playableSource(allowPending: false) == null) e,
      ];
      expect(stranded, isNotEmpty, reason: 'ada qari yang menunggu sumbernya');
      final release = ids(catalog.visible(allowPending: false));
      for (final entry in stranded) {
        expect(release, isNot(contains(entry.id)), reason: entry.id);
        expect(entry.toReciter(allowPending: false), isNull, reason: entry.id);
      }
      for (final id in release) {
        final entry = catalog.entries.firstWhere((e) => e.id == id);
        expect(
          entry.toReciter(allowPending: false),
          isNotNull,
          reason: 'tampil di rilis tetapi tak bisa diputar: $id',
        );
      }
    },
  );

  test('cadangan equran.id dan MP3Quran aktif di rilis karena granted', () {
    AudioSources.debugAllowPending = false; // meniru build rilis
    addTearDown(() => AudioSources.debugAllowPending = null);
    expect(AudioSources.allowPending, isFalse);
    expect(AudioSources.canUseEquran, isTrue);
    expect(AudioSources.canUseMp3Quran, isTrue);
  });

  test('nama Arab dari daftar alquran.cloud lewat ref', () {
    final named = catalog.withArabicNames(const [
      Reciter(
        identifier: 'ar.hudhaify',
        name: 'علي بن عبدالرحمن الحذيفي',
        englishName: 'Hudhaify',
      ),
    ]);
    expect(
      named.entries.firstWhere((e) => e.id == 'hudhaify').arabicName,
      'علي بن عبدالرحمن الحذيفي',
    );
    expect(named.entries.firstWhere((e) => e.id == 'maher').arabicName, isNull);
  });
}
