// Mengisi versi, ukuran, SHA-256, catatan versi, dan riwayat versi APK dari GitHub Releases,
// supaya pengunjung tidak perlu membuka GitHub. Tanpa pelacak. Bila GitHub tidak terjangkau,
// tautan unduh statis di HTML tetap bekerja.
(function () {
  'use strict';

  var REPO = 'ZainulArkaanAlinsi/Qur-an_App';
  var DOWNLOAD_PREFIX = 'https://github.com/' + REPO + '/releases/download/';
  var RELEASES_URL = 'https://github.com/' + REPO + '/releases/latest';

  function $(id) { return document.getElementById(id); }
  function all(sel) { return Array.prototype.slice.call(document.querySelectorAll(sel)); }
  function T(key, fallback, vars) { return window.MQ ? window.MQ.t(key, fallback, vars) : fallback; }
  function locale() { return window.MQ ? window.MQ.locale() : 'id-ID'; }

  function formatSize(bytes) {
    var n = (bytes / 1048576).toFixed(1);
    return (locale() === 'id-ID' ? n.replace('.', ',') : n) + ' MB';
  }

  function formatDate(iso) {
    try {
      return new Date(iso).toLocaleDateString(locale(), { day: 'numeric', month: 'long', year: 'numeric' });
    } catch (e) {
      return '';
    }
  }

  function apkOf(rel) {
    var assets = rel.assets || [];
    return assets.filter(function (a) { return /^myquran-\d.*\.apk$/.test(a.name); })[0] ||
      assets.filter(function (a) { return a.name === 'myquran.apk'; })[0] ||
      assets.filter(function (a) { return /\.apk$/.test(a.name); })[0] || null;
  }

  function safeUrl(u) { return /^https:\/\//i.test(u) ? u : null; }

  // Penerjemah markdown kecil dan aman: hanya membuat simpul DOM, tanpa innerHTML.
  function inline(parent, text) {
    var re = /(\*\*[^*]+\*\*|`[^`]+`|\[[^\]]+\]\([^)]+\))/g;
    var last = 0, m;
    while ((m = re.exec(text)) !== null) {
      if (m.index > last) parent.appendChild(document.createTextNode(text.slice(last, m.index)));
      var tok = m[0], el;
      if (tok.charAt(0) === '*') {
        el = document.createElement('strong'); el.textContent = tok.slice(2, -2);
      } else if (tok.charAt(0) === '`') {
        el = document.createElement('code'); el.textContent = tok.slice(1, -1);
      } else {
        var mm = /^\[([^\]]+)\]\(([^)]+)\)$/.exec(tok);
        var href = mm ? safeUrl(mm[2]) : null;
        if (href) {
          el = document.createElement('a'); el.href = href; el.rel = 'noopener noreferrer'; el.textContent = mm[1];
        } else {
          el = document.createTextNode(mm ? mm[1] : tok);
        }
      }
      parent.appendChild(el);
      last = m.index + tok.length;
    }
    if (last < text.length) parent.appendChild(document.createTextNode(text.slice(last)));
  }

  function renderMd(md, box) {
    // Bagian "Unduh" di catatan rilis sudah ada di halaman ini (tombol dan SHA-256), jadi dibuang.
    var cut = md.search(/^#{1,4}\s+Unduh\s*$/m);
    if (cut >= 0) md = md.slice(0, cut);
    var lines = md.replace(/\r/g, '').split('\n');
    var list = null, para = null, skippedTitle = false;

    function closePara() { para = null; }
    function closeList() { list = null; }

    lines.forEach(function (line) {
      var h = /^#{1,4}\s+(.*)$/.exec(line);
      var li = /^\s*[-*]\s+(.*)$/.exec(line);
      var bq = /^>\s?(.*)$/.exec(line);
      if (h) {
        closePara(); closeList();
        if (!skippedTitle && /^Baru di/i.test(h[1])) { skippedTitle = true; return; }
        skippedTitle = true;
        var hh = document.createElement('h4'); inline(hh, h[1].replace(/\*\*/g, '')); box.appendChild(hh);
      } else if (li) {
        closePara();
        if (!list) { list = document.createElement('ul'); box.appendChild(list); }
        var item = document.createElement('li'); inline(item, li[1]); list.appendChild(item);
      } else if (bq) {
        closePara(); closeList();
        var q = document.createElement('blockquote'); inline(q, bq[1]); box.appendChild(q);
      } else if (/^\s*$/.test(line)) {
        closePara(); closeList();
      } else {
        closeList();
        if (!para) { para = document.createElement('p'); box.appendChild(para); para.appendChild(document.createTextNode('')); }
        else para.appendChild(document.createTextNode(' '));
        inline(para, line.trim());
      }
    });
  }

  var releases = null;
  var latestIdx = 0;

  function paintMeta() {
    if (!releases) return;
    var rel = releases[latestIdx];
    var apk = apkOf(rel);
    // Nama berkas di langkah pasang dan perintah SHA-256 harus sama dengan berkas yang benar-benar terunduh.
    if (apk && apk.name) all('.js-apk').forEach(function (el) { el.textContent = apk.name; });
    var parts = [];
    if (rel.tag_name) parts.push(T('meta.ver', 'Versi {v}', { v: rel.tag_name.replace(/^v/, '') }));
    if (apk && apk.size) parts.push(formatSize(apk.size));
    var date = rel.published_at ? formatDate(rel.published_at) : '';
    if (date) parts.push(date);
    parts.push(T('meta.android', 'Android 7.0 ke atas'));
    all('.js-meta').forEach(function (p) { p.textContent = parts.join(' · '); });
  }

  function downloadLink(apk, label) {
    var a = document.createElement('a');
    a.className = 'dl';
    a.href = (apk && apk.browser_download_url && apk.browser_download_url.indexOf(DOWNLOAD_PREFIX) === 0)
      ? apk.browser_download_url : RELEASES_URL;
    a.textContent = label;
    return a;
  }

  function paintNotes() {
    var box = $('catatan-baru');
    var hist = $('riwayat');
    var histBox = $('riwayat-isi');
    if (!box) return;
    box.textContent = '';
    if (histBox) histBox.textContent = '';
    if (!releases || !releases.length) {
      var p = document.createElement('p');
      p.className = 'small';
      p.textContent = T('versi.fail', 'Catatan versi tidak bisa dimuat dari GitHub saat ini.');
      var link = document.createElement('a');
      link.href = RELEASES_URL; link.textContent = ' GitHub Releases';
      p.appendChild(link);
      box.appendChild(p);
      if (hist) hist.hidden = true;
      return;
    }

    var rel = releases[latestIdx];
    var h = document.createElement('h3');
    h.textContent = T('versi.new', 'Yang baru di versi {v}', { v: (rel.tag_name || '').replace(/^v/, '') });
    box.appendChild(h);
    var body = document.createElement('div');
    body.className = 'md';
    renderMd(rel.body || '', body);
    box.appendChild(body);

    var older = releases.filter(function (r, i) { return i !== latestIdx; });
    if (hist && histBox && older.length) {
      older.forEach(function (r) {
        var d = document.createElement('details');
        var s = document.createElement('summary');
        var ver = (r.tag_name || '').replace(/^v/, '');
        var date = r.published_at ? formatDate(r.published_at) : '';
        s.textContent = T('meta.ver', 'Versi {v}', { v: ver }) + (date ? ' · ' + date : '');
        d.appendChild(s);
        var inner = document.createElement('div');
        inner.className = 'md';
        renderMd(r.body || '', inner);
        var apk = apkOf(r);
        if (apk) inner.appendChild(downloadLink(apk, T('dl', 'Unduh') + ' ' + (apk.size ? '(' + formatSize(apk.size) + ')' : '')));
        d.appendChild(inner);
        histBox.appendChild(d);
      });
      hist.hidden = false;
    } else if (hist) {
      hist.hidden = true;
    }
  }

  function showFallback(shaEl) {
    shaEl.removeAttribute('data-i18n');
    shaEl.textContent = T('sha.fail', 'Tidak bisa dimuat dari GitHub saat ini. Buka halaman rilis untuk melihat SHA-256: ');
    var link = document.createElement('a');
    link.href = RELEASES_URL;
    link.textContent = 'GitHub Releases';
    shaEl.appendChild(link);
  }

  var shaEl = $('sha');
  if (!window.fetch) { if (shaEl) showFallback(shaEl); paintNotes(); return; }

  fetch('https://api.github.com/repos/' + REPO + '/releases?per_page=8', {
    headers: { Accept: 'application/vnd.github+json' }
  })
    .then(function (res) {
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return res.json();
    })
    .then(function (list) {
      releases = (list || []).filter(function (r) { return !r.draft && !r.prerelease && apkOf(r); });
      if (!releases.length) throw new Error('tidak ada rilis');
      latestIdx = 0;
      var rel = releases[0];
      var apk = apkOf(rel);

      // Hanya terima tautan dari repo ini.
      if (apk.browser_download_url && apk.browser_download_url.indexOf(DOWNLOAD_PREFIX) === 0) {
        all('.js-unduh').forEach(function (a) { a.href = apk.browser_download_url; });
      }
      paintMeta();
      paintNotes();

      var digest = (apk.digest || '').replace(/^sha256:/, '');
      if (shaEl && /^[0-9a-f]{64}$/i.test(digest)) {
        shaEl.removeAttribute('data-i18n');
        shaEl.textContent = digest.toLowerCase();
        var copy = $('salin');
        copy.hidden = false;
        copy.addEventListener('click', function () {
          var done = function () {
            copy.textContent = T('copied', 'Tersalin');
            setTimeout(function () { copy.textContent = T('copy', 'Salin'); }, 1800);
          };
          try {
            navigator.clipboard.writeText(digest.toLowerCase()).then(done, function () {});
          } catch (e) { /* abaikan */ }
        });
      } else if (shaEl) {
        showFallback(shaEl);
      }
    })
    .catch(function () {
      if (shaEl) showFallback(shaEl);
      paintNotes();
    });

  // Ganti bahasa: gambar ulang bagian yang dibuat skrip ini.
  window.addEventListener('mq:lang', function () { paintMeta(); paintNotes(); });
})();
