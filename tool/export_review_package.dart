// Mengekspor materi draf tajwid (tahap 6-16) menjadi paket peninjauan untuk
// guru, dan daftar slot audio menjadi panduan rekaman.
//
// Skrip ini TIDAK menulis atau mengubah isi agama apa pun. Teks pelajaran
// disalin apa adanya dari assets/learn/curriculum.json; ayat contoh diambil
// dari dataset Tanzil lewat fungsi pemecah kata yang sama dengan aplikasi
// (`exampleWords`), jadi kata yang ditandai sama persis dengan yang tampil
// di layar. Bagian yang harus ditulis guru dibiarkan kosong.
//
// Jalankan dari akar repo:
//   dart run tool/export_review_package.dart
//
// Keluaran (docs/content/paket-peninjau/):
//   paket-peninjau-tajwid-tahap-6-16.html
//   panduan-rekaman-audio.html
// PDF dibuat dari HTML itu (lihat README.md di folder yang sama).
import 'dart:convert';
import 'dart:io';

import 'package:quran_app_2025/data/basmalah.dart';
import 'package:quran_app_2025/features/learn/domain/example_words.dart';

const _outDir = 'docs/content/paket-peninjau';
const _firstLevel = 6;

final _problems = <String>[];

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

final _arabicRun = RegExp(
  r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]+'
  r'(?:[  ]+[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]+)*',
);

/// Teks biasa -> HTML aman: **tebal** dan bagian Arab diberi font Arab.
String _inline(String s) => _esc(s)
    .replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (m) => '<strong>${m[1]}</strong>',
    )
    .replaceAllMapped(
      _arabicRun,
      (m) => '<span class="ar" dir="rtl">${m[0]}</span>',
    );

String _pad(int n) => n.toString().padLeft(2, '0');

const _months = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus',
  'September', 'Oktober', 'November', 'Desember', //
];

