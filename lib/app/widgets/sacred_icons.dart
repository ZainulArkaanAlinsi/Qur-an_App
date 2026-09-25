/// Path ikon, disalin dari mockup di
/// `quran-ios-redesign-handoff/docs/design/ios-redesign/html/`.
///
/// Ikon bawaan Flutter bentuknya berbeda dari acuan, jadi yang dipakai path
/// aslinya. Elemen `<circle cx cy r>` pada mockup ditulis di sini sebagai dua
/// busur setengah lingkaran yang setara, karena pengurai hanya menerima path.
///
/// Jangan "merapikan" angka di berkas ini. Kalau mockup berubah, salin ulang
/// dari HTML-nya supaya tetap sama persis.
abstract final class SacredIcons {
  /// Lebar garis yang dipakai mockup untuk tiap kelompok ikon.
  static const strokeNav = 1.8;
  static const strokeNavActive = 2.1;
  static const strokeAction = 2.0;
  static const strokeBookmark = 1.9;

  static const bookmark = ['M6.5 3.5h11v17l-5.5-3.8-5.5 3.8z'];

  static const book = [
    'M2.5 5.5c3-1.4 6.6-1.2 9.5 1 2.9-2.2 6.5-2.4 9.5-1v13.4'
        'c-3-1.4-6.6-1.2-9.5 1-2.9-2.2-6.5-2.4-9.5-1z',
    'M12 6.5v13.4',
  ];

  static const checkCircle = [
    'M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17z',
    'm8.3 12.2 2.6 2.6 4.8-5.3',
  ];

  static const home = [
    'M4 10.5 12 4l8 6.5V19a1.5 1.5 0 0 1-1.5 1.5H15v-5.5a3 3 0 0 0-6 0v5.5'
        'H5.5A1.5 1.5 0 0 1 4 19z',
  ];

  static const chart = ['M5 20v-6', 'M12 20V5', 'M19 20v-10'];

  static const sliders = [
    'M4 7h9',
    'M19 7h1',
    'M16 4.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5z',
    'M4 17h3',
    'M13 17h7',
    'M10 14.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5z',
  ];

  static const search = [
    'M11 4.5a6.5 6.5 0 1 0 0 13 6.5 6.5 0 0 0 0-13z',
    'm20 20-4.2-4.2',
  ];

  static const headphones = [
    'M4 15v-3a8 8 0 0 1 16 0v3',
    'M4 15h3v5H5.5A1.5 1.5 0 0 1 4 18.5z',
    'M20 15h-3v5h1.5a1.5 1.5 0 0 0 1.5-1.5z',
  ];

  /// Ikon isi, bukan garis.
  static const play = [
    'M8.5 5.3v13.4a1 1 0 0 0 1.5.86l10.4-6.7a1 1 0 0 0 0-1.72L10 4.44'
        'a1 1 0 0 0-1.5.86z',
  ];

  static const flame = [
    'M12 3c.8 3.6 5 5.2 5 10.2a5 5 0 0 1-10 0c0-2.4 1.3-3.6 2-5.2'
        '.9 1.4 1.9 2 1.9 2C10.9 7 12 5 12 3z',
  ];

  static const sun = [
    'M12 8.2a3.8 3.8 0 1 0 0 7.6 3.8 3.8 0 0 0 0-7.6z',
    'M12 2.8v2M12 19.2v2M2.8 12h2M19.2 12h2M5.5 5.5l1.4 1.4'
        'M17.1 17.1l1.4 1.4M5.5 18.5l1.4-1.4M17.1 6.9l1.4-1.4',
  ];

  static const chevronLeft = ['M15 18.5 8.5 12 15 5.5'];
  static const chevronDown = ['m6 9.5 6 6 6-6'];
  static const chevronRight = ['m9.5 6 6 6-6 6'];

