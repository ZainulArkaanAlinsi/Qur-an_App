#!/usr/bin/env bash
# Audit statis liquid glass MyQuran (docs/design/v4-liquid-glass/LIQUID_GLASS.md).
# Jalankan dari akar repo:  bash tool/glass_audit.sh
# Keluar dengan kode = jumlah temuan GAGAL. Tidak mengubah berkas apa pun.
# Hanya pakai grep/awk/sed standar supaya jalan juga di Git Bash (Windows).

set -u
LIB=lib
GLASS_DIR="lib/app/glass"            # satu-satunya tempat BackdropFilter boleh ada
fail=0; warn=0
ok()   { printf '  \033[32mLULUS\033[0m  %s\n' "$1"; }
bad()  { printf '  \033[31mGAGAL\033[0m  %s\n' "$1"; fail=$((fail+1)); }
note() { printf '  \033[33mCEK  \033[0m  %s\n' "$1"; warn=$((warn+1)); }
list() { sed 's/^/           /'; }

echo "== A. Struktur =="

# A1. BackdropFilter hanya di komponen kaca.
hits=$(grep -rn --include='*.dart' -E 'BackdropFilter(\.grouped)?\(' "$LIB" | grep -v "^$GLASS_DIR/" || true)
if [ -z "$hits" ]; then ok "A1 BackdropFilter hanya di $GLASS_DIR/"
else bad "A1 BackdropFilter di luar $GLASS_DIR/ (pakai LiquidGlass):"; echo "$hits" | list; fi

# A2. Semua blur memakai BackdropFilter.grouped dan ada BackdropGroup.
plain=$(grep -rn --include='*.dart' -E 'BackdropFilter\(' "$LIB" | grep -v 'BackdropFilter\.grouped' || true)
group=$(grep -rln --include='*.dart' 'BackdropGroup(' "$LIB" || true)
if [ -z "$plain" ] && [ -n "$group" ]; then ok "A2 BackdropFilter.grouped + BackdropGroup dipakai"
else
  [ -n "$plain" ] && { bad "A2 BackdropFilter biasa (harus .grouped):"; echo "$plain" | list; }
  [ -z "$group" ] && bad "A2 Tidak ada BackdropGroup di mana pun"
fi

