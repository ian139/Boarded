import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';

// DESTRUCTIVE FIXTURES: point both variables at the SAME disposable deployment.
// Its migrated DB connection must be boarded_migrator (role assignment/fixtures),
// and its SMTP configuration must target a TLS-capable test mail sink.
// Run: TEST_APP_ORIGIN=... TEST_DATABASE_URL=... node --test lib/server/security.integration.test.mjs
// No server is started, migrations applied or real email verification bypass exposed.
// Run exclusively: global-quota fixtures and metadata snapshots require no other writers.
const enabled = Boolean(process.env.TEST_APP_ORIGIN && process.env.TEST_DATABASE_URL);

test('real backend preserves ownership, image privacy and cleanup boundaries', {
  skip: enabled ? false : 'Requires TEST_APP_ORIGIN and TEST_DATABASE_URL for a disposable deployment',
  timeout: 120_000,
}, async (t) => {
  const [{ default: pg }, { default: sharp }] = await Promise.all([import('pg'), import('sharp')]);
  const origin = new URL(process.env.TEST_APP_ORIGIN).origin;
  const database = new pg.Pool({ connectionString: process.env.TEST_DATABASE_URL, max: 2 });
  const emails = [];
  const users = [];
  const routeIds = [];
  const wallIds = [];
  const uploads = [];
  const metadataFixtures = new Set();
  let quotaOwner;
  let owner;
  let outsider;

  async function request(path, { method = 'GET', actor, json, form } = {}, status = 200) {
    const headers = { Origin: origin };
    if (actor) headers.Cookie = actor.cookie;
    if (json !== undefined) headers['Content-Type'] = 'application/json';
    const response = await fetch(new URL(path, origin), {
      method, headers, body: form ?? (json === undefined ? undefined : JSON.stringify(json)),
      redirect: 'manual', signal: AbortSignal.timeout(20_000),
    });
    assert.ok([status].flat().includes(response.status), `${method} ${path}: unexpected HTTP status ${response.status}`);
    return response;
  }
  async function jsonRequest(path, options, status) {
    return (await request(path, options, status)).json();
  }
  async function account(label) {
    const email = `boarded-security-${randomUUID()}@example.test`;
    emails.push(email);
    const password = `Security-${randomUUID()}!`;
    await request('/api/auth/sign-up/email', {
      method: 'POST', json: { email, password, name: label },
    });
    const verified = await database.query(
      'UPDATE public."user" SET "emailVerified" = true WHERE email = $1 RETURNING id', [email],
    );
    assert.equal(verified.rowCount, 1, 'App and fixture connection must target the same disposable database');
    const id = verified.rows[0].id;
    users.push(id);
    const response = await request('/api/auth/sign-in/email', { method: 'POST', json: { email, password } });
    const cookie = response.headers.getSetCookie().map((value) => value.split(';', 1)[0]).join('; ');
    assert.ok(cookie, 'A verified sign-in must issue a session cookie');
    return { id, cookie };
  }
  const png = await sharp({ create: { width: 4, height: 3, channels: 3, background: '#ca7248' } }).png().toBuffer();
  function uploadForm(bytes = png) {
    const form = new FormData();
    form.set('file', new Blob([bytes], { type: 'image/png' }), 'fixture.png');
    form.set('purpose', 'wall');
    form.set('wall_id', randomUUID());
    return form;
  }
  async function storedFiles(actor) {
    return (await database.query(`
      SELECT id, owner_id, purpose, entity_id, wall_id, bytes FROM public.files
      WHERE $1::uuid IS NULL OR owner_id = $1 ORDER BY id
    `, [actor?.id ?? null])).rows;
  }
  // Metadata-only fixtures have no disk bytes and must never enter disk cleanup.
  // Mix every purpose; all rows are unreferenced and owned only by this test.
  async function withStorageFixtures({ count = 1, bytes, actor = quotaOwner }, run) {
    const ids = Array.from({ length: count }, () => randomUUID());
    for (const id of ids) metadataFixtures.add(id);
    try {
      await database.query(`
        INSERT INTO public.files(id, owner_id, purpose, entity_id, mime_type, width, height, bytes, checksum)
        SELECT id, $2::uuid,
          (ARRAY['wall', 'route-snapshot', 'avatar'])[((ordinal - 1) % 3 + 1)::integer],
          id, 'image/webp', 1, 1,
          CASE WHEN ordinal = 1 THEN $3::bigint - ($4::integer - 1) ELSE 1 END,
          repeat('0', 64)
        FROM unnest($1::uuid[]) WITH ORDINALITY AS fixtures(id, ordinal)
      `, [ids, actor?.id ?? null, bytes, count]);
      await run(ids);
    } finally {
      await database.query('DELETE FROM public.files WHERE id = ANY($1::uuid[])', [ids]);
      for (const id of ids) metadataFixtures.delete(id);
    }
  }
  async function upload(purpose, wallId, routeId) {
    const form = new FormData();
    form.set('file', new Blob([png], { type: 'image/png' }), 'fixture.png');
    form.set('purpose', purpose);
    if (wallId) form.set('wall_id', wallId);
    if (routeId) form.set('route_id', routeId);
    const uploaded = await jsonRequest('/api/files', { method: 'POST', actor: owner, form }, 201);
    uploads.push(uploaded.id);
    return uploaded;
  }
  // Simulate eight days passing without disabling timestamp triggers or changing
  // the server clock. Only this test's UNREFERENCED upload is replaced atomically;
  // its actual bytes stay intact. Referenced resources are never fixture-rewritten.
  async function ageOrphan(id) {
    await database.query(`
      WITH removed AS (
        DELETE FROM public.files f WHERE f.id = $1
          AND NOT EXISTS (SELECT 1 FROM public.file_references r WHERE r.file_id = f.id)
        RETURNING f.*
      )
      INSERT INTO public.files(id, owner_id, purpose, entity_id, wall_id, mime_type,
        width, height, bytes, checksum, created_at, updated_at)
      SELECT id, owner_id, purpose, entity_id, wall_id, mime_type,
        width, height, bytes, checksum, now() - interval '8 days', now() - interval '8 days'
      FROM removed
    `, [id]);
  }

  t.after(async () => {
    try {
      // Scope every cleanup to UUIDs created by this test. Never truncate tables.
      await database.query('DELETE FROM public.files WHERE id = ANY($1::uuid[])', [[...metadataFixtures]]);
      // Discover unexpected durable records too, so failed assertions do not leak
      // actual upload bytes. These accounts belong exclusively to these tests.
      for (const actor of [owner, quotaOwner].filter(Boolean)) {
        for (const file of await storedFiles(actor)) {
          if (!uploads.includes(file.id)) uploads.push(file.id);
        }
      }
      await database.query('DELETE FROM public.routes WHERE id = ANY($1::uuid[])', [routeIds]);
      await database.query('DELETE FROM public.walls WHERE id = ANY($1::uuid[])', [wallIds]);
      if (outsider) {
        await database.query("INSERT INTO public.user_roles(user_id, role) VALUES ($1, 'moderator') ON CONFLICT DO NOTHING", [outsider.id]);
        for (const id of uploads) await ageOrphan(id);
        const cleaned = await jsonRequest('/api/admin/storage/cleanup', {
          method: 'POST', actor: outsider, json: { fileIds: uploads },
        });
        assert.ok(uploads.every((id) => cleaned.deletedIds.includes(id) || id === removedOrphan), 'Fixture bytes must be cleaned');
      }
      await database.query('DELETE FROM public."user" WHERE id = ANY($1::uuid[])', [users]);
      // Verification records may retain an email identifier after fixture deletion.
      await database.query('DELETE FROM public.verification WHERE identifier = ANY($1::text[])', [emails]);
    } finally {
      await database.end();
    }
  });
  let removedOrphan;
  owner = await account('Security owner');
  outsider = await account('Security outsider');
  const routeId = randomUUID();
  routeIds.push(routeId);
  const shareToken = randomUUID();
  const original = { id: routeId, wall_id: 'default-wall', name: 'Owner route', is_public: false, share_token: shareToken };

  await t.test('cross-owner offline replay cannot overwrite an existing route', async () => {
    await jsonRequest('/api/routes', { method: 'POST', actor: owner, json: original }, 201);
    await request('/api/routes', {
      method: 'POST', actor: outsider, json: { ...original, name: 'Attempted takeover', is_public: true },
    }, 409);
    const saved = await jsonRequest(`/api/routes/${routeId}`, { actor: owner });
    assert.equal(saved.user_id, owner.id);
    assert.equal(saved.name, original.name);
    assert.equal(saved.is_public, false);
  });

  await t.test('share tokens never unlock private routes', async () => {
    await request(`/api/routes/${routeId}`, {}, 404);
    await request(`/api/routes/${routeId}`, { actor: outsider }, 404);
    await request(`/api/share/${shareToken}`, {}, 404);
    await jsonRequest(`/api/routes/${routeId}`, { method: 'PATCH', actor: owner, json: { is_public: true } });
    const shared = await jsonRequest(`/api/share/${shareToken}`);
    assert.equal(shared.id, routeId);
    assert.equal(shared.is_public, true);
  });

  const wallId = randomUUID();
  wallIds.push(wallId);
  let wallImage;
  let snapshot;
  await t.test('public route snapshots do not expose private wall bytes', async () => {
    wallImage = await upload('wall', wallId);
    await jsonRequest('/api/walls', { method: 'POST', actor: owner, json: {
      id: wallId, name: 'Private photo wall', image_url: wallImage.url,
      image_width: wallImage.width, image_height: wallImage.height, is_public: false,
    } }, 201);
    const privateBytes = Buffer.from(await (await request(wallImage.url, { actor: owner })).arrayBuffer());
    await request(wallImage.url, {}, 404);
    await request(wallImage.url, { actor: outsider }, 404);
    snapshot = await upload('route-snapshot', wallId, routeId);
    await jsonRequest(`/api/routes/${routeId}`, { method: 'PATCH', actor: owner, json: {
      wall_id: wallId, wall_image_url: snapshot.url,
      wall_image_width: snapshot.width, wall_image_height: snapshot.height,
    } });
    const shared = await jsonRequest(`/api/share/${shareToken}`);
    assert.equal(shared.wall_image_url, snapshot.url);
    assert.notEqual(snapshot.url, wallImage.url);
    const publicResponse = await request(snapshot.url);
    assert.match(publicResponse.headers.get('cache-control'), /no-store/);
    assert.deepEqual(Buffer.from(await publicResponse.arrayBuffer()), privateBytes);
    await request(wallImage.url, {}, 404);
    await request(wallImage.url, { actor: outsider }, 404);
  });

  await t.test('cleanup requires a moderator and rechecks a stale preview after attachment', async () => {
    await request('/api/admin/storage/cleanup-preview', { method: 'POST', actor: owner }, 403);
    await database.query("INSERT INTO public.user_roles(user_id, role) VALUES ($1, 'moderator')", [outsider.id]);
    const orphan = await upload('wall', randomUUID());
    const lateWallId = randomUUID();
    wallIds.push(lateWallId);
    const lateImage = await upload('wall', lateWallId);
    await ageOrphan(orphan.id);
    await ageOrphan(lateImage.id);
    const preview = await jsonRequest('/api/admin/storage/cleanup-preview', { method: 'POST', actor: outsider });
    assert.ok(preview.files.some((file) => file.id === orphan.id));
    assert.ok(preview.files.some((file) => file.id === lateImage.id));
    await jsonRequest('/api/walls', { method: 'POST', actor: owner, json: {
      id: lateWallId, name: 'Attached after preview', image_url: lateImage.url, is_public: false,
    } }, 201);
    const result = await jsonRequest('/api/admin/storage/cleanup', {
      method: 'POST', actor: outsider, json: { fileIds: [orphan.id, lateImage.id, wallImage.id, snapshot.id] },
    });
    removedOrphan = orphan.id;
    assert.deepEqual(result.deletedIds, [orphan.id]);
    await request(orphan.url, { actor: owner }, 404);
    await request(lateImage.url, { actor: owner });
    await request(wallImage.url, { actor: owner });
    await request(snapshot.url);
  });

  quotaOwner = await account('Storage quota owner');
  const accountByteLimit = 250 * 1024 * 1024;

  await t.test('anonymous uploads return 401 without durable file metadata', async () => {
    const before = await storedFiles();
    await request('/api/files', { method: 'POST', form: uploadForm() }, 401);
    assert.deepEqual(await storedFiles(), before);
  });

  await t.test('malformed images leave no metadata and release admission for a valid upload', async () => {
    const before = await storedFiles(owner);
    const rejected = await jsonRequest('/api/files', {
      method: 'POST', actor: owner, form: uploadForm(Buffer.from('not an image')),
    }, 422);
    assert.equal(rejected.error.code, 'invalid_file');
    assert.deepEqual(await storedFiles(owner), before);
    const uploaded = await upload('wall', randomUUID());
    await request(uploaded.url, { actor: owner });
  });

  await t.test('500 stored files across purposes reject uploads without adding an orphan', async () => {
    await withStorageFixtures({ count: 500, bytes: 500 }, async () => {
      const before = await storedFiles(quotaOwner);
      const rejected = await jsonRequest('/api/files', {
        method: 'POST', actor: quotaOwner, form: uploadForm(),
      }, 413);
      assert.equal(rejected.error.code, 'storage_quota');
      assert.deepEqual(await storedFiles(quotaOwner), before);
    });
  });

  await t.test('exhausted account bytes reject avatar uploads without adding an orphan', async () => {
    await withStorageFixtures({ bytes: accountByteLimit }, async () => {
      const before = await storedFiles(quotaOwner);
      const form = new FormData();
      form.set('file', new Blob([png], { type: 'image/png' }), 'fixture.png');
      const rejected = await jsonRequest('/api/profile/avatar', {
        method: 'POST', actor: quotaOwner, form,
      }, 413);
      assert.equal(rejected.error.code, 'storage_quota');
      assert.deepEqual(await storedFiles(quotaOwner), before);
    });
  });

  await t.test('normalized image bytes cannot exceed the remaining account quota', async () => {
    // One remaining byte cannot contain a valid WebP, irrespective of encoder
    // version or whether normalization makes this PNG larger or smaller.
    await withStorageFixtures({ bytes: accountByteLimit - 1 }, async () => {
      const before = await storedFiles(quotaOwner);
      const rejected = await jsonRequest('/api/files', {
        method: 'POST', actor: quotaOwner, form: uploadForm(),
      }, 413);
      assert.equal(rejected.error.code, 'storage_quota');
      assert.deepEqual(await storedFiles(quotaOwner), before);
    });
  });

  await t.test('global byte quota counts owner-null files and rejects without metadata', async () => {
    const globalByteLimit = 10 * 1024 * 1024 * 1024;
    const existingBytes = (await storedFiles()).reduce((total, file) => total + Number(file.bytes), 0);
    assert.ok(existingBytes < globalByteLimit, 'Disposable deployment must start below the global byte cap');
    await withStorageFixtures({ bytes: globalByteLimit - existingBytes, actor: null }, async () => {
      const before = await storedFiles();
      const rejected = await jsonRequest('/api/files', {
        method: 'POST', actor: quotaOwner, form: uploadForm(),
      }, 413);
      assert.equal(rejected.error.code, 'storage_quota');
      assert.deepEqual(await storedFiles(), before);
    });
  });

  await t.test('concurrent uploads cannot exceed the final account file slot or silently succeed', async () => {
    await withStorageFixtures({ count: 499, bytes: 499 }, async (fixtureIds) => {
      // Wait for every request, even if one fails, before removing quota fixtures.
      const settled = await Promise.allSettled(Array.from({ length: 4 }, async () => {
        const response = await request('/api/files', {
          method: 'POST', actor: quotaOwner, form: uploadForm(),
        }, [201, 429, 413]);
        const body = await response.json();
        if (response.status === 201) uploads.push(body.id);
        return { status: response.status, body };
      }));
      for (const result of settled) {
        if (result.status === 'rejected') throw result.reason;
      }
      const results = settled.map((result) => result.value);
      const successes = results.filter((result) => result.status === 201);
      for (const result of results) {
        if (result.status !== 201) {
          assert.equal(result.body.error.code, result.status === 429 ? 'upload_busy' : 'storage_quota');
        }
      }
      const files = await storedFiles(quotaOwner);
      assert.ok(files.length <= 500, 'Concurrent requests must not overfill the account');
      assert.ok(files.reduce((total, file) => total + Number(file.bytes), 0) <= accountByteLimit);
      assert.deepEqual(
        files.filter((file) => !fixtureIds.includes(file.id)).map((file) => file.id).sort(),
        successes.map((result) => result.body.id).sort(),
        'Every success must be durable and every rejected request must leave no file metadata',
      );
      for (const { body } of successes) await request(body.url, { actor: quotaOwner });
      // Capacity rejection is allowed, but must not permanently consume the slot.
      if (successes.length === 0) {
        const uploaded = await jsonRequest('/api/files', {
          method: 'POST', actor: quotaOwner, form: uploadForm(),
        }, 201);
        uploads.push(uploaded.id);
        await request(uploaded.url, { actor: quotaOwner });
      }
      const before = await storedFiles(quotaOwner);
      assert.equal(before.length, 500);
      const rejected = await jsonRequest('/api/files', {
        method: 'POST', actor: quotaOwner, form: uploadForm(),
      }, 413);
      assert.equal(rejected.error.code, 'storage_quota');
      assert.deepEqual(await storedFiles(quotaOwner), before);
    });
  });
});