  /// Panah ke kanan untuk jalur menu ("Saya → Belajar").
  static const arrowRight = ['M5 12h14', 'm13 6 6 6-6 6'];
  static const close = ['M6 6l12 12M18 6 6 18'];

  /// Tiga titik mendatar.
  static const more = [
    'M6 10.8a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4z',
    'M12 10.8a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4z',
    'M18 10.8a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4z',
  ];

  /// Dua batang jeda; dipakai dengan `filled: true`.
  static const pause = [
    'M7.4 4.5h1.2a1.4 1.4 0 0 1 1.4 1.4v12.2a1.4 1.4 0 0 1-1.4 1.4H7.4'
        'a1.4 1.4 0 0 1-1.4-1.4V5.9a1.4 1.4 0 0 1 1.4-1.4z',
    'M15.4 4.5h1.2a1.4 1.4 0 0 1 1.4 1.4v12.2a1.4 1.4 0 0 1-1.4 1.4h-1.2'
        'a1.4 1.4 0 0 1-1.4-1.4V5.9a1.4 1.4 0 0 1 1.4-1.4z',
  ];

  /// Bookmark versi isi, untuk ayat yang sudah disimpan.
  static const bookmarkFilled = ['M6.5 3.5h11v17l-5.5-3.8-5.5 3.8z'];

  /// Huruf besar-kecil, untuk tombol Tampilan bacaan.
  static const textSize = [
    'M4 18 8.5 6 13 18',
    'M5.6 14h5.8',
    'M15 18l3-8 3 8',
    'M16 15.5h4',
  ];

  /// Bulan sabit, untuk Mode fokus.
  static const moon = [
    'M20.5 13.2A8.5 8.5 0 1 1 10.8 3.5a6.6 6.6 0 0 0 9.7 9.7z',
  ];

  static const translate = [
    'M3.5 5.5h9',
    'M8 3.5v2',
    'M5.5 5.5c.8 3.8 3.6 6.6 6.8 7.6',
    'M10.5 5.5c-.8 3.8-3.4 6.6-6.5 7.6',
    'm12.5 20.5 4-9 4 9',
    'M14 17.5h5',
  ];

  static const repeat = [
    'm17 2.5 3 3-3 3',
    'M4 11.5v-1a5 5 0 0 1 5-5h11',
    'm7 21.5-3-3 3-3',
    'M20 12.5v1a5 5 0 0 1-5 5H4',
  ];

  static const timer = [
    'M12 5.5a7.5 7.5 0 1 0 0 15 7.5 7.5 0 0 0 0-15z',
    'M12 9.5V13h3',
    'M9.5 2.5h5',
  ];

  static const download = [
    'M12 3.5v11',
    'm7.5 10 4.5 4.5 4.5-4.5',
    'M5 20.5h14',
  ];

  static const share = [
    'M12 3.5v12',
    'm7.5 8 4.5-4.5L16.5 8',
    'M5 13v6.5h14V13',
  ];

  static const pin = [
    'M12 21s6.5-5.8 6.5-11A6.5 6.5 0 0 0 5.5 10c0 5.2 6.5 11 6.5 11z',
    'M12 7.7a2.3 2.3 0 1 0 0 4.6 2.3 2.3 0 0 0 0-4.6z',
  ];

  static const bell = ['M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15z', 'M10 21h4'];

  static const cloud = [
    'M7 18.5a4.5 4.5 0 0 1-.5-9A6 6 0 0 1 18 8.5a4 4 0 0 1 0 10z',
  ];

  static const palette = [
    'M12 3.5a8.5 8.5 0 0 0 0 17c1.2 0 1.7-.8 1.7-1.6 0-1.1-.9-1.5-.9-2.5'
        'c0-.9.7-1.6 1.6-1.6h2.1a4 4 0 0 0 4-4c0-4.2-3.8-7.3-8.5-7.3z',
    'M8 10a1 1 0 1 0 0 2 1 1 0 0 0 0-2z',
    'M11 6.5a1 1 0 1 0 0 2 1 1 0 0 0 0-2z',
    'M15.5 7.5a1 1 0 1 0 0 2 1 1 0 0 0 0-2z',
  ];

