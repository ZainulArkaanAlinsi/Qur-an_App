/// Hukum tajwid yang dikenali dari anotasi `text_uthmani_tajweed`
/// Quran Foundation. Daftar ini adalah whitelist: class lain ditolak parser.
///
/// Nama Indonesia berstatus [ContentReviewStatus.draft] sampai diperiksa guru
/// tajwid (lihat docs/RELIGIOUS_CONTENT_GOVERNANCE.md). Pemetaan
/// `madda_permissible` dan `madda_obligatory` khususnya perlu dikonfirmasi,
/// karena provider tidak membedakan jenis mad jaiz/wajib secara lebih rinci.
enum TajweedRule {
  hamzahWasl('ham_wasl', 'Hamzah Washal'),
  lamSyamsiyah('laam_shamsiyah', 'Lam Syamsiyah'),
  silent('slnt', 'Huruf tidak dibaca'),
  madThabii('madda_normal', "Mad Thabi'i"),
  madJaiz('madda_permissible', 'Mad Jaiz'),
  madWajib('madda_obligatory', 'Mad Wajib'),
  madLazim('madda_necessary', 'Mad Lazim'),
  qalqalah('qalaqah', 'Qalqalah'),
  ikhfaHaqiqi('ikhafa', 'Ikhfa Haqiqi'),
  ikhfaSyafawi('ikhafa_shafawi', 'Ikhfa Syafawi'),
  idghamBighunnah('idgham_ghunnah', 'Idgham Bighunnah'),
  idghamBilaghunnah('idgham_wo_ghunnah', 'Idgham Bilaghunnah'),
  idghamMimi('idgham_shafawi', 'Idgham Mimi'),
  idghamMutajanisain('idgham_mutajanisayn', 'Idgham Mutajanisain'),
  idghamMutaqaribain('idgham_mutaqaribayn', 'Idgham Mutaqaribain'),
  iqlab('iqlab', 'Iqlab'),
  ghunnah('ghunnah', 'Ghunnah');

  const TajweedRule(this.providerClass, this.nameId);

  /// Nilai atribut `class` persis seperti dikirim provider.
  final String providerClass;

  /// Nama hukum dalam bahasa Indonesia (draft, belum direview).
  final String nameId;

  static final Map<String, TajweedRule> _byClass = {
    for (final rule in values) rule.providerClass: rule,
  };

  /// Mengembalikan `null` untuk class di luar whitelist.
  static TajweedRule? fromProviderClass(String value) => _byClass[value];
}

/// Status tata kelola konten agama.
enum ContentReviewStatus { draft, reviewed, approved, published, archived }

/// Status review untuk seluruh nama hukum pada [TajweedRule].
const tajweedRuleNamesReviewStatus = ContentReviewStatus.draft;
