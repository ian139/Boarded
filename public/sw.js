const versionParam = new URL(self.location.href).searchParams.get('v') || 'dev';
const CACHE_NAME = `boarded-public-v2-${versionParam}`;
// These client-rendered pages contain no account data until their API calls run.
// Only anonymous, query-free copies fetched at installation may be persisted.
const SHELL_ROUTES = new Set(['/', '/editor']);
const STATIC_ASSETS = new Set([
  '/manifest.json',
  '/icon.png',
  '/apple-touch-icon.png',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
  '/walls/default-wall.jpg',
]);
const PRIVATE_PATH = /^\/(?:api|auth|login|signup|recovery|reset|reset-password|forgot-password|profile|settings|share|files|storage)(?:\/|$)/;
const FORBIDDEN_CACHE_CONTROL = /(?:^|,)\s*(?:no-store|no-cache|private)\b/i;

function canStore(response) {
  return response.ok &&
    response.type !== 'opaque' &&
    !response.redirected &&
    !FORBIDDEN_CACHE_CONTROL.test(response.headers.get('Cache-Control') || '') &&
    !/(?:^|,)\s*(?:\*|cookie|authorization)\s*(?:,|$)/i.test(response.headers.get('Vary') || '');
}

async function purgeCaches(keepCurrent = false) {
  const keys = await caches.keys();
  await Promise.all(keys
    .filter((key) => key.startsWith('boarded-') && (!keepCurrent || key !== CACHE_NAME))
    .map((key) => caches.delete(key)));
}

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await Promise.all([...SHELL_ROUTES, ...STATIC_ASSETS].map(async (path) => {
      try {
        // Never precache a signed-in response, including from the HTTP cache.
        const response = await fetch(new Request(new URL(path, self.location.origin), {
          credentials: 'omit',
          cache: 'reload',
          redirect: 'error',
        }));
        if (canStore(response) &&
            (!SHELL_ROUTES.has(path) || response.headers.get('Content-Type')?.includes('text/html'))) {
          await cache.put(path, response);
        }
      } catch {
        // Missing/offline assets must not prevent replacement of an unsafe worker.
      }
    }));
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    await purgeCaches(true);
    await self.clients.claim();
  })());
});

self.addEventListener('message', (event) => {
  if (event.data?.type === 'CLEAR_PRIVATE_DATA') {
    event.waitUntil(purgeCaches(true));
  }
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // API includes all private file bytes. Also bypass HTTP caching for account
  // pages and any navigation not explicitly eligible for the guest fallback.
  const isGuestShell = SHELL_ROUTES.has(url.pathname) && !url.search;
  if (PRIVATE_PATH.test(url.pathname) ||
      (request.mode === 'navigate' && !isGuestShell)) {
    event.respondWith(fetch(new Request(request, { cache: 'no-store' })));
    return;
  }
  if (request.method !== 'GET') return;
  if (request.cache === 'no-store' || request.cache === 'no-cache' ||
      request.headers.has('Authorization') ||
      FORBIDDEN_CACHE_CONTROL.test(request.headers.get('Cache-Control') || '')) {
    return;
  }

  if (request.mode === 'navigate') {
    // Never write a user's navigation response. Only installation's anonymous
    // shell is an offline fallback, never a private route or query-bearing URL.
    event.respondWith(fetch(new Request(request, { cache: 'no-store' })).catch(async () => {
      const cache = await caches.open(CACHE_NAME);
      return (await cache.match(url.pathname)) || Response.error();
    }));
    return;
  }

  if (!url.pathname.startsWith('/_next/static/') && !STATIC_ASSETS.has(url.pathname)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request);
    if (cached) return cached;
    // Persist only public static bytes, fetched without session credentials.
    const response = await fetch(new Request(request, { credentials: 'omit', redirect: 'error' }));
    if (canStore(response)) await cache.put(request, response.clone());
    return response;
  })());
});
