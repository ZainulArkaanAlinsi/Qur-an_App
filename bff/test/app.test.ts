import { describe, expect, test } from 'vitest';
import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { QfClient } from '../src/qf-client.js';

/** Kata sintetis: glyph QCF asli tidak perlu untuk menguji rute. */
const word = (id: number, page: number, line: number) => ({
  id,
  page_number: page,
  line_number: line,
  position: id,
  char_type_name: 'word',
  code_v2: `g${id}`,
});

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });

function harness(options: { now?: () => number; ratePerMinute?: number } = {}) {
  const calls: string[] = [];
  const fetchImpl = (async (input: Parameters<typeof fetch>[0]) => {
    const url = String(input);
    calls.push(url);
    if (url.includes('oauth2')) {
      return json({ access_token: 't', expires_in: 3600 });
    }
    if (url.includes('verses/by_page/')) {
      const requested = Number(url.split('verses/by_page/')[1]!.split('?')[0]);
      return json({
        verses: [
          {
            verse_key: '1:1',
            // Sebagian kata pada respons ini milik halaman tetangga.
            words: [
              word(requested * 10, requested, 1),
              word(requested * 10 + 1, requested + 1, 1),
            ],
          },
        ],
      });
    }
    if (url.includes('quran/verses/uthmani_tajweed')) {
      return json({
        verses: [{ verse_key: '1:1', text_uthmani_tajweed: '<span>x</span>' }],
      });
    }
    if (url.includes('resources/recitations')) {
      return json({
        recitations: [
          {
            id: 7,
            reciter_name: 'Mishari Rashid al-`Afasy',
            style: 'Murattal',
            translated_name: { name: 'Mishari Rashid al-`Afasy' },
          },
        ],
      });
    }
    if (url.endsWith('/chapters')) {
      // Simulasi gangguan di sisi provider.
      return new Response('upstream down', { status: 500 });
    }
    return new Response('not found', { status: 404 });
  }) as unknown as typeof fetch;

  const config = loadConfig({
    QF_CLIENT_ID: 'id-uji',
    QF_CLIENT_SECRET: 'rahasia-uji',
    RATE_LIMIT_PER_MINUTE: `${options.ratePerMinute ?? 60}`,
  } as NodeJS.ProcessEnv);
  const app = createApp({
    config,
    client: new QfClient(config, fetchImpl, options.now ?? Date.now),
    ...(options.now ? { now: options.now } : {}),
  });
  return { app, calls };
}

describe('rute BFF', () => {
  test('health menyebut lingkungan dan dataset prelive yang terbatas', async () => {
    const { app } = harness();
    const response = await app.request('/v1/health');
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      status: 'ok',
      environment: 'prestaging',
      limitedDataset: true,
    });
  });

  test('halaman mushaf hanya memuat kata milik halaman itu', async () => {
    const { app } = harness();
    const response = await app.request('/v1/mushaf/v2/pages/50');
    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      page: number;
      edition: string;
      words: { id: number; page: number }[];
    };
    expect(body.page).toBe(50);
    expect(body.edition).toBe('qcf-v2');
    expect(body.words.map((item) => item.page)).toEqual([50, 50]);
    // 491 berasal dari respons halaman 49 tetapi milik halaman 50: inilah
    // alasan halaman tetangga ikut diambil lalu disaring.
    expect(body.words.map((item) => item.id).sort()).toEqual([491, 500]);
  });

  test('nomor halaman di luar 1–604 ditolak sebelum memanggil provider', async () => {
    const { app, calls } = harness();
    const response = await app.request('/v1/mushaf/v2/pages/605');
    expect(response.status).toBe(400);
    expect(calls).toHaveLength(0);
  });

  test('nomor surah tidak valid ditolak', async () => {
    const { app, calls } = harness();
    expect((await app.request('/v1/chapters/0/tajweed')).status).toBe(400);
    expect((await app.request('/v1/chapters/abc/tajweed')).status).toBe(400);
    expect(calls).toHaveLength(0);
  });

  test('permintaan kedua dilayani dari cache tanpa memanggil provider', async () => {
    const { app, calls } = harness();
    await app.request('/v1/chapters/1/tajweed');
    const afterFirst = calls.length;
    await app.request('/v1/chapters/1/tajweed');
    expect(calls).toHaveLength(afterFirst);
  });

  test('daftar qari diteruskan dalam bentuk milik aplikasi', async () => {
    const { app } = harness();
    const response = await app.request('/v1/recitations');
    await expect(response.json()).resolves.toEqual({
      recitations: [
        {
          id: 7,
          reciterName: 'Mishari Rashid al-`Afasy',
          style: 'Murattal',
          translatedName: 'Mishari Rashid al-`Afasy',
        },
      ],
    });
  });

  test('rate limit menolak permintaan berlebih dengan 429', async () => {
    const { app } = harness({ ratePerMinute: 2 });
    const headers = { 'x-forwarded-for': '203.0.113.9' };
    expect((await app.request('/v1/health', { headers })).status).toBe(200);
    expect((await app.request('/v1/health', { headers })).status).toBe(200);
    const blocked = await app.request('/v1/health', { headers });
    expect(blocked.status).toBe(429);
    // Klien lain tidak ikut terblokir.
    const other = await app.request('/v1/health', {
      headers: { 'x-forwarded-for': '203.0.113.10' },
    });
    expect(other.status).toBe(200);
  });

  test('kegagalan provider menjadi 502 tanpa membocorkan detail', async () => {
    const { app } = harness();
    const response = await app.request('/v1/chapters');
    expect(response.status).toBe(502);
    const body = (await response.json()) as { error: string };
    expect(body.error).not.toMatch(/token|secret|id-uji/i);
  });

  test('endpoint tidak dikenal menjawab 404 JSON', async () => {
    const { app } = harness();
    const response = await app.request('/v1/tidak-ada');
    expect(response.status).toBe(404);
  });
});
