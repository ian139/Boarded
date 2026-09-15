import { it } from 'node:test';
import assert from 'node:assert/strict';
import { resourceAPI, ResourceError } from './client.ts';

it('retains confirmed deletions and retry failures without treating partial cleanup as success', async (context) => {
  const payload = {
    error: { code: 'cleanup_failed', message: 'Some files could not be deleted; retry is safe' },
    deletedIds: ['00000000-0000-4000-8000-000000000001'],
    failedIds: ['00000000-0000-4000-8000-000000000002'],
  };
  context.mock.method(globalThis, 'fetch', async () => Response.json(payload, { status: 500 }));

  await assert.rejects(
    resourceAPI.request('/api/admin/storage/cleanup', {
      method: 'POST',
      body: JSON.stringify({ fileIds: [...payload.deletedIds, ...payload.failedIds] }),
    }),
    (error: unknown) => {
      assert.ok(error instanceof ResourceError);
      assert.equal(error.status, 500);
      assert.equal(error.code, 'cleanup_failed');
      assert.equal(error.message, payload.error.message);
      assert.deepEqual(error.payload, payload);
      return true;
    },
  );
});