String _today() {
  final d = DateTime.now();
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

// ---------------------------------------------------------------- data Tanzil

class _Quran {
  _Quran._(this._verses, this._start, this.fatihahFirst);

  final List<String> _verses;
  final Map<int, int> _start;
  final String fatihahFirst;

  static _Quran load() {
    final xml = File('assets/quran/raw/quran-data.xml').readAsStringSync();
    final start = <int, int>{};
    for (final m in RegExp(
      r'<sura index="(\d+)" ayas="\d+" start="(\d+)"',
    ).allMatches(xml)) {
      start[int.parse(m[1]!)] = int.parse(m[2]!);
    }
    final verses = File('assets/quran/raw/tanzil_uthmani_v1.0.2.txt')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
        .toList();
    if (verses.length != 6236 || start.length != 114) {
      throw StateError(
        'Dataset Tanzil tidak utuh: ${verses.length} ayat, ${start.length} surah.',
      );
    }
    return _Quran._(verses, start, verses.first);
  }

  String verse(int surah, int ayah) {
    final s = _start[surah];
    if (s == null) throw RangeError('Surah $surah tidak ada');
    return _verses[s + ayah - 1];
  }
}

/// Ayat contoh dengan kata yang ditandai, persis seperti di aplikasi.
String _exampleHtml(_Quran q, String id, Map<String, dynamic> b) {
  final surah = b['surah'] as int;
  final ayah = b['ayah'] as int;
  final words = (b['words'] as List?)?.cast<int>();
  final verse = q.verse(surah, ayah);
  final prefix = ayah == 1 ? basmalahPrefix(surah, verse, q.fatihahFirst) : 0;
  final all = exampleWords(
    surah: surah,
    ayah: ayah,
    verse: verse,
    fatihahFirst: q.fatihahFirst,
  );
  final hl = highlightOf(all, words);
  final shown = verse.substring(prefix);
  final head =
      '<div class="ref">Q.S. $surah:$ayah'
      '${words == null ? '' : ' · kata ${words[0]}–${words[1]}'}'
      ' <span class="muted">(${all.length} kata)</span></div>';
  String arabic;
  if (words == null) {
    // Contoh satu ayat utuh tanpa kata yang ditandai: sah.
    arabic = '<span class="ar big" dir="rtl">${_esc(shown)}</span>';
  } else if (hl == null) {
    _problems.add('$id: rentang kata $words tidak valid untuk $surah:$ayah');
    arabic =
        '<span class="ar" dir="rtl">${_esc(shown)}</span>'
        '<div class="warn">RENTANG KATA TIDAK VALID, periksa sebelum dicetak.</div>';
  } else {
    final s = hl.start - prefix;
    final e = hl.end - prefix;
    arabic =
        '<span class="ar big" dir="rtl">${_esc(shown.substring(0, s))}'
        '<mark>${_esc(shown.substring(s, e))}</mark>'
        '${_esc(shown.substring(e))}</span>';
  }
  final note = b['note'] as String?;
  return '$head<div class="verse">$arabic</div>'
      '${note == null ? '' : '<div class="note-app"><span class="muted">Keterangan di aplikasi:</span> ${_inline(note)}</div>'}';
}

// -------------------------------------------------------------- blok pelajaran

const _typeLabel = {
  'text': 'Penjelasan',
  'tip': 'Catatan',
  'letters': 'Daftar huruf',
  'example': 'Contoh ayat',
  'audio': 'Audio contoh',
  'quiz': 'Soal',
};

String _blockBody(_Quran q, String id, Map<String, dynamic> b) {
  switch (b['type']) {
    case 'text':
      final h = b['heading'] as String?;
      return '${h == null ? '' : '<div class="h">${_inline(h)}</div>'}'
          '<div>${_inline(b['text'] as String)}</div>';
    case 'tip':
      return '<div>${_inline(b['text'] as String)}</div>';
    case 'letters':
      final items = (b['items'] as List).cast<Map<String, dynamic>>();
      return '<table class="letters">${[for (final i in items) '<tr><td class="ar big" dir="rtl">${_esc('${i['letter']}')}</td>'
            '<td>${_inline('${i['name']}')}</td>'
            '<td class="muted">${_inline('${i['note'] ?? ''}')}</td></tr>'].join()}</table>';
    case 'example':
      return _exampleHtml(q, id, b);
    case 'audio':
      return '<div><strong>${_inline(b['label'] as String)}</strong></div>'
          '<div class="muted">Slot audio. Belum ada rekaman (app menampilkan '
          '"sedang disiapkan"). Tidak perlu dinilai di sini; lihat panduan rekaman.</div>';
    case 'quiz':
      final opts = (b['options'] as List).cast<String>();
      final answer = b['answer'] as int;
      return '<div class="h">${_inline(b['question'] as String)}</div>'
          '<ol class="opts" type="A">${[for (var i = 0; i < opts.length; i++) '<li${i == answer ? ' class="key"' : ''}>${_inline(opts[i])}'
                '${i == answer ? ' <span class="keytag">kunci jawaban</span>' : ''}</li>'].join()}</ol>'
          '<div><span class="muted">Penjelasan di aplikasi:</span> ${_inline('${b['explanation'] ?? ''}')}</div>';
    default:
      throw StateError('Jenis blok tidak dikenal: ${b['type']}');
  }
}

