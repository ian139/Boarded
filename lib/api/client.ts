'use client';

export interface SessionUser {
  id: string;
  email: string;
  displayName: string;
  createdAt: string;
  isModerator: boolean;
}

export class ResourceError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
    public readonly payload: unknown = null,
  ) {
    super(message);
    this.name = 'ResourceError';
  }
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const headers = new Headers(options.headers);
  if (options.body && !(options.body instanceof FormData)) headers.set('Content-Type', 'application/json');
  headers.set('Accept', 'application/json');
  const response = await fetch(path, { ...options, headers, credentials: 'same-origin', cache: 'no-store' });
  const body = await response.json().catch(() => null);
  if (!response.ok) {
    throw new ResourceError(
      response.status,
      body?.error?.code || 'REQUEST_FAILED',
      body?.error?.message || `Request failed (${response.status})`,
      body,
    );
  }
  return body as T;
}

async function upload(file: Blob, purpose: 'wall' | 'route-snapshot', association: { wall_id?: string; route_id?: string }) {
  const form = new FormData();
  form.set('file', file, file.type === 'image/png' ? 'image.png' : 'image.jpg');
  form.set('purpose', purpose);
  if (association.wall_id) form.set('wall_id', association.wall_id);
  if (association.route_id) form.set('route_id', association.route_id);
  return request<{ id: string; url: string; width: number; height: number }>('/api/files', { method: 'POST', body: form });
}

async function clearPrivateCaches() {
  if (typeof window === 'undefined') return;
  localStorage.removeItem('boarded-storage-history');
  localStorage.removeItem('boarded-user');
  navigator.serviceWorker?.controller?.postMessage({ type: 'CLEAR_PRIVATE_DATA' });
  if ('caches' in window) {
    const names = await caches.keys();
    await Promise.all(names
      .filter((name) => name.startsWith('boarded-') && !name.startsWith('boarded-public-v2-'))
      .map((name) => caches.delete(name)));
  }
}

export const resourceAPI = {
  request,
  upload,
  clearPrivateCaches,
  session: () => request<{ user: SessionUser | null }>('/api/session'),
};
