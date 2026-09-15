import { saveSocial } from '@/lib/server/resources';
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const PUT = saveSocial('comment',true);
export { deleteComment as DELETE } from '@/lib/server/resources';