String _lessonSection(_Quran q, Map<String, dynamic> l) {
  final level = l['level'] as int;
  final blocks = (l['blocks'] as List).cast<Map<String, dynamic>>();
  final rows = StringBuffer();
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    final id = 'T$level.${_pad(i + 1)}';
    final isAudio = b['type'] == 'audio';
    rows.writeln(
      '<tr class="${b['type']}"><td class="no">$id</td>'
      '<td class="type">${_typeLabel[b['type']]}</td>'
      '<td class="body">${_blockBody(q, id, b)}</td>'
      '<td class="mark">${isAudio ? '<span class="muted">tidak dinilai</span>' : '☐ Benar<br>☐ Perbaiki<br>☐ Salah<br>☐ Ragu'}</td>'
      '<td class="note"></td></tr>',
    );
  }
  final objectives = (l['objectives'] as List?)?.cast<String>() ?? const [];
  final sources = (l['sources'] as List).cast<Map<String, dynamic>>();
  return '''
<section class="lesson">
<h2>Tahap $level · ${_inline(l['title'] as String)}</h2>
<p class="meta">id: ${_esc(l['id'] as String)} · status saat ini: <strong>${_esc(l['review'] as String)}</strong> · ${blocks.length} butir</p>
<p>${_inline(l['summary'] as String)}</p>
${objectives.isEmpty ? '' : '<h3>Tujuan belajar menurut draf</h3><ul>${objectives.map((o) => '<li>${_inline(o)}</li>').join()}</ul>'}
<div class="prov"><strong>Catatan penyusun draf, apa adanya dari berkas:</strong><br>${_inline(l['provenance'] as String)}</div>
<h3>Rujukan yang dinyatakan draf</h3>
<ul>${sources.map((s) => '<li>${_inline('${s['title']}')} — ${_inline('${s['author'] ?? ''}')}${(s['url'] as String?)?.isNotEmpty == true ? ' (${_esc(s['url'] as String)})' : ''}</li>').join()}</ul>
<table class="items">
<colgroup><col style="width:15mm"><col style="width:20mm"><col><col style="width:26mm"><col style="width:44mm"></colgroup>
<thead><tr><th>No</th><th>Jenis</th><th>Isi di aplikasi</th><th>Penilaian</th><th>Catatan dan rujukan Anda (kitab, bab/halaman)</th></tr></thead>
<tbody>
$rows</tbody></table>
<div class="verdict"><strong>Kesimpulan tahap $level:</strong>
 &nbsp; ☐ Layak terbit &nbsp; ☐ Layak terbit setelah perbaikan &nbsp; ☐ Belum layak &nbsp;&nbsp;|&nbsp;&nbsp; Peninjau: ☐ 1 &nbsp;☐ 2</div>
</section>''';
}

// ------------------------------------------------------------ bagian B dan C

List<({String id, String providerClass, String nameId})> _ruleNames() {
  final src = File(
    'lib/features/tajweed/domain/tajweed_rule.dart',
  ).readAsStringSync();
  final body = src.substring(
    src.indexOf('enum TajweedRule'),
    src.indexOf('const TajweedRule('),
  );
  // Nama Indonesia boleh memakai tanda petik satu ("Mad Thabi'i"), jadi ditulis
  // dengan petik dua; kedua bentuk dikenali.
  final rules = [
    for (final m in RegExp(
      r'''(\w+)\('([^']+)',\s*(?:'([^']*)'|"([^"]*)")\)''',
    ).allMatches(body))
      (id: m[1]!, providerClass: m[2]!, nameId: (m[3] ?? m[4])!),
  ];
  final expected =
      (jsonDecode(
                File(
                  'assets/learn/tajweed_explanations.json',
                ).readAsStringSync(),
              )['rules']
              as List)
          .length;
  if (rules.length != expected) {
    throw StateError(
      'Daftar hukum tidak cocok: ${rules.length} terbaca dari tajweed_rule.dart, '
      '$expected di tajweed_explanations.json.',
    );
  }
  return rules;
}

String _partB(List<({String id, String providerClass, String nameId})> rules) {
  return '''
<section class="lesson">
<h2>Bagian B · Nama 17 hukum tajwid di aplikasi</h2>
<p>Nama-nama ini tampil di layar <em>Warna tajwid</em> saat pembaca mengetuk huruf berwarna. Tertulis
berstatus <strong>draf</strong> di kode. Pemilik meminta perhatian khusus pada empat pemetaan:
<code>madda_permissible</code> → "Mad Jaiz", <code>madda_obligatory</code> → "Mad Wajib",
<code>slnt</code> → "Huruf tidak dibaca", dan <code>ham_wasl</code> → "Hamzah Washal".
Penyedia data hanya memberi nama kelas dalam bahasa Inggris; pemetaan ke istilah Indonesia dilakukan
oleh penyusun draf (AI), jadi mohon diperiksa satu per satu.</p>
<table class="items">
<colgroup><col style="width:15mm"><col><col style="width:40mm"><col style="width:26mm"><col style="width:50mm"></colgroup>
<thead><tr><th>No</th><th>Nama di aplikasi</th><th>Kelas dari penyedia data</th><th>Penilaian nama</th><th>Catatan (nama yang benar, rujukan)</th></tr></thead>
<tbody>
${[for (var i = 0; i < rules.length; i++) '<tr><td class="no">B.${_pad(i + 1)}</td><td class="body"><strong>${_inline(rules[i].nameId)}</strong></td>'
        '<td class="body"><code>${_esc(rules[i].providerClass)}</code></td>'
        '<td class="mark">☐ Benar<br>☐ Perbaiki<br>☐ Salah<br>☐ Ragu</td><td class="note"></td></tr>'].join('\n')}
</tbody></table>
</section>''';
}

