import { auth } from '@/lib/server/auth';
import { endpoint } from '@/lib/server/http';
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
const handler = endpoint<{ all: string[] }>(async request => {
  const response = await auth().handler(request);
  response.headers.set('Cache-Control','private, no-store');
  response.headers.set('Vary','Cookie');
  return response;
});
export const GET = handler;
export const POST = handler;
