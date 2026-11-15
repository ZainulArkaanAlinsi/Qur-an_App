// Gerak halaman unduh MyQuran: paralaks berlapis, kemiringan HP mengikuti pointer, pita yang
// miring menurut kecepatan gulir, judul kata demi kata, dan bab fitur yang menukar layar HP.
// Tanpa pustaka dan tanpa pelacak. Hanya transform dan opacity. Mengikuti prefers-reduced-motion,
// dan pengunjung bisa mematikan gerak lewat tombol di kaki halaman.
(function () {
  'use strict';

  var root = document.documentElement;
  var KEY = 'myquran.gerak';
  var reduceMq = window.matchMedia ? window.matchMedia('(prefers-reduced-motion: reduce)') : null;

  function read() { try { return window.localStorage.getItem(KEY); } catch (e) { return null; } }
  function write(v) { try { window.localStorage.setItem(KEY, v); } catch (e) { /* abaikan */ } }
  function T(key, fallback) { return window.MQ ? window.MQ.t(key, fallback) : fallback; }

  var motionOn = true;
  var ticking = false;
  var lastY = window.pageYOffset || 0;
  var lastT = 0;
  var vel = 0;
  var decaying = false;

  var top = document.querySelector('.top');
  var bar = document.querySelector('.progress');
  var toggle = document.getElementById('gerak');
  var ribbon = document.querySelector('.ribbon');
  var ribbonTrack = document.querySelector('.ribbon-track');
  var fan = document.querySelector('.fan');

  var sections = Array.prototype.slice.call(document.querySelectorAll('[data-parallax]')).map(function (el) {
    return {
      el: el,
      fromTop: el.hasAttribute('data-origin'),
      isStory: el.id === 'cerita',
      layers: Array.prototype.slice.call(el.querySelectorAll('[data-speed]')),
      visible: false
    };
  });

  Array.prototype.forEach.call(document.querySelectorAll('.tilt'), function (t) {
    t.style.setProperty('--k', t.getAttribute('data-depth') || '1');
  });

  function update() {
    ticking = false;
    var y = window.pageYOffset || 0;
    var vh = window.innerHeight || 800;
    var doc = document.documentElement.scrollHeight - vh;

    if (bar) bar.style.setProperty('--sp', doc > 0 ? Math.min(1, y / doc).toFixed(4) : 0);
    if (top && sections[0]) top.classList.toggle('scrolled', y > sections[0].el.offsetHeight * 0.6);
    if (!motionOn) return;

    // Layar sempit: gerak lebih kecil supaya ringan dan tidak memusingkan.
    var k = window.innerWidth < 820 ? 0.55 : 1;

    sections.forEach(function (s) {
      if (!s.visible) return;
      var r = s.el.getBoundingClientRect();
      var base = vh / 2 - (r.top + r.height / 2);
      if (s.fromTop) {
        // Adegan hero menempel di layar: p = seberapa jauh digulir di dalam bagian yang menempel.
        var pin = s.el.querySelector('.hero-pin');
        var span = Math.max(1, s.el.offsetHeight - (pin ? pin.offsetHeight : vh));
        var p = Math.min(1, Math.max(0, -r.top / span));
        s.el.style.setProperty('--p', p.toFixed(4));
      }
      if (s.isStory) {
        // Kemiringan HP berayun terus selama bagian cerita digulir.
        var sp = Math.min(1, Math.max(0, (vh - r.top) / (r.height + vh)));
        s.el.style.setProperty('--sy', Math.sin(sp * Math.PI * 4).toFixed(3));
      }
      s.layers.forEach(function (layer) {
        var speed = parseFloat(layer.getAttribute('data-speed')) || 0;
        var b = base;
        if (layer.hasAttribute('data-local') && layer.parentElement) {
          // Angka bab bergerak menurut posisi babnya sendiri, bukan seluruh bagian.
          var pr = layer.parentElement.getBoundingClientRect();
          b = vh / 2 - (pr.top + pr.height / 2);
        }
        layer.style.translate = '0 ' + (b * speed * k).toFixed(1) + 'px';
      });
    });

    // Pita kata ikut tergulir: tiap piksel gulir menggeser pita (ditambah geseran waktu dari CSS).
    if (ribbon && ribbonTrack) {
      var rr = ribbon.getBoundingClientRect();
      if (rr.bottom > -60 && rr.top < vh + 60) {
        var group = ribbonTrack.scrollWidth / 4;
        ribbonTrack.style.setProperty('--rx', (-((y * 0.9) % group)).toFixed(1));
      }
    }

    // Kecepatan gulir memiringkan pita kata.
    var now = performance.now();
    if (lastT) {
      var dt = Math.max(1, now - lastT);
      var inst = Math.max(-9, Math.min(9, ((y - lastY) / dt) * 4.5));
      vel = vel * 0.6 + inst * 0.4;
    }
    lastY = y;
    lastT = now;
    if (ribbon) ribbon.style.setProperty('--v', vel.toFixed(2));
    if (!decaying) { decaying = true; window.requestAnimationFrame(decay); }
  }

  function decay() {
    vel *= 0.9;
    if (ribbon) ribbon.style.setProperty('--v', vel.toFixed(2));
    if (Math.abs(vel) > 0.04 && motionOn) { window.requestAnimationFrame(decay); }
    else { decaying = false; vel = 0; if (ribbon) ribbon.style.setProperty('--v', '0'); }
  }

  function schedule() {
    if (!ticking) { ticking = true; window.requestAnimationFrame(update); }
  }

  function resetLayers() {
    sections.forEach(function (s) {
      s.layers.forEach(function (layer) { layer.style.translate = ''; });
      s.el.style.removeProperty('--p');
      s.el.style.removeProperty('--sy');
    });
    if (ribbonTrack) ribbonTrack.style.removeProperty('--rx');
    if (ribbon) ribbon.style.removeProperty('--v');
    if (fan) { fan.style.setProperty('--mx', '0'); fan.style.setProperty('--my', '0'); }
  }

  function paintToggle() {
    if (!toggle) return;
    toggle.hidden = false;
    toggle.setAttribute('aria-pressed', motionOn ? 'true' : 'false');
    toggle.textContent = motionOn ? T('m.on', 'Efek gerak: hidup') : T('m.off', 'Efek gerak: mati');
  }

  function apply() {
    root.setAttribute('data-motion', motionOn ? 'on' : 'off');
    paintToggle();
    if (!motionOn) resetLayers();
    schedule();
  }

  var stored = read();
  motionOn = stored ? stored === 'on' : !(reduceMq && reduceMq.matches);

  if (toggle) {
    toggle.addEventListener('click', function () {
      motionOn = !motionOn;
      write(motionOn ? 'on' : 'off');
      apply();
    });
  }
  if (reduceMq && reduceMq.addEventListener) {
    reduceMq.addEventListener('change', function () {
      if (!read()) { motionOn = !reduceMq.matches; apply(); }
    });
  }

  window.addEventListener('scroll', schedule, { passive: true });
  window.addEventListener('resize', schedule);

  // Kemiringan HP mengikuti pointer (hanya mouse, hanya saat gerak hidup).
  var hero = sections[0] && sections[0].el;
  if (hero && fan && window.PointerEvent) {
    var px = 0, py = 0, pending = false;
    var paintPointer = function () {
      pending = false;
      fan.style.setProperty('--mx', px.toFixed(3));
      fan.style.setProperty('--my', py.toFixed(3));
    };
    hero.addEventListener('pointermove', function (e) {
      if (!motionOn || e.pointerType !== 'mouse') return;
      var r = hero.getBoundingClientRect();
      px = Math.max(-1, Math.min(1, ((e.clientX - r.left) / r.width - 0.5) * 2));
      py = Math.max(-1, Math.min(1, ((e.clientY - r.top) / r.height - 0.5) * 2));
      if (!pending) { pending = true; window.requestAnimationFrame(paintPointer); }
    });
    hero.addEventListener('pointerleave', function () { px = 0; py = 0; paintPointer(); });
  }

  // Judul kata demi kata. Dipanggil lagi saat bahasa berganti, karena teksnya diganti.
  var splitEls = Array.prototype.slice.call(document.querySelectorAll('.split'));
  var splitObs = null;

  function splitAll() {
    splitEls.forEach(function (el) {
      var wasIn = el.classList.contains('in');
      var text = el.textContent.replace(/\s+/g, ' ').trim();
      el.textContent = '';
      text.split(' ').forEach(function (word, i, arr) {
        var w = document.createElement('span');
        w.className = 'w';
        var inner = document.createElement('span');
        inner.style.setProperty('--i', String(i));
        inner.textContent = word;
        w.appendChild(inner);
        el.appendChild(w);
        if (i < arr.length - 1) el.appendChild(document.createTextNode(' '));
      });
      el.classList.add('ready');
      el.setAttribute('aria-label', text);
      if (wasIn) el.classList.add('in');
      else if (splitObs) splitObs.observe(el);
    });
  }

  if ('IntersectionObserver' in window) {
    // Hanya bagian yang terlihat yang dihitung ulang.
    var seen = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        sections.forEach(function (s) { if (s.el === e.target) s.visible = e.isIntersecting; });
      });
      schedule();
    }, { rootMargin: '10% 0px 10% 0px' });
    sections.forEach(function (s) { seen.observe(s.el); });

    var reveal = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add('in'); reveal.unobserve(e.target); }
      });
    }, { threshold: 0.15 });
    Array.prototype.forEach.call(document.querySelectorAll('.reveal'), function (el) { reveal.observe(el); });

    splitObs = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add('in'); splitObs.unobserve(e.target); }
      });
    }, { threshold: 0.4 });

    // Bab yang sedang dibaca menentukan layar HP.
    var chapters = Array.prototype.slice.call(document.querySelectorAll('.chapter'));
    var slides = Array.prototype.slice.call(document.querySelectorAll('.slide'));
    var dots = Array.prototype.slice.call(document.querySelectorAll('.dots li'));
    var stageDev = document.getElementById('stage-dev');
    var current = -1;

    var show = function (idx) {
      if (idx === current) return;
      var dir = idx > current ? 1 : -1;
      current = idx;
      chapters.forEach(function (c, i) {
        c.style.setProperty('--dir', String(dir));
        c.classList.toggle('active', i === idx);
      });
      slides.forEach(function (s, i) {
        s.classList.toggle('on', i === idx);
        s.classList.toggle('prev', i < idx);
      });
      dots.forEach(function (d, i) { d.classList.toggle('on', i === idx); });
      if (stageDev) {
        stageDev.style.setProperty('--ry', (idx % 2 ? -8 : 8) + 'deg');
        stageDev.style.setProperty('--rx', (idx % 2 ? 2 : -2) + 'deg');
        var sb = slides[idx] && slides[idx].getAttribute('data-sb');
        if (sb) stageDev.style.setProperty('--sb', sb);
      }
    };

    var chapterObs = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) show(Number(e.target.getAttribute('data-shot')) || 0);
      });
    }, { rootMargin: '-42% 0px -42% 0px' });
    chapters.forEach(function (c) { chapterObs.observe(c); });
    show(0);

    splitAll();
  } else {
    // Peramban lama: tampilkan semuanya, tanpa gerak.
    Array.prototype.forEach.call(document.querySelectorAll('.reveal, .split'), function (el) { el.classList.add('in'); });
    motionOn = false;
  }

  // Ganti bahasa: judul dipecah ulang dan tulisan tombol gerak diperbarui.
  window.addEventListener('mq:lang', function () {
    if ('IntersectionObserver' in window) splitAll();
    paintToggle();
  });

  apply();
})();