String _partC(List<({String id, String providerClass, String nameId})> rules) {
  final raw =
      jsonDecode(
            File('assets/learn/tajweed_explanations.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final ids = [
    for (final r in raw['rules'] as List) (r as Map)['rule'] as String,
  ];
  final byId = {for (final r in rules) r.id: r};
  return '''
<section class="lesson">
<h2>Bagian C · Penjelasan cara membaca tiap hukum (diisi guru)</h2>
<p><strong>Ini bagian yang hanya boleh ditulis oleh guru.</strong> Layar penjelasan hukum di aplikasi
sekarang kosong dan menampilkan "sedang disiapkan bersama guru tajwid". Sesuai aturan proyek,
isinya <strong>tidak boleh ditulis atau dibuatkan oleh AI</strong>. Mohon tulis dengan kata-kata Anda
sendiri, untuk pembaca awam, singkat dan jelas, lalu cantumkan rujukan.</p>
<table class="items">
<colgroup><col style="width:15mm"><col style="width:40mm"><col><col style="width:48mm"></colgroup>
<thead><tr><th>No</th><th>Hukum</th><th>Cara membacanya (tulisan guru)</th><th>Rujukan</th></tr></thead>
<tbody>
${[for (var i = 0; i < ids.length; i++) '<tr class="fill"><td class="no">C.${_pad(i + 1)}</td><td class="body"><strong>${_inline(byId[ids[i]]?.nameId ?? ids[i])}</strong></td>'
        '<td class="write"></td><td class="note"></td></tr>'].join('\n')}
</tbody></table>
</section>''';
}

String _signature(List<Map<String, dynamic>> lessons) {
  return '''
<section class="lesson sign">
<h2>Lembar pengesahan</h2>
<p>Dengan menandatangani, peninjau menyatakan telah memeriksa butir-butir di atas sesuai ilmu dan
rujukannya, dan bahwa penilaian di lembar ini adalah penilaiannya sendiri. Materi baru boleh
diterbitkan di aplikasi setelah <strong>dua peninjau</strong> menyetujuinya.</p>
<table class="items sig">
<colgroup><col style="width:60mm"><col><col></colgroup>
<thead><tr><th></th><th>Peninjau 1</th><th>Peninjau 2</th></tr></thead>
<tbody>
<tr><td class="body">Nama lengkap</td><td class="write short"></td><td class="write short"></td></tr>
<tr><td class="body">Kualifikasi (guru Al-Qur'an/tajwid, sanad, ijazah)</td><td class="write short"></td><td class="write short"></td></tr>
<tr><td class="body">Lembaga / tempat mengajar</td><td class="write short"></td><td class="write short"></td></tr>
<tr><td class="body">Kontak (opsional)</td><td class="write short"></td><td class="write short"></td></tr>
<tr><td class="body">Tanggal</td><td class="write short"></td><td class="write short"></td></tr>
<tr><td class="body">Tanda tangan</td><td class="write sigbox"></td><td class="write sigbox"></td></tr>
</tbody></table>
<h3>Rekap per tahap</h3>
<table class="items">
<colgroup><col><col style="width:48mm"><col style="width:48mm"></colgroup>
<thead><tr><th>Tahap</th><th>Peninjau 1</th><th>Peninjau 2</th></tr></thead>
<tbody>
${[for (final l in lessons) '<tr><td class="body">Tahap ${l['level']} · ${_inline(l['title'] as String)}</td>'
        '<td class="mark">☐ Layak ☐ Perbaiki ☐ Belum</td><td class="mark">☐ Layak ☐ Perbaiki ☐ Belum</td></tr>'].join('\n')}
<tr><td class="body">Bagian B · nama 17 hukum</td><td class="mark">☐ Layak ☐ Perbaiki ☐ Belum</td><td class="mark">☐ Layak ☐ Perbaiki ☐ Belum</td></tr>
<tr><td class="body">Bagian C · penjelasan cara membaca</td><td class="mark">☐ Selesai ditulis</td><td class="mark">☐ Selesai ditinjau</td></tr>
</tbody></table>
</section>''';
}

// ---------------------------------------------------------------- dokumen

const _css = r'''
@font-face { font-family: "AmiriQuran"; src: url("../../../assets/fonts/AmiriQuran-Regular.ttf") format("truetype"); }
@page { size: A4; margin: 14mm 12mm; }
* { box-sizing: border-box; }
body { font: 10.5pt/1.5 "Segoe UI", Arial, sans-serif; color: #1b1c1c; margin: 0; }
h1 { font-size: 22pt; margin: 0 0 4px; color: #003527; }
h2 { font-size: 15pt; margin: 0 0 6px; color: #003527; }
h3 { font-size: 11pt; margin: 14px 0 4px; }
.muted { color: #5b625f; font-size: 9pt; }
.meta { color: #5b625f; font-size: 9pt; margin: 0 0 6px; }
.ar { font-family: "AmiriQuran", "Amiri", serif; font-size: 14pt; line-height: 2; }
.ar.big { font-size: 17pt; }
mark { background: #fed65b; padding: 0 2px; border-radius: 3px; }
.cover { padding: 8mm 0 4mm; }
.box { border: 1.5px solid #003527; border-radius: 8px; padding: 10px 14px; margin: 12px 0; background: #f4f8f5; }
.box.warn-box { border-color: #8a4b00; background: #fff6e8; }
.box ol { margin: 6px 0 0 18px; padding: 0; }
.box li { margin: 4px 0; }
.lesson { page-break-before: always; }
.prov { border-left: 4px solid #8a4b00; background: #fff6e8; padding: 8px 12px; margin: 10px 0; font-size: 9.5pt; }
table { border-collapse: collapse; width: 100%; }
table.items { margin-top: 8px; table-layout: fixed; }
table.items th, table.items td { border: 1px solid #b9c2bd; padding: 5px 6px; vertical-align: top; }
table.items thead { display: table-header-group; background: #e6efe9; }
table.items th { font-size: 9pt; text-align: left; }
table.items tr { page-break-inside: avoid; }
td.no { width: 15mm; font-size: 8.5pt; color: #5b625f; }
td.type { width: 20mm; font-size: 8.5pt; color: #5b625f; }
td.mark { width: 26mm; font-size: 9pt; white-space: nowrap; }
td.note { width: 42mm; }
td.write { height: 26mm; }
td.write.short { height: 9mm; }
td.write.sigbox { height: 22mm; }
tr.fill td.write { height: 34mm; }
.h { font-weight: 700; margin-bottom: 2px; }
.ref { font-weight: 600; font-size: 9pt; }
.verse { margin: 2px 0; text-align: right; }
.note-app { font-size: 9pt; }
.keytag { background: #003527; color: #fff; font-size: 7.5pt; padding: 0 5px; border-radius: 8px; }
.opts { margin: 4px 0 4px 20px; padding: 0; }
.warn { color: #b00020; font-weight: 700; }
table.letters td { border: 0; padding: 1px 8px 1px 0; }
.verdict { margin-top: 12px; padding: 8px 12px; border: 1px dashed #5b625f; border-radius: 6px; }
code { background: #eef2ef; padding: 0 4px; border-radius: 4px; font-size: 9pt; }
''';

String _doc(String title, String body) =>
    '''<!doctype html>
<html lang="id"><head><meta charset="utf-8"><title>${_esc(title)}</title>
<style>$_css</style></head><body>
$body
</body></html>
''';

String _reviewPackage(
  _Quran q,
  List<Map<String, dynamic>> lessons,
  Map<String, dynamic> cur,
) {
  final counts = <String, int>{};
  var total = 0;
  for (final l in lessons) {
    for (final b in (l['blocks'] as List).cast<Map<String, dynamic>>()) {
      counts.update(b['type'] as String, (v) => v + 1, ifAbsent: () => 1);
      total++;
    }
  }
  final rules = _ruleNames();
  final sections = [for (final l in lessons) _lessonSection(q, l)].join('\n');
  final cover =
      '''
<section class="cover">
<h1>Paket Peninjauan Materi Tajwid MyQuran</h1>
<p><strong>Tahap $_firstLevel–16 · berstatus DRAF · belum diterbitkan</strong><br>
<span class="muted">Dibuat ${_today()} dari <code>assets/learn/curriculum.json</code> (versi ${_esc('${cur['version']}')}) ·
${lessons.length} tahap · $total butir (${counts.entries.map((e) => '${_typeLabel[e.key]} ${e.value}').join(', ')})</span></p>

<div class="box warn-box">
<strong>Mohon dibaca dulu, ini penting.</strong>
<ol>
<li>Materi di paket ini <strong>ditulis oleh asisten AI</strong> atas permintaan pemilik aplikasi. Hal ini tercatat di
catatan penyusun pada tiap tahap. Karena itu isinya <strong>tidak boleh dianggap benar</strong> sebelum
Bapak/Ibu periksa. AI bisa keliru pada rincian hukum, jumlah harakat, penamaan istilah, dan pilihan contoh.</li>
<li>Rujukan yang dinyatakan penyusun draf adalah <em>Tuhfatul Athfal</em> (Sulaiman al-Jamzuri) dan
<em>Al-Muqaddimah al-Jazariyyah</em> (Ibnul Jazari). Mohon cocokkan dengan kitab yang Bapak/Ibu pakai, dan
tulis rujukan Bapak/Ibu sendiri (kitab, bab/halaman) di kolom catatan, terutama bila ada yang berbeda.</li>
<li>Teks ayat Al-Qur'an di paket ini <strong>tidak diketik</strong>; diambil otomatis dari dataset Tanzil
(Uthmani 1.0.2). Kata yang diberi warna kuning adalah kata yang ditunjuk contoh di aplikasi. Yang perlu
diperiksa adalah <em>apakah contoh itu tepat</em> untuk hukum yang dijelaskan.</li>
<li>Isi tidak akan tampil di aplikasi sebelum <strong>dua peninjau</strong> menyetujuinya. Butir yang ditandai
Perbaiki atau Salah tetap tersembunyi sampai diperbaiki. <strong>Perbaikan ditulis atau dibenarkan oleh peninjau,
bukan oleh AI.</strong></li>
</ol>
</div>

<div class="box">
<strong>Cara mengisi</strong>
<ol>
<li><strong>Benar</strong>: sesuai kitab dan layak tampil apa adanya.</li>
<li><strong>Perbaiki</strong>: pada dasarnya benar, tetapi redaksi atau rincian perlu diubah. Tuliskan perbaikannya di kolom catatan.</li>
<li><strong>Salah</strong>: tidak benar atau tidak layak tampil. Mohon beri alasan singkat.</li>
<li><strong>Ragu</strong>: Bapak/Ibu tidak yakin dan perlu rujukan lain. Lebih baik jujur ragu daripada menyetujui.</li>
<li>Soal pilihan ganda: periksa juga <em>kunci jawaban</em> (diberi tanda) dan penjelasannya.</li>
<li>Sebut nomor butir (misalnya <strong>T10.07</strong>) bila mengirim catatan lewat chat atau surat.
Foto atau pindaian lembar yang sudah diisi sudah cukup.</li>
</ol>
</div>

<h3>Isi paket</h3>
<ul>
${[for (final l in lessons) '<li>Tahap ${l['level']} · ${_inline(l['title'] as String)} (${(l['blocks'] as List).length} butir)</li>'].join('\n')}
<li>Bagian B · nama 17 hukum tajwid (${rules.length} butir)</li>
<li>Bagian C · penjelasan cara membaca, <strong>diisi guru</strong></li>
<li>Lembar pengesahan dua peninjau</li>
</ul>
<p class="muted">Audio contoh belum direkam; slot-nya dibahas di dokumen terpisah
(<em>Panduan rekaman audio</em>) dan tidak dinilai di paket ini.</p>
</section>''';
  return _doc(
    'Paket Peninjauan Materi Tajwid MyQuran, Tahap 6-16 (DRAF)',
    '$cover\n$sections\n${_partB(rules)}\n${_partC(rules)}\n${_signature(lessons)}',
  );
}

// ------------------------------------------------------------ panduan rekaman

String _recordingGuide(List<Map<String, dynamic>> all) {
  final slots =
      <
        ({
          int level,
          String review,
          String title,
          int block,
          String label,
          String? asset,
        })
      >[];
  for (final l in all) {
    final blocks = (l['blocks'] as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i]['type'] == 'audio') {
        slots.add((
          level: (l['level'] as int?) ?? 0,
          review: l['review'] as String,
          title: l['title'] as String,
          block: i + 1,
          label: blocks[i]['label'] as String,
          asset: blocks[i]['asset'] as String?,
        ));
      }
    }
  }
  final published = slots.where((s) => s.review == 'published').length;
  final rows = [
    for (var i = 0; i < slots.length; i++)
      '<tr><td class="no">R.${_pad(i + 1)}</td>'
          '<td class="body">Tahap ${slots[i].level} · ${_inline(slots[i].title)}<br>'
          '<span class="muted">blok ke-${slots[i].block} · status ${slots[i].review == 'published' ? '<strong>terbit</strong> (tampil di rilis)' : 'draf'}</span></td>'
          '<td class="body"><strong>${_inline(slots[i].label)}</strong></td>'
          '<td class="write short"></td><td class="mark">☐ Direkam<br>☐ Diperiksa</td></tr>',
  ].join('\n');
  return _doc('Panduan rekaman audio MyQuran', '''
<section class="cover">
<h1>Panduan Rekaman Audio MyQuran</h1>
<p><span class="muted">Dibuat ${_today()} · ${slots.length} slot audio ($published di tahap yang sudah terbit, ${slots.length - published} di tahap draf)</span></p>

<div class="box warn-box"><strong>Aturan yang tidak boleh dilanggar</strong>
<ol>
<li>Rekaman <strong>wajib suara manusia yang berizin</strong>. Aplikasi ini <strong>tidak memakai suara buatan</strong>
(TTS atau AI) untuk contoh bunyi. Selama belum ada rekaman, layarnya jujur menampilkan "sedang disiapkan".</li>
<li>Yang merekam sebaiknya guru Al-Qur'an atau tajwid yang bacaannya bisa dipertanggungjawabkan. Isi tiap rekaman
(huruf apa, kata apa, berapa kali) <strong>ditentukan guru</strong>, bukan oleh pembuat aplikasi.</li>
<li>Sebelum direkam, penutur menandatangani surat izin (templat di halaman terakhir).</li>
</ol></div>

<h3>Slot yang perlu direkam</h3>
<p>Satu slot sama dengan <strong>satu berkas audio</strong>. Itulah yang didukung aplikasi sekarang: tiap blok audio
menunjuk satu berkas. Kalau guru ingin berkas terpisah per huruf atau per contoh, aplikasi perlu diubah dulu
(belum dikerjakan).</p>
<table class="items">
<colgroup><col style="width:15mm"><col style="width:48mm"><col><col style="width:42mm"><col style="width:24mm"></colgroup>
<thead><tr><th>No</th><th>Pelajaran</th><th>Label di aplikasi</th><th>Isi rekaman (diisi guru)</th><th>Status</th></tr></thead>
<tbody>
$rows
</tbody></table>
<p class="muted">Utamakan slot di tahap yang sudah terbit (R.01–R.${_pad(published)}): itu yang dilihat pengguna rilis hari ini.</p>

<h3>Saran teknis (bukan aturan agama)</h3>
<ul>
<li>Format <strong>M4A (AAC)</strong>, mono, 44,1 kHz, sekitar 96 kbps. MP3 atau WAV juga bisa diputar aplikasi.</li>
<li>Rekam di ruangan sepi, mikrofon dekat dan stabil, tanpa kipas atau gema. Ponsel yang baik cukup.</li>
<li>Sisakan hening sekitar 0,3 detik di awal dan akhir. Volume konsisten antar-rekaman, tanpa pecah (clipping).</li>
<li>Tiap berkas sebaiknya di bawah 1 MB supaya ukuran aplikasi tidak membengkak.</li>
<li>Nama berkas memakai huruf kecil tanpa spasi, mis. <code>tahap01_huruf.m4a</code>.</li>
</ul>

<h3>Untuk pemilik aplikasi: cara memasang rekaman</h3>
<ol>
<li>Taruh berkas di <code>assets/learn/audio/</code> dan tambahkan <code>- assets/learn/audio/</code> di bagian
<code>assets:</code> pada <code>pubspec.yaml</code> (folder itu belum terdaftar).</li>
<li>Di <code>assets/learn/curriculum.json</code>, isi <code>"asset"</code> pada blok audio yang bersangkutan, mis.
<code>"asset": "assets/learn/audio/tahap01_huruf.m4a"</code>.</li>
<li>Catat nama penutur, tanggal, dan jenis izin di <code>docs/design/v3/LISENSI_ASET.md</code> dan di layar
<em>Sumber &amp; lisensi</em>. Jalankan <code>flutter analyze</code> dan <code>flutter test</code>.</li>
</ol>
</section>

<section class="lesson">
<h2>Templat surat izin penggunaan rekaman suara</h2>
<p class="muted">Templat umum; sesuaikan bila perlu. Bukan nasihat hukum.</p>
<p>Saya yang bertanda tangan di bawah ini:</p>
<p>Nama: ........................................................<br>
Pekerjaan / lembaga: ........................................<br>
Kualifikasi mengajar Al-Qur'an / tajwid: ......................................</p>
<p>memberikan izin kepada <strong>Zainul Arkaan</strong> (pengembang aplikasi <strong>MyQuran</strong>) untuk memakai
rekaman suara saya sebagai contoh bunyi di aplikasi MyQuran, dengan ketentuan:</p>
<ol>
<li>Aplikasi bersifat <strong>gratis, tanpa iklan, tanpa pembelian</strong>, dan rekaman tidak dijual terpisah.</li>
<li>Rekaman boleh didistribusikan sebagai bagian dari aplikasi (di GitHub, Google Play, atau situs resmi aplikasi).</li>
<li>Nama saya dicantumkan sebagai penutur di layar <em>Sumber &amp; lisensi</em>: &#9744; ya &nbsp; &#9744; tidak, mohon dirahasiakan.</li>
<li>Izin berlaku &#9744; selamanya &nbsp; &#9744; sampai tanggal ................. &nbsp; dan dapat saya cabut dengan pemberitahuan tertulis;
rekaman akan dihapus dari pembaruan berikutnya.</li>
<li>Saya merekam isi yang saya yakini benar menurut ilmu dan rujukan saya, dan bersedia menjelaskan rujukannya bila ditanya.</li>
</ol>
<p>Tempat, tanggal: ..............................</p>
<table class="items sig"><tr><td class="write sigbox">Penutur<br><br><br>( ................................ )</td>
<td class="write sigbox">Pengembang<br><br><br>( Zainul Arkaan )</td></tr></table>
</section>''');
}

