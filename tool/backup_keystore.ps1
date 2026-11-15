<#
.SYNOPSIS
  Mencadangkan kunci rilis MyQuran ke satu arsip 7-Zip terenkripsi.

.DESCRIPTION
  Kunci rilis (.jks) dan android\key.properties tidak boleh hilang: tanpa
  keduanya, APK GitHub tidak bisa diperbarui di atas versi lama (docs/RELEASE.md).
  Skrip ini membuat satu arsip .7z dengan enkripsi AES-256 dan nama berkas ikut
  terenkripsi. Kata sandi diminta langsung oleh 7-Zip di jendela ini, jadi tidak
  pernah lewat skrip, riwayat perintah, atau daftar proses.

  Skrip ini TIDAK mengunggah apa pun. Salin arsipnya sendiri ke minimal dua
  tempat terpisah (flashdisk dan penyimpanan cloud pribadi). Aman diunggah
  karena terenkripsi, selama kata sandinya kuat dan kamu ingat.

.PARAMETER Keystore
  Jalur berkas .jks. Bawaan: $env:USERPROFILE\keystores\ruang-tilawah-release.jks

.PARAMETER KeyProperties
  Jalur android\key.properties. Bawaan: relatif terhadap akar repo.

.PARAMETER Out
  Tempat arsip ditulis. Bawaan: Desktop.

.PARAMETER DryRun
  Hanya menampilkan apa yang akan dilakukan; tidak membuat apa pun.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\backup_keystore.ps1
#>
param(
  [string]$Keystore = (Join-Path $env:USERPROFILE 'keystores\ruang-tilawah-release.jks'),
  [string]$KeyProperties = (Join-Path (Split-Path $PSScriptRoot -Parent) 'android\key.properties'),
  [string]$Out = [Environment]::GetFolderPath('Desktop'),
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$sevenZip = @(
  (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
  (Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe')
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $sevenZip) { throw '7-Zip tidak ditemukan. Pasang dari https://www.7-zip.org lalu ulangi.' }

foreach ($f in @($Keystore, $KeyProperties)) {
  if (-not (Test-Path $f)) { throw "Berkas tidak ditemukan: $f" }
}

$stamp = Get-Date -Format 'yyyy-MM-dd'
$archive = Join-Path $Out "myquran-kunci-rilis-$stamp.7z"
if (Test-Path $archive) { throw "Arsip sudah ada, tidak ditimpa: $archive" }

Write-Host "7-Zip      : $sevenZip"
Write-Host "Keystore   : $Keystore"
Write-Host "Properti   : $KeyProperties"
Write-Host "Arsip      : $archive"

if ($DryRun) {
  Write-Host ''
  Write-Host 'DryRun: tidak ada yang dibuat. Tanpa -DryRun, 7-Zip akan meminta kata sandi di sini.'
  return
}

Write-Host ''
Write-Host 'Ketik kata sandi arsip saat diminta 7-Zip (tidak tampil di layar).'
& $sevenZip a -t7z -mhe=on -mx=9 -p $archive $Keystore $KeyProperties
if ($LASTEXITCODE -ne 0) { throw "7-Zip gagal (kode $LASTEXITCODE)" }

$hash = (Get-FileHash $archive -Algorithm SHA256).Hash
$size = [math]::Round((Get-Item $archive).Length / 1KB, 1)
Write-Host ''
Write-Host "Selesai: $archive ($size KB)"
Write-Host "SHA-256 arsip: $hash"
Write-Host ''
Write-Host 'Langkah berikutnya, wajib:'
Write-Host ' 1. Salin arsip ke flashdisk DAN ke penyimpanan cloud pribadi.'
Write-Host ' 2. Uji: buka arsip dengan kata sandimu dan pastikan kedua berkas ada.'
Write-Host ' 3. Simpan kata sandi di pengelola kata sandi, bukan di repo atau catatan biasa.'
