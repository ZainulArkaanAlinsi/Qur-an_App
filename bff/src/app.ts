import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { z } from 'zod';
import { TtlCache } from './cache.js';
import type { Config } from './config.js';
import { QfApiError, QfClient } from './qf-client.js';
import { RateLimiter } from './rate-limit.js';

const pageSchema = z.coerce.number().int().min(1).max(604);
const chapterSchema = z.coerce.number().int().min(1).max(114);

/** Bentuk milik aplikasi, bukan salinan mentah respons provider. */
type Word = {
  id: number;
  page: number;
  line: number;
  verseKey: string;
  position: number;
  type: string;
  glyph: string;
};

type UpstreamVerse = {
  verse_key: string;
  words?: {
    id: number;
    page_number: number;
    line_number: number;
    position: number;
    char_type_name: string;
    code_v2: string;
  }[];
};

export type AppDeps = {
  config: Config;
  client: QfClient;
  now?: () => number;
};

export function createApp({ config, client, now = Date.now }: AppDeps) {
  const app = new Hono();
  const limiter = new RateLimiter(config.rateLimitPerMinute, now);
  const content = new TtlCache<unknown>(config.contentTtlMs, 2_000, now);
  const resources = new TtlCache<unknown>(config.resourcesTtlMs, 100, now);

  if (config.allowedOrigins.length > 0) {
    app.use('/v1/*', cors({ origin: config.allowedOrigins }));
  }

  app.use('/v1/*', async (context, next) => {
    const key =
      context.req.header('x-forwarded-for')?.split(',')[0]?.trim() ??
      context.req.header('cf-connecting-ip') ??
      'unknown';
    const remaining = limiter.take(key);
    if (remaining === null) {
      return context.json({ error: 'Terlalu banyak permintaan' }, 429);
    }
    context.header('x-ratelimit-remaining', `${remaining}`);
    await next();
  });

  // Log tanpa identitas klien, isi konten, atau kredensial.
  app.use('*', async (context, next) => {
    const started = now();
    await next();
    console.info(
      JSON.stringify({
        method: context.req.method,
        route: context.req.routePath,
        status: context.res.status,
        ms: now() - started,
      }),
    );
  });

  app.onError((error, context) => {
    if (error instanceof QfApiError) {
      return context.json({ error: error.message }, error.status as 502);
    }
    console.error(JSON.stringify({ error: 'unhandled', name: error.name }));
    return context.json({ error: 'Kesalahan internal' }, 500);
  });

  app.get('/v1/health', (context) =>
    context.json({
      status: 'ok',
      environment: config.environment,
      // Konten prelive hanya berisi surah 1–2; berguna saat menguji.
      limitedDataset: config.environment === 'prestaging',
    }),
  );

  app.get('/v1/chapters', async (context) => {
    const data = await resources.fetch('chapters', async () => {
      const body = await client.get<{
        chapters: {
          id: number;
          name_arabic: string;
          name_simple: string;
          verses_count: number;
          pages: number[];
        }[];
      }>('chapters');
      return body.chapters.map((chapter) => ({
        id: chapter.id,
        nameArabic: chapter.name_arabic,
        nameSimple: chapter.name_simple,
        versesCount: chapter.verses_count,
        pages: chapter.pages,
      }));
    });
    return context.json({ chapters: data });
  });

  app.get('/v1/recitations', async (context) => {
    const data = await resources.fetch('recitations', async () => {
      const body = await client.get<{
        recitations: {
          id: number;
          reciter_name: string;
          style?: string | null;
          translated_name?: { name: string } | null;
        }[];
      }>('resources/recitations');
      return body.recitations.map((recitation) => ({
        id: recitation.id,
        reciterName: recitation.reciter_name,
        style: recitation.style ?? null,
        translatedName: recitation.translated_name?.name ?? null,
      }));
    });
    return context.json({ recitations: data });
  });

  /**
   * Kata satu halaman mushaf. `by_page` memilih ayat menurut halaman QCF V1,
   * sedangkan `page_number`/`line_number` kata mengikuti mushaf yang diminta,
   * jadi halaman tetangga ikut diambil lalu disaring di sini. Klien menerima
   * satu halaman utuh dan tidak perlu tahu keanehan ini.
   */
  app.get('/v1/mushaf/v2/pages/:page', async (context) => {
    const page = pageSchema.safeParse(context.req.param('page'));
    if (!page.success) {
      return context.json({ error: 'Nomor halaman harus 1–604' }, 400);
    }
    const number = page.data;
    const data = await content.fetch(`page:${number}`, async () => {
      const neighbours = [number - 1, number, number + 1, number + 2].filter(
        (value) => value >= 1 && value <= 604,
      );
      const responses = await Promise.all(
        neighbours.map((value) =>
          client.get<{ verses: UpstreamVerse[] }>(`verses/by_page/${value}`, {
            words: 'true',
            per_page: '50',
            mushaf: '1',
            word_fields: 'code_v2,line_number,page_number',
          }),
        ),
      );
      const words = new Map<number, Word>();
      for (const response of responses) {
        for (const verse of response.verses) {
          for (const word of verse.words ?? []) {
            if (word.page_number !== number) continue;
            words.set(word.id, {
              id: word.id,
              page: word.page_number,
              line: word.line_number,
              verseKey: verse.verse_key,
              position: word.position,
              type: word.char_type_name,
              glyph: word.code_v2,
            });
          }
        }
      }
      return { page: number, edition: 'qcf-v2', words: [...words.values()] };
    });
    return context.json(data as object);
  });

  app.get('/v1/chapters/:chapter/tajweed', async (context) => {
    const chapter = chapterSchema.safeParse(context.req.param('chapter'));
    if (!chapter.success) {
      return context.json({ error: 'Nomor surah harus 1–114' }, 400);
    }
    const number = chapter.data;
    const data = await content.fetch(`tajweed:${number}`, async () => {
      const body = await client.get<{
        verses: { verse_key: string; text_uthmani_tajweed: string }[];
      }>('quran/verses/uthmani_tajweed', { chapter_number: `${number}` });
      return {
        chapter: number,
        source: 'text_uthmani_tajweed',
        verses: body.verses.map((verse) => ({
          verseKey: verse.verse_key,
          markup: verse.text_uthmani_tajweed,
        })),
      };
    });
    return context.json(data as object);
  });

  app.notFound((context) =>
    context.json({ error: 'Endpoint tidak dikenal' }, 404),
  );

  return app;
}
