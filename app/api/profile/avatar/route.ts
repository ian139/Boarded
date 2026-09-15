import { endpoint, json, requireActor } from '@/lib/server/http';
import { transaction } from '@/lib/server/db';
import { uploadAvatar, attachFile } from '@/lib/server/files';
import { ensureProfile } from '@/lib/server/resources';
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export const POST = endpoint(async request => {
  const user = await requireActor(request);
  const image = await uploadAvatar(request,user);
  const profile = await transaction(async client => {
    await ensureProfile(client,user);
    await attachFile(client,image.url,{actor:user,purpose:'avatar',entityId:user.id});
    return (await client.query('UPDATE profiles SET avatar_url=$2,updated_at=now() WHERE id=$1 RETURNING *',[user.id,image.url])).rows[0];
  });
  return json({profile,avatar_url:image.url});
});
