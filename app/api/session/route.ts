import { actor, endpoint, json } from '@/lib/server/http';
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const GET = endpoint(async request => json({user:await actor(request)}));
