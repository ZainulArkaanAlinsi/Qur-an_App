import { z } from 'zod';

/**
 * URL bawaan per lingkungan. Nilai ini dapat ditimpa lewat env karena
 * dokumentasi provider bisa berubah; lihat bff/README.md.
 */
const DEFAULTS = {
  prestaging: {
    tokenUrl: 'https://prelive-oauth2.quran.foundation/oauth2/token',
    apiBaseUrl: 'https://apis-prelive.quran.foundation/content/api/v4',
  },
  production: {
    tokenUrl: 'https://oauth2.quran.foundation/oauth2/token',
    apiBaseUrl: 'https://apis.quran.foundation/content/api/v4',
  },
} as const;

/** Batas penyimpanan konten menurut Developer Terms: 1 minggu. */
const MAX_CACHE_SECONDS = 7 * 24 * 60 * 60;

const schema = z.object({
  QF_CLIENT_ID: z.string().min(1),
  QF_CLIENT_SECRET: z.string().min(1),
  QF_ENVIRONMENT: z.enum(['prestaging', 'production']).default('prestaging'),
  QF_TOKEN_URL: z.string().url().optional(),
  QF_API_BASE_URL: z.string().url().optional(),
  QF_SCOPE: z.string().default('content'),
  PORT: z.coerce.number().int().positive().default(8787),
  RATE_LIMIT_PER_MINUTE: z.coerce.number().int().positive().default(60),
  // Developer Terms: konten tidak boleh disimpan lebih dari 1 minggu kecuali
  // lewat Content Sync, jadi TTL dibatasi di sini, bukan sekadar dicatat.
  CACHE_TTL_CONTENT_SECONDS: z.coerce
    .number()
    .int()
    .positive()
    .max(MAX_CACHE_SECONDS)
    .default(86_400),
  CACHE_TTL_RESOURCES_SECONDS: z.coerce
    .number()
    .int()
    .positive()
    .max(MAX_CACHE_SECONDS)
    .default(3_600),
  ALLOWED_ORIGINS: z.string().default(''),
  UPSTREAM_TIMEOUT_MS: z.coerce.number().int().positive().default(15_000),
});

export type Config = {
  clientId: string;
  clientSecret: string;
  environment: 'prestaging' | 'production';
  tokenUrl: string;
  apiBaseUrl: string;
  scope: string;
  port: number;
  rateLimitPerMinute: number;
  contentTtlMs: number;
  resourcesTtlMs: number;
  allowedOrigins: string[];
  upstreamTimeoutMs: number;
};

/**
 * Membaca konfigurasi dari environment. Gagal cepat bila kredensial tidak ada
 * supaya server tidak pernah berjalan setengah jadi. Pesan error hanya memuat
 * nama variabel, tidak pernah nilainya.
 */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = schema.safeParse(env);
  if (!parsed.success) {
    const fields = parsed.error.issues.map((issue) => issue.path.join('.'));
    throw new Error(
      `Konfigurasi tidak lengkap: ${[...new Set(fields)].join(', ')}`,
    );
  }
  const value = parsed.data;
  const defaults = DEFAULTS[value.QF_ENVIRONMENT];
  return {
    clientId: value.QF_CLIENT_ID,
    clientSecret: value.QF_CLIENT_SECRET,
    environment: value.QF_ENVIRONMENT,
    tokenUrl: value.QF_TOKEN_URL ?? defaults.tokenUrl,
    apiBaseUrl: value.QF_API_BASE_URL ?? defaults.apiBaseUrl,
    scope: value.QF_SCOPE,
    port: value.PORT,
    rateLimitPerMinute: value.RATE_LIMIT_PER_MINUTE,
    contentTtlMs: value.CACHE_TTL_CONTENT_SECONDS * 1000,
    resourcesTtlMs: value.CACHE_TTL_RESOURCES_SECONDS * 1000,
    allowedOrigins: value.ALLOWED_ORIGINS.split(',')
      .map((origin) => origin.trim())
      .filter(Boolean),
    upstreamTimeoutMs: value.UPSTREAM_TIMEOUT_MS,
  };
}