  static const previous = ['M19 19 10 12l9-7z', 'M5.5 5v14'];
  static const next = ['m5 5 9 7-9 7z', 'M18.5 5v14'];

  // Ikon tambahan paket desain v2 (`docs/design/v2/html/`).

  /// Toga: tab Belajar dan baris "Lanjutkan belajar".
  static const cap = [
    'M2.5 9 12 4.5 21.5 9 12 13.5z',
    'M6.5 11v5c0 1.5 2.5 3 5.5 3s5.5-1.5 5.5-3v-5',
  ];

  /// Tumpukan lapis: tab Hafalan dan murajaah.
  static const layers = [
    'M12 3.5 21 8l-9 4.5L3 8z',
    'M3 12.5 12 17l9-4.5',
    'M3 16.5 12 21l9-4.5',
  ];

  static const user = [
    'M12 4a4 4 0 1 0 0 8 4 4 0 0 0 0-8z',
    'M4.5 20.5a7.5 7.5 0 0 1 15 0',
  ];

  static const info = [
    'M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17z',
    'M12 11v5.5',
    'M12 7.8h.01',
  ];

  static const plus = ['M12 5v14M5 12h14'];

  static const mic = [
    'M12 3a3 3 0 0 0-3 3v5a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3z',
    'M5.5 11a6.5 6.5 0 0 0 13 0',
    'M12 17.5v3',
  ];

  static const calendar = [
    'M6 5h12a2.5 2.5 0 0 1 2.5 2.5V18a2.5 2.5 0 0 1-2.5 2.5H6'
        'A2.5 2.5 0 0 1 3.5 18V7.5A2.5 2.5 0 0 1 6 5z',
    'M3.5 10h17M8 3v4M16 3v4',
  ];

  static const compass = [
    'M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17z',
    'm15.5 8.5-2 5-5 2 2-5z',
  ];

  static const eyeOff = [
    'M3 3l18 18',
    'M10.6 5.1A10 10 0 0 1 21 12a13 13 0 0 1-2.2 3.2M6.2 6.3A13 13 0 0 0 3 12'
        's3.5 6.5 9 6.5a9 9 0 0 0 4-.9',
    'M9.9 9.9a3 3 0 0 0 4.2 4.2',
  ];

  /// Mode baca: satu halaman, dua halaman, kartu ayat.
  static const pageSingle = [
    'M8 3.5h8a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2v-13'
        'a2 2 0 0 1 2-2z',
    'M9 8h6M9 11h6M9 14h6',
  ];
  static const pageDouble = [
    'M4 5h6a1.5 1.5 0 0 1 1.5 1.5v11A1.5 1.5 0 0 1 10 19H4'
        'a1.5 1.5 0 0 1-1.5-1.5v-11A1.5 1.5 0 0 1 4 5z',
    'M14 5h6a1.5 1.5 0 0 1 1.5 1.5v11A1.5 1.5 0 0 1 20 19h-6'
        'a1.5 1.5 0 0 1-1.5-1.5v-11A1.5 1.5 0 0 1 14 5z',
  ];
  static const cards = [
    'M6 4h12a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z',
    'M6 13h12a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-3'
        'a2 2 0 0 1 2-2z',
  ];

  /// Putar HP ke mendatar (tombol "2 halaman" di mushaf).
  static const rotate = [
    'M3 12a9 9 0 0 1 15.5-6.2L21 8',
    'M21 3.5V8h-4.5',
    'M9.5 10h5a1.5 1.5 0 0 1 1.5 1.5v8a1.5 1.5 0 0 1-1.5 1.5h-5'
        'A1.5 1.5 0 0 1 8 19.5v-8A1.5 1.5 0 0 1 9.5 10z',
  ];
}
