// Security rules tests. Run: `npm test` (starts the Firestore emulator).
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
} from 'firebase/firestore';

const SESSION_ID = '3f1c2a9e-8b7d-4c1e-9a2b-1d2e3f4a5b6c';
let env;

const session = (overrides = {}) => {
  const start = Timestamp.fromMillis(Date.now() - 400_000);
  return {
    id: SESSION_ID,
    deviceId: 'device-a',
    startedAt: start,
    endedAt: Timestamp.fromMillis(start.toMillis() + 360_000),
    activeSeconds: 300,
    timezone: 'Asia/Jakarta',
    localDate: '2026-09-22',
    mode: 'reading',
    lastVerseKey: '2:255',
    syncedAt: serverTimestamp(),
    ...overrides,
  };
};

const bookmark = (overrides = {}) => ({
  surah: 2,
  ayah: 255,
  collection: 'Hafalan',
  deleted: false,
  updatedAtMs: 1790000000000,
  syncedAt: serverTimestamp(),
  ...overrides,
});

const db = (uid) =>
  uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const sessionRef = (uid, owner = uid, id = SESSION_ID) =>
  doc(db(uid), `users/${owner}/sessions/${id}`);
const bookmarkRef = (uid, owner = uid, id = '2_255') =>
  doc(db(uid), `users/${owner}/bookmarks/${id}`);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-quran-rules',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});
beforeEach(() => env.clearFirestore());
after(() => env.cleanup());

describe('isolasi antar akun', () => {
  test('pemilik dapat menulis dan membaca sesinya', async () => {
    await assertSucceeds(setDoc(sessionRef('alice'), session()));
    await assertSucceeds(getDoc(sessionRef('alice')));
  });

  test('akun lain tidak dapat membaca sesi pemilik', async () => {
    await setDoc(sessionRef('alice'), session());
    await assertFails(getDoc(sessionRef('bob', 'alice')));
  });

  test('akun lain tidak dapat menulis ke data pemilik', async () => {
    await assertFails(setDoc(sessionRef('bob', 'alice'), session()));
    await assertFails(setDoc(bookmarkRef('bob', 'alice'), bookmark()));
  });

  test('akun lain tidak dapat menghapus data pemilik', async () => {
    await setDoc(sessionRef('alice'), session());
    await assertFails(deleteDoc(sessionRef('bob', 'alice')));
    await assertSucceeds(deleteDoc(sessionRef('alice')));
  });

  test('pengguna tanpa login ditolak', async () => {
    await assertFails(getDoc(sessionRef(null, 'alice')));
    await assertFails(setDoc(sessionRef(null, 'alice'), session()));
  });

  test('query sesi milik sendiri berdasarkan syncedAt diizinkan', async () => {
    const q = query(collection(db('alice'), 'users/alice/sessions'), orderBy('syncedAt'));
    await assertSucceeds(getDocs(q));
    const other = query(collection(db('bob'), 'users/alice/sessions'), orderBy('syncedAt'));
    await assertFails(getDocs(other));
  });
});

describe('tidak ada stats authoritative dari klien', () => {
  test('dokumen user dan koleksi lain ditolak', async () => {
    await assertFails(setDoc(doc(db('alice'), 'users/alice'), { streak: 999 }));
    await assertFails(setDoc(doc(db('alice'), 'users/alice/stats/reading'), { current: 999 }));
    await assertFails(setDoc(doc(db('alice'), 'users/alice/dailyProgress/2026-09-22'), { s: 1 }));
  });
});

describe('validasi sesi', () => {
  const rejects = {
    'field tambahan': { extra: true },
    'activeSeconds nol': { activeSeconds: 0 },
    'activeSeconds > 24 jam': { activeSeconds: 86401 },
    'activeSeconds bukan int': { activeSeconds: 300.5 },
    'detik aktif melebihi durasi sesi': { activeSeconds: 3000 },
    'id tidak sama dengan dokumen': { id: '11111111-1111-4111-8111-111111111111' },
    'tanggal lokal salah format': { localDate: '22-09-2026' },
    'mode tidak dikenal': { mode: 'listening' },
    'syncedAt dari jam klien': { syncedAt: Timestamp.now() },
    'verseKey tidak valid': { lastVerseKey: 'Al-Baqarah' },
    'selesai sebelum mulai': {
      startedAt: Timestamp.fromMillis(Date.now()),
      endedAt: Timestamp.fromMillis(Date.now() - 1000),
    },
  };
  for (const [name, change] of Object.entries(rejects)) {
    test(`ditolak: ${name}`, async () => {
      await assertFails(setDoc(sessionRef('alice'), session(change)));
    });
  }

  test('ID dokumen bukan UUID ditolak', async () => {
    await assertFails(
      setDoc(sessionRef('alice', 'alice', 'abc'), session({ id: 'abc' })),
    );
  });

  test('lastVerseKey null diterima', async () => {
    await assertSucceeds(setDoc(sessionRef('alice'), session({ lastVerseKey: null })));
  });

  test('unggah ulang sesi yang sama (retry) diizinkan', async () => {
    await assertSucceeds(setDoc(sessionRef('alice'), session()));
    await assertSucceeds(setDoc(sessionRef('alice'), session()));
  });
});

describe('validasi bookmark', () => {
  test('bookmark valid dan tombstone diterima', async () => {
    await assertSucceeds(setDoc(bookmarkRef('alice'), bookmark()));
    await assertSucceeds(setDoc(bookmarkRef('alice'), bookmark({ deleted: true })));
  });

  test('versi lebih tua tidak boleh menimpa versi baru (termasuk tombstone)', async () => {
    await assertSucceeds(
      setDoc(bookmarkRef('alice'), bookmark({ deleted: true, updatedAtMs: 2000 })),
    );
    await assertFails(setDoc(bookmarkRef('alice'), bookmark({ updatedAtMs: 1000 })));
  });

  test('versi sama (retry) dan lebih baru diterima', async () => {
    await assertSucceeds(setDoc(bookmarkRef('alice'), bookmark({ updatedAtMs: 2000 })));
    await assertSucceeds(setDoc(bookmarkRef('alice'), bookmark({ updatedAtMs: 2000 })));
    await assertSucceeds(setDoc(bookmarkRef('alice'), bookmark({ updatedAtMs: 3000 })));
  });

  const rejects = {
    'ID tidak sama dengan surah_ayat': ['1_1', {}],
    'surah di luar 1..114': ['115_1', { surah: 115, ayah: 1 }],
    'ayat nol': ['2_0', { ayah: 0 }],
    'koleksi kosong': ['2_255', { collection: '' }],
    'koleksi terlalu panjang': ['2_255', { collection: 'x'.repeat(41) }],
    'deleted bukan bool': ['2_255', { deleted: 'no' }],
    'field tambahan': ['2_255', { note: 'catatan' }],
  };
  for (const [name, [id, change]] of Object.entries(rejects)) {
    test(`ditolak: ${name}`, async () => {
      await assertFails(setDoc(bookmarkRef('alice', 'alice', id), bookmark(change)));
    });
  }
});
