type Entry<T> = { value: T; expiresAt: number };

/**
 * Cache memori dengan TTL dan batas jumlah entri. Tujuannya menahan beban ke
 * provider, bukan menyimpan dataset: isinya hilang saat proses berhenti.
 *
 * Developer Terms Quran Foundation melarang menyimpan konten lebih dari
 * 1 minggu kecuali lewat Content Sync, jadi TTL dibatasi di `config.ts`.
 */
export class TtlCache<T> {
  readonly #entries = new Map<string, Entry<T>>();
  readonly #inflight = new Map<string, Promise<T>>();

  constructor(
    private readonly ttlMs: number,
    private readonly maxEntries = 500,
    private readonly now: () => number = Date.now,
  ) {}

  get size(): number {
    return this.#entries.size;
  }

  get(key: string): T | undefined {
    const entry = this.#entries.get(key);
    if (!entry) return undefined;
    if (entry.expiresAt <= this.now()) {
      this.#entries.delete(key);
      return undefined;
    }
    return entry.value;
  }

  set(key: string, value: T): void {
    if (this.#entries.size >= this.maxEntries && !this.#entries.has(key)) {
      const oldest = this.#entries.keys().next();
      if (!oldest.done) this.#entries.delete(oldest.value);
    }
    this.#entries.set(key, { value, expiresAt: this.now() + this.ttlMs });
  }

  /**
   * Mengembalikan nilai dari cache atau memanggil [load]. Permintaan serentak
   * untuk kunci yang sama hanya memicu satu panggilan ke provider, dan
   * kegagalan tidak pernah disimpan.
   */
  async fetch(key: string, load: () => Promise<T>): Promise<T> {
    const cached = this.get(key);
    if (cached !== undefined) return cached;
    const running = this.#inflight.get(key);
    if (running) return running;
    const promise = load()
      .then((value) => {
        this.set(key, value);
        return value;
      })
      .finally(() => {
        this.#inflight.delete(key);
      });
    this.#inflight.set(key, promise);
    return promise;
  }

  clear(): void {
    this.#entries.clear();
  }
}
