import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { boardRedirect } from '../utils.ts';

describe('board authentication return destinations', () => {
  it('preserves contextual board paths, queries and fragments', () => {
    for (const destination of ['/', '/settings', '/profile/', '/editor?edit=route-123#holds', '/share/abc_-123?view=full']) {
      assert.equal(boardRedirect(destination, '/profile'), destination);
    }
  });

  it('rejects external navigation, URL parser ambiguities and unavailable routes', () => {
    for (const destination of [
      '//evil.example/settings',
      'https://evil.example/settings',
      '/\\evil.example/settings',
      '/\nevil.example/settings',
      '/%2f%2fevil.example',
      '/editor/../../settings',
      '/unknown',
      '/login?redirect=/login',
      'javascript:alert(1)',
      '',
      null,
    ]) {
      assert.equal(boardRedirect(destination, '/settings'), '/settings');
    }
  });
});
