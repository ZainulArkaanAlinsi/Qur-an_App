# Build APK rilis dan sisakan SATU berkas di folder keluaran.
#
# Pemakaian:
#   pwsh tool/build_release.ps1
#
# Hasil: build/app/outputs/flutter-apk/myquran-<versi>.apk
# APK lama (debug, split-per-abi, versi sebelumnya) dihapus lebih dulu supaya
# folder tidak menumpuk dan tidak ada risiko mengunggah berkas yang salah.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$versionLine = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$'
if (-not $versionLine) { throw 'Versi tidak ditemukan di pubspec.yaml' }
$version = $versionLine.Matches[0].Groups[1].Value.Trim().Split('+')[0]

$outDir = Join-Path $root 'build/app/outputs/flutter-apk'
if (Test-Path $outDir) {
    Write-Host "Membersihkan APK lama di $outDir"
    Get-ChildItem $outDir -File | Where-Object {
        $_.Extension -in '.apk', '.sha1'
    } | Remove-Item -Force
}

# Hanya arsitektur ARM yang dibundel: x86_64 praktis cuma dipakai emulator dan
# sebagian Chromebook, dan menambah ~20 MB pada unduhan setiap pengguna.
# Filter abiFilters di Gradle diabaikan Flutter untuk APK gabungan, jadi
# pembatasannya harus lewat --target-platform.
# DISTRIBUTION=github: APK ini untuk GitHub Releases, jadi pengunduh pembaruan
# dan izin pasang APK ikut. Build Google Play (appbundle) tidak memakainya;
# lihat lib/app/distribution.dart dan docs/PLAY_STORE_RELEASE.md.
Write-Host "Build rilis GitHub versi $version (arm + arm64)"
flutter build apk --release --target-platform android-arm,android-arm64 --dart-define=DISTRIBUTION=github
if ($LASTEXITCODE -ne 0) { throw 'flutter build apk gagal' }

$built = Join-Path $outDir 'app-release.apk'
# Pemeriksa pembaruan memilih berkas .apk mana pun di rilis, jadi nama baru
# aman bagi pengguna versi lama.
$final = Join-Path $outDir "myquran-$version.apk"
Move-Item $built $final -Force
Remove-Item (Join-Path $outDir 'app-release.apk.sha1') -Force -ErrorAction SilentlyContinue

$hash = (Get-FileHash $final -Algorithm SHA256).Hash
$size = (Get-Item $final).Length

Write-Host ''
Write-Host "Berkas : $final"
Write-Host "Ukuran : $size byte"
Write-Host "SHA-256: $hash"
Write-Host ''
Write-Host 'Verifikasi tanda tangan (sesuaikan versi build-tools):'
Write-Host "  & `"$env:LOCALAPPDATA\Android\Sdk\build-tools\<versi>\apksigner.bat`" verify --print-certs `"$final`""
Write-Host 'Sertifikat SHA-256 harus sama dengan yang tercatat di docs/RELEASE.md.'
