import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';
import ts from 'typescript';
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import type { useWallsStore as WallsStore } from './walls-store';
import type { Wall } from '@boarded/shared/types';

test('cached private wall and selection stay hidden until an owner-verified resource fetch', async () => {
  const privateWall: Wall = {
    id: 'private-wall', user_id: 'owner-a', name: 'Private training wall',
    image_url: '/api/files/private', image_width: 100, image_height: 100,
    is_public: false, created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z',
  };
  const guestWall = { ...privateWall, id: 'guest-wall', user_id: 'local-user', name: 'Guest wall' };
  let persisted = JSON.stringify({ state: { walls: [guestWall, privateWall], selectedWall: privateWall }, version: 0 });
  const storage = { getItem: () => persisted, setItem: (_key: string, value: string) => { persisted = value; }, removeItem: () => { persisted = ''; } };
  let resourceReads = 0;
  const resourceAPI = {
    session: async () => ({ user: { id: 'owner-a' } }),
    request: async () => { resourceReads += 1; return [privateWall]; },
  };
  const module = { exports: {} as { useWallsStore: typeof WallsStore } };
  const compiled = ts.transpileModule(readFileSync(new URL('./walls-store.ts', import.meta.url), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  vm.runInNewContext(compiled, {
    module, exports: module.exports, console,
    require: (name: string) => {
      if (name === 'zustand') return { create };
      if (name === '@/lib/api/client') return { resourceAPI };
      if (name === 'zustand/middleware') return {
        persist: (initializer: Parameters<typeof persist>[0], options: Parameters<typeof persist>[1]) =>
          persist(initializer, { ...options, storage: createJSONStorage(() => storage) }),
      };
      throw new Error(`Unexpected import ${name}`);
    },
  });
  const store = module.exports.useWallsStore;
  assert.deepEqual(Array.from(store.getState().walls, (wall) => wall.id), ['guest-wall']);
  assert.equal(store.getState().selectedWall?.id, 'default-wall');
  await store.getState().fetchWalls();
  assert.equal(resourceReads, 0);
  store.getState().clearRemoteWalls('owner-a');
  await store.getState().fetchWalls();
  assert.equal(store.getState().walls.find((wall) => wall.id === privateWall.id)?.name, privateWall.name);
  store.getState().clearRemoteWalls();
  assert.equal(store.getState().walls.some((wall) => wall.id === privateWall.id), false);
});
