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
}