# A3. Kaca di dalam item daftar yang bergulir (itemBuilder / builder: ListView/SliverList).
files=$(grep -rl --include='*.dart' -E 'GlassSurface|LiquidGlass' "$LIB" 2>/dev/null || true)
lst=""
[ -n "$files" ] && lst=$(awk '
  FNR==1 { inb=0 }
  # Builder daftar punya dua argumen (context, index); PopupMenu hanya satu.
  /itemBuilder: *\( *[A-Za-z_]+ *, *[A-Za-z_]+ *\)|SliverChildBuilderDelegate\(/ { inb=30 }
  inb>0 { if ($0 ~ /(GlassSurface|LiquidGlass)\(/) print FILENAME":"FNR": "$0; inb-- }
' $files </dev/null || true)
if [ -z "$lst" ]; then ok "A3 Tidak ada kaca per item daftar"
else bad "A3 Kaca di dalam item daftar (tiap item = 1 blur, berat saat gulir):"; echo "$lst" | list; fi

# A4. Opacity / ShaderMask membungkus kaca memaksa saveLayer.
op=$(grep -rn --include='*.dart' -B3 -E '(GlassSurface|LiquidGlass)\(' "$LIB" | grep -E '(^|[^A-Za-z])(Opacity|ShaderMask)\(' || true)
if [ -z "$op" ]; then ok "A4 Tidak ada Opacity/ShaderMask tepat di atas kaca"
else bad "A4 Opacity/ShaderMask di atas kaca (pakai FadeTransition atau alfa warna):"; echo "$op" | list; fi

echo "== B. Warna & keterbacaan =="

# B1. Alfa token glass tidak boleh terlalu pekat (kaca jadi kaku). Palet kontras
#     tinggi dikecualikan karena selalu memakai tingkat "padat".
toks=$(ls lib/app/sacred_tokens.dart lib/app/glass/glass_tokens.dart 2>/dev/null)
if [ -n "$toks" ]; then
  b1=$(awk '
    FNR==1 { blk="" }
    /static const [A-Za-z]+ = (SacredTokens|GlassTokens)\(/ { match($0,/static const [A-Za-z]+/); blk=substr($0,RSTART+13,RLENGTH-13) }
    /^[ \t]*(glass|glassTint|tint):/ {
      if (blk ~ /highContrast/) next
      a=-1
      if (match($0,/0x[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/)) {
        hx=toupper(substr($0,RSTART+2,2))
        a=(index("0123456789ABCDEF",substr(hx,1,1))-1)*16+index("0123456789ABCDEF",substr(hx,2,1))-1
        a=a*100/255
      } else if (match($0,/alpha: *[01]?\.[0-9]+/)) {
        v=substr($0,RSTART,RLENGTH); sub(/alpha: */,"",v); a=v*100
      }
      if (a>60) printf "%s:%d token %s alfa %d%%\n", FILENAME, FNR, blk, int(a)
    }' $toks </dev/null)
  if [ -z "$b1" ]; then ok "B1 Alfa tint kaca <= 60% (kontras dijaga lapisan vibrancy + tes B4)"
  else bad "B1 Alfa kaca > 60%: terlihat seperti panel padat, bukan kaca"; echo "$b1" | list; fi
fi

# B2. Scrim padat di belakang tab bar membuat kaca tidak punya apa-apa untuk dibiaskan.
scrim=$(grep -rn --include='*.dart' -E 'colors: \[tokens\.bg, tokens\.bg' "$LIB" || true)
if [ -z "$scrim" ]; then ok "B2 Tidak ada scrim padat di belakang kaca"
else bad "B2 Scrim padat tokens.bg di belakang kaca:"; echo "$scrim" | list; fi

# B3. Warna mentah di komponen chrome kaca (harus dari SacredTokens / GlassTokens).
chrome="lib/widgets/audio_mini_player.dart $GLASS_DIR"
raw=$(grep -rn --include='*.dart' -E 'SacredTheme\.(primary|primaryContainer|gold)|Colors\.(white|black)[^0-9A-Za-z]' $chrome 2>/dev/null | grep -v '^\s*//' || true)
if [ -z "$raw" ]; then ok "B3 Chrome kaca hanya memakai token"
else bad "B3 Warna mentah di chrome kaca (tidak ikut terang/gelap/sepia/kontras tinggi):"; echo "$raw" | head -15 | list; fi

# B4. Tes kontras kaca & tajwid ada.
if grep -rqlE 'glass.*contrast|contrast.*glass|kontras.*kaca' test 2>/dev/null; then ok "B4 Tes kontras kaca ada"
else bad "B4 Belum ada tes kontras kaca (test/glass_contrast_test.dart)"; fi

echo "== C. Adaptif & kinerja =="

# C1. Tingkat kualitas + fallback aksesibilitas.
if grep -rqE 'enum GlassTier|GlassQuality' "$LIB"; then ok "C1 Tingkat kualitas kaca ada"
else bad "C1 Belum ada tingkat kualitas kaca (penuh/ringan/padat)"; fi
if grep -rqE 'highContrast' "$GLASS_DIR" 2>/dev/null && grep -rqE 'disableAnimations' "$GLASS_DIR" 2>/dev/null; then ok "C2 Kaca menghormati kontras tinggi & kurangi gerak"
else bad "C2 Kaca belum membaca MediaQuery highContrast/disableAnimations"; fi
if grep -rqE 'addTimingsCallback' "$LIB"; then ok "C3 Pengawas frame (turun tingkat otomatis) ada"
else bad "C3 Belum ada pengawas frame (SchedulerBinding.addTimingsCallback)"; fi
if ls integration_test/*glass* integration_test/*perf* >/dev/null 2>&1; then ok "C4 Tes kinerja integration_test ada"
else bad "C4 Belum ada integration_test kinerja (gulir pembaca + ganti tab)"; fi

# C5. Jumlah pemakaian kaca (informasi).
n=$(grep -rn --include='*.dart' -E '(GlassSurface|LiquidGlass)\(' "$LIB" | grep -v "^$GLASS_DIR/" | wc -l | tr -d ' ')
note "C5 $n pemakaian komponen kaca di luar $GLASS_DIR/ (periksa: hanya chrome mengambang)"

echo
echo "Ringkas: $fail GAGAL, $warn perlu dicek manual."
exit "$fail"
