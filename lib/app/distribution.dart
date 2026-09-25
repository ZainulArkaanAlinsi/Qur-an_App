/// Saluran distribusi build ini.
///
/// Bawaan: Google Play, yang memperbarui aplikasi lewat Play sendiri. Build
/// untuk GitHub Releases dibuat dengan `--dart-define=DISTRIBUTION=github`;
/// flag yang sama juga menambahkan izin pasang APK di manifest Android
/// (android/app/build.gradle.kts). Kebijakan Google Play melarang aplikasi
/// dari Play memperbarui dirinya di luar Play, jadi pengunduh APK hanya aktif
/// di build GitHub.
const bool isGithubBuild = String.fromEnvironment('DISTRIBUTION') == 'github';
