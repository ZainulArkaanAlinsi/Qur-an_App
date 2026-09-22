import { describe, expect, test } from 'vitest';
import { loadConfig } from '../src/config.js';
import { QfApiError, QfClient } from '../src/qf-client.js';

const config = loadConfig({
  QF_CLIENT_ID: 'id-uji',
  QF_CLIENT_SECRET: 'rahasia-uji',
  QF_ENVIRONMENT: 'prestaging',
  UPSTREAM_TIMEOUT_MS: '50',
} as NodeJS.ProcessEnv);

type Call = { url: string; init?: RequestInit };

/**
 * Stub fetch yang memilih respons berdasarkan jenis URL (token vs konten),
 * bukan urutan panggilan, karena urutannya berbeda antar skenario.
 */
function stub(queues: {
  token: ((call: Call) => Response | Promise<Response>)[];
  content: ((call: Call) => Response | Promise<Response>)[];
}) {
  const calls: Call[] = [];
  const cursors = { token: 0, content: 0 };
  const fetchImpl = (async (
    input: Parameters<typeof fetch>[0],
    init?: RequestInit,
  ) => {
    const call = { url: String(input), ...(init ? { init } : {}) };
    calls.push(call);
    const kind = call.url.includes('oauth2') ? 'token' : 'content';
    const queue = queues[kind];
    const handler = queue[Math.min(cursors[kind]++, queue.length - 1)]!;
    return handler(call);
  }) as unknown as typeof fetch;
  return { fetchImpl, calls };
}

const tokenResponse = (value = 'token-1', expiresIn = 3600) =>
  new Response(JSON.stringify({ access_token: value, expires_in: expiresIn }), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });

describe('QfClient', () => {
  test('memakai Basic auth, client_credentials, dan header wajib', async () => {
    const { fetchImpl, calls } = stub({
      token: [() => tokenResponse()],
      content: [() => jsonResponse({ chapters: [] })],
    });
    const client = new QfClient(config, fetchImpl);
    await client.get('chapters');

    const [token, content] = calls;
    expect(token!.url).toBe(
      'https://prelive-oauth2.quran.foundation/oauth2/token',
    );
    const headers = token!.init!.headers as Record<string, string>;
    expect(headers.authorization).toBe(
      `Basic ${Buffer.from('id-uji:rahasia-uji').toString('base64')}`,
    );
    expect(token!.init!.body).toBe(
      'grant_type=client_credentials&scope=content',
    );

    expect(content!.url).toBe(
      'https://apis-prelive.quran.foundation/content/api/v4/chapters',
    );
    const contentHeaders = content!.init!.headers as Record<string, string>;
    expect(contentHeaders['x-auth-token']).toBe('token-1');
    expect(contentHeaders['x-client-id']).toBe('id-uji');
  });

  test('token dipakai ulang sampai mendekati kedaluwarsa', async () => {
    let now = 0;
    const { fetchImpl, calls } = stub({
      token: [
        () => tokenResponse('token-1', 3600),
        () => tokenResponse('token-2', 3600),
      ],
      content: [() => jsonResponse({})],
    });
    const client = new QfClient(config, fetchImpl, () => now);

    await client.get('chapters');
    now = 3_000_000; // masih di dalam masa berlaku
    await client.get('chapters');
    expect(calls.filter((call) => call.url.includes('oauth2'))).toHaveLength(1);

    now = 3_580_000; // di dalam margin 30 detik sebelum kedaluwarsa
    await client.get('chapters');
    expect(calls.filter((call) => call.url.includes('oauth2'))).toHaveLength(2);
  });

  test('permintaan serentak hanya meminta satu token', async () => {
    const { fetchImpl, calls } = stub({
      token: [() => tokenResponse()],
      content: [() => jsonResponse({})],
    });
    const client = new QfClient(config, fetchImpl);
    await Promise.all([
      client.get('chapters'),
      client.get('chapters'),
      client.get('chapters'),
    ]);
    expect(calls.filter((call) => call.url.includes('oauth2'))).toHaveLength(1);
  });

  test('401 memicu token baru dan satu kali percobaan ulang saja', async () => {
    const { fetchImpl, calls } = stub({
      token: [() => tokenResponse('token-1'), () => tokenResponse('token-2')],
      content: [() => new Response('', { status: 401 })],
    });
    const client = new QfClient(config, fetchImpl);
    await expect(client.get('chapters')).rejects.toBeInstanceOf(QfApiError);
    expect(calls).toHaveLength(4);
    const last = calls.at(-1)!.init!.headers as Record<string, string>;
    expect(last['x-auth-token']).toBe('token-2');
  });

  test('kegagalan token tidak membocorkan pesan provider', async () => {
    const { fetchImpl } = stub({
      token: [
        () => new Response('invalid_client: secret salah', { status: 401 }),
      ],
      content: [() => jsonResponse({})],
    });
    const client = new QfClient(config, fetchImpl);
    await expect(client.get('chapters')).rejects.toMatchObject({
      status: 502,
      message: 'Gagal mendapatkan token dari Quran Foundation',
    });
  });

  test('permintaan yang menggantung dihentikan dengan 504', async () => {
    const hang = (call: Call) =>
      new Promise<Response>((_, reject) => {
        call.init?.signal?.addEventListener('abort', () =>
          reject(new Error('aborted')),
        );
      });
    const { fetchImpl } = stub({ token: [hang], content: [hang] });
    const client = new QfClient(config, fetchImpl);
    await expect(client.get('chapters')).rejects.toMatchObject({ status: 504 });
  });
});

describe('loadConfig', () => {
  test('menolak konfigurasi tanpa kredensial, hanya menyebut nama variabel', () => {
    expect(() => loadConfig({} as NodeJS.ProcessEnv)).toThrowError(
      /QF_CLIENT_ID, QF_CLIENT_SECRET/,
    );
  });

  test('URL produksi dipakai saat environment production', () => {
    const production = loadConfig({
      QF_CLIENT_ID: 'a',
      QF_CLIENT_SECRET: 'b',
      QF_ENVIRONMENT: 'production',
    } as NodeJS.ProcessEnv);
    expect(production.tokenUrl).toBe(
      'https://oauth2.quran.foundation/oauth2/token',
    );
    expect(production.apiBaseUrl).toBe(
      'https://apis.quran.foundation/content/api/v4',
    );
  });

  test('TTL cache tidak boleh melewati batas 1 minggu Developer Terms', () => {
    expect(() =>
      loadConfig({
        QF_CLIENT_ID: 'a',
        QF_CLIENT_SECRET: 'b',
        CACHE_TTL_CONTENT_SECONDS: '1209600',
      } as NodeJS.ProcessEnv),
    ).toThrowError(/CACHE_TTL_CONTENT_SECONDS/);
  });
});
