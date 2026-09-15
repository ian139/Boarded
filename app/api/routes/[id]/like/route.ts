import { likeRoute } from '@/lib/server/resources';
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const PUT = likeRoute(true);
export const DELETE = likeRoute(false);
