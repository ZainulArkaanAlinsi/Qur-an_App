/**
 * Token bucket per klien: menahan penyalahgunaan endpoint dan menjaga kuota ke
 * provider. Batas resmi Quran Foundation tidak dipublikasikan, jadi angka di
 * sini adalah batas milik kita sendiri (lihat `RATE_LIMIT_PER_MINUTE`).
 *
 * Kunci klien (mis. alamat IP) tidak pernah masuk log.
 */
export class RateLimiter {
  readonly #buckets = new Map<string, { tokens: number; updatedAt: number }>();

  constructor(
    private readonly perMinute: number,
    private readonly now: () => number = Date.now,
    private readonly maxKeys = 10_000,
  ) {}

  /** @returns sisa jatah, atau `null` bila permintaan ditolak. */
  take(key: string): number | null {
    const current = this.now();
    const bucket = this.#buckets.get(key) ?? {
      tokens: this.perMinute,
      updatedAt: current,
    };
    const refill = ((current - bucket.updatedAt) / 60_000) * this.perMinute;
    const tokens = Math.min(this.perMinute, bucket.tokens + refill);
    if (tokens < 1) {
      this.#buckets.set(key, { tokens, updatedAt: current });
      return null;
    }
    if (this.#buckets.size >= this.maxKeys && !this.#buckets.has(key)) {
      const oldest = this.#buckets.keys().next();
      if (!oldest.done) this.#buckets.delete(oldest.value);
    }
    this.#buckets.set(key, { tokens: tokens - 1, updatedAt: current });
    return Math.floor(tokens - 1);
  }
}
