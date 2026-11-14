// Mengisi versi, ukuran, dan SHA-256 APK dari rilis GitHub terbaru.
// Tanpa pelacak. Bila GitHub tidak terjangkau, tautan unduh statis di HTML tetap bekerja.
(function () {
  'use strict';

  var REPO = 'ZainulArkaanAlinsi/Qur-an_App';
  var DOWNLOAD_PREFIX = 'https://github.com/' + REPO + '/releases/download/';
  var RELEASES_URL = 'https://github.com/' + REPO + '/releases/latest';

  function $(id) { return document.getElementById(id); }

  function formatSize(bytes) {
    return (bytes / 1048576).toFixed(1).replace('.', ',') + ' MB';
  }

  function formatDate(iso) {
    try {
      return new Date(iso).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' });
    } catch (e) {
      return '';
    }
  }

  function showFallback(shaEl) {
    shaEl.textContent = 'Tidak bisa dimuat dari GitHub saat ini. Buka halaman rilis untuk melihat SHA-256: ';
    var link = document.createElement('a');
    link.href = RELEASES_URL;
    link.textContent = 'GitHub Releases';
    shaEl.appendChild(link);
  }

  var shaEl = $('sha');
  if (!shaEl || !window.fetch) { if (shaEl) showFallback(shaEl); return; }

  fetch('https://api.github.com/repos/' + REPO + '/releases/latest', {
    headers: { Accept: 'application/vnd.github+json' }
  })
    .then(function (res) {
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return res.json();
    })
    .then(function (rel) {
      var assets = rel.assets || [];
      var apk = assets.filter(function (a) { return a.name === 'myquran.apk'; })[0] ||
        assets.filter(function (a) { return /\.apk$/.test(a.name); })[0];
      if (!apk) throw new Error('tidak ada APK');

      // Hanya terima tautan dari repo ini.
      if (apk.browser_download_url && apk.browser_download_url.indexOf(DOWNLOAD_PREFIX) === 0) {
        $('unduh').href = apk.browser_download_url;
      }

      var parts = [];
      if (rel.tag_name) parts.push('Versi ' + rel.tag_name.replace(/^v/, ''));
      if (apk.size) parts.push(formatSize(apk.size));
      var date = rel.published_at ? formatDate(rel.published_at) : '';
      if (date) parts.push(date);
      parts.push('Android 7.0 ke atas');
      $('meta').textContent = parts.join(' · ');

      $('nama-berkas').textContent = apk.name;

      var digest = (apk.digest || '').replace(/^sha256:/, '');
      if (/^[0-9a-f]{64}$/i.test(digest)) {
        shaEl.textContent = digest.toLowerCase();
        var copy = $('salin');
        copy.hidden = false;
        copy.addEventListener('click', function () {
          var done = function () {
            copy.textContent = 'Tersalin';
            setTimeout(function () { copy.textContent = 'Salin'; }, 1800);
          };
          try {
            navigator.clipboard.writeText(digest.toLowerCase()).then(done, function () {});
          } catch (e) { /* abaikan */ }
        });
      } else {
        showFallback(shaEl);
      }
    })
    .catch(function () { showFallback(shaEl); });
})();
