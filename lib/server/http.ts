import 'server-only';
import { auth, origin } from './auth';
import { pool } from './db';

export interface Actor { id: string; email: string; displayName: string; createdAt: string; isModerator: boolean }
export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string) { super(message); }
}
export function json(value: unknown, status = 200): Response {
  return Response.json(value, { status, headers: { 'Cache-Control': 'private, no-store', 'Vary': 'Cookie', 'X-Content-Type-Options': 'nosniff' } });
}
export async function actor(request: Request): Promise<Actor | null> {
  const session = await auth().api.getSession({ headers: request.headers });
  if (!session || !session.user.emailVerified) return null;
  const roles = await pool().query('SELECT role FROM user_roles WHERE user_id=$1', [session.user.id]);
  return { id: session.user.id, email: session.user.email, displayName: session.user.name,
    createdAt: new Date(session.user.createdAt).toISOString(), isModerator: roles.rows.some(row => row.role === 'moderator') };
}
export async function requireActor(request: Request): Promise<Actor> {
  const user = await actor(request);
  if (!user) throw new ApiError(401, 'unauthenticated', 'Sign in to continue');
  return user;
}
export async function requireModerator(request: Request): Promise<Actor> {
  const user = await requireActor(request);
  if (!user.isModerator) throw new ApiError(403, 'forbidden', 'Moderator access required');
  return user;
}
export interface RouteContext<Parameters extends Record<string, string | string[]> = Record<string, string>> {
  params: Promise<Parameters>;
}
export function endpoint<Parameters extends Record<string, string | string[]> = Record<string, string>>(
  handler: (request: Request, context: RouteContext<Parameters>) => Promise<Response>,
) {
  return async (request: Request, context: RouteContext<Parameters>) => {
    try {
      if (!['GET', 'HEAD', 'OPTIONS'].includes(request.method)) {
        if (request.headers.get('origin') !== origin() || request.headers.get('sec-fetch-site') === 'cross-site') {
          throw new ApiError(403, 'invalid_origin', 'Same-origin request required');
        }
      }
      return await handler(request, context);
    } catch (error) {
      if (error instanceof ApiError) return json({ error: { code: error.code, message: error.message } }, error.status);
      const code = error && typeof error === 'object' && 'code' in error && typeof error.code === 'string' ? error.code : undefined;
      if (code === '23505') return json({ error: { code: 'conflict', message: 'This record already exists' } }, 409);
      if (code === '23503') return json({ error: { code: 'conflict', message: 'A referenced record changed; refresh and retry' } }, 409);
      console.error('API request failed', { method: request.method, code: code || 'internal' });
      return json({ error: { code: 'internal', message: 'The request could not be completed' } }, 500);
    }
  };
}
