import type { Config } from './config.js';

/**
 * Klien Content API Quran Foundation.
 *
 * Alur resmi: OAuth2 client credentials (Basic auth) dengan scope `content`,
 * lalu setiap permintaan membawa header `x-auth-token` dan `x-client-id`.
 * Token berumur 3600 detik dan tidak punya refresh token, jadi token baru
 * diminta sebelum kedaluwarsa. Dokumentasi provider melarang alur ini
 * dijalankan dari aplikasi mobile — itulah alasan BFF ini ada.
 */
export class QfApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = 'QfApiError';
  }
}

type Token = { value: string; expiresAt: number };

/** Ambil token baru sedikit lebih awal agar tidak kedaluwarsa saat dipakai. */
const REFRESH_MARGIN_MS = 30_000;

export class QfClient {
  #token: Token | null = null;
  #pending: Promise<Token> | null = null;

  constructor(
    private readonly config: Config,
    private readonly fetchImpl: typeof fetch = fetch,
    private readonly now: () => number = Date.now,
  ) {}

  async #requestToken(): Promise<Token> {
    const basic = Buffer.from(
      `${this.config.clientId}:${this.config.clientSecret}`,
    ).toString('base64');
    const response = await this.#withTimeout((signal) =>
      this.fetchImpl(this.config.tokenUrl, {
        method: 'POST',
        headers: {
          authorization: `Basic ${basic}`,
          'content-type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          grant_type: 'client_credentials',
          scope: this.config.scope,
        }).toString(),
        signal,
      }),
    );
    if (!response.ok) {
      // Badan respons bisa memuat petunjuk kredensial; jangan diteruskan.
      throw new QfApiError(
        502,
        'Gagal mendapatkan token dari Quran Foundation',
      );
    }
    const body = (await response.json()) as {
      access_token?: unknown;
      expires_in?: unknown;
    };
    if (typeof body.access_token !== 'string' || !body.access_token) {
      throw new QfApiError(502, 'Respons token tidak berisi access_token');
    }
    const lifetimeMs =
      (typeof body.expires_in === 'number' ? body.expires_in : 3600) * 1000;
    return {
      value: body.access_token,
      expiresAt: this.now() + lifetimeMs - REFRESH_MARGIN_MS,
    };
  }

  async #accessToken(force = false): Promise<string> {
    if (force) this.#token = null;
    const current = this.#token;
    if (current && current.expiresAt > this.now()) return current.value;
    // Satu permintaan token saja meski banyak permintaan masuk bersamaan.
    this.#pending ??= this.#requestToken()
      .then((token) => {
        this.#token = token;
        return token;
      })
      .finally(() => {
        this.#pending = null;
      });
    return (await this.#pending).value;
  }

  async #withTimeout<T>(run: (signal: AbortSignal) => Promise<T>): Promise<T> {
    const controller = new AbortController();
    const timer = setTimeout(
      () => controller.abort(),
      this.config.upstreamTimeoutMs,
    );
    try {
      return await run(controller.signal);
    } catch (error) {
      if (controller.signal.aborted) {
        throw new QfApiError(504, 'Permintaan ke provider melebihi batas waktu');
      }
      throw error instanceof QfApiError
        ? error
        : new QfApiError(502, 'Provider tidak dapat dihubungi');
    } finally {
      clearTimeout(timer);
    }
  }

  /**
   * GET pada Content API. Token kedaluwarsa (401) dicoba ulang **satu kali**
   * dengan token baru, sesuai panduan provider; tidak ada perulangan.
   */
  async get<T>(path: string, query: Record<string, string> = {}): Promise<T> {
    const url = new URL(`${this.config.apiBaseUrl}/${path}`);
    for (const [key, value] of Object.entries(query)) {
      url.searchParams.set(key, value);
    }

    const send = async (token: string) =>
      this.#withTimeout((signal) =>
        this.fetchImpl(url, {
          headers: {
            'x-auth-token': token,
            'x-client-id': this.config.clientId,
            accept: 'application/json',
          },
          signal,
        }),
      );

    let response = await send(await this.#accessToken());
    if (response.status === 401) {
      response = await send(await this.#accessToken(true));
    }
    if (!response.ok) {
      throw new QfApiError(
        response.status === 404 ? 404 : 502,
        `Provider menjawab ${response.status}`,
      );
    }
    return (await response.json()) as T;
  }
}
