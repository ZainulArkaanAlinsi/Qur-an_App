import 'package:quran_app_2025/core/bff/bff_client.dart';
import 'package:quran_app_2025/features/mushaf/data/bff_mushaf_source.dart';
import 'package:quran_app_2025/features/mushaf/data/mushaf_source.dart';
import 'package:quran_app_2025/features/mushaf/data/qf_debug_mushaf_source.dart';

/// Apakah mode halaman mushaf (1 dan 2 halaman) boleh ditawarkan.
///
/// Mode itu butuh data tata letak halaman dari Quran Foundation. Rilis hanya
/// memakainya lewat server perantara sendiri (BFF), yang memegang kredensial,
/// jadi mode ini **mati bawaan** dan hidup hanya bila build diberi alamat BFF
/// (`--dart-define=BFF_BASE_URL=...`). Build debug di perangkat boleh memanggil
/// api.quran.com langsung ([debugLayout]).
///
/// [bffConfigured] hanya untuk tes; bawaannya [isBffConfigured].
bool mushafModesAvailable({required bool debugLayout, bool? bffConfigured}) =>
    (bffConfigured ?? isBffConfigured) || debugLayout;

/// Sumber tata letak mushaf untuk build ini, atau `null` bila mode mushaf
/// tidak tersedia. Pemanggil wajib memanggil `dispose()` pada hasilnya.
///
/// BFF didahulukan di semua build; tanpa BFF, hanya build debug yang punya
/// sumber (langsung ke api.quran.com, tanpa kredensial).
MushafSource? createMushafSource({
  required bool debugLayout,
  bool? bffConfigured,
}) {
  if (bffConfigured ?? isBffConfigured) return BffMushafSource();
  if (debugLayout) return QfDebugMushafSource();
  return null;
}