// --------------------------------------------------------------------- main

void main() {
  if (!File('assets/learn/curriculum.json').existsSync()) {
    stderr.writeln(
      'Jalankan dari akar repo: dart run tool/export_review_package.dart',
    );
    exit(64);
  }
  final cur =
      jsonDecode(File('assets/learn/curriculum.json').readAsStringSync())
          as Map<String, dynamic>;
  final all = (cur['lessons'] as List).cast<Map<String, dynamic>>();
  final drafts = [
    for (final l in all)
      if (l['review'] == 'draft' && ((l['level'] as int?) ?? 0) >= _firstLevel)
        l,
  ]..sort((a, b) => (a['level'] as int).compareTo(b['level'] as int));
  if (drafts.isEmpty) {
    stderr.writeln('Tidak ada pelajaran draf tahap >= $_firstLevel.');
    exit(1);
  }
  final q = _Quran.load();
  Directory(_outDir).createSync(recursive: true);
  File(
    '$_outDir/paket-peninjau-tajwid-tahap-6-16.html',
  ).writeAsStringSync(_reviewPackage(q, drafts, cur));
  File(
    '$_outDir/panduan-rekaman-audio.html',
  ).writeAsStringSync(_recordingGuide(all));
  stdout.writeln('Selesai: ${drafts.length} tahap draf, tulis ke $_outDir/');
  if (_problems.isNotEmpty) {
    stderr.writeln('MASALAH (${_problems.length}):');
    _problems.forEach(stderr.writeln);
    exit(2);
  }
}
