import 'server-only';
import { randomUUID } from 'node:crypto';
import type { Pool, PoolClient, QueryResultRow } from 'pg';
import { pool, transaction } from './db';
import { actor, ApiError, endpoint, json, requireActor, type Actor } from './http';
import { attachFile } from './files';
import { body, payload, uuid, invalid } from './validation';

const routeSelect = `SELECT r.*, r.rating::double precision AS rating,
  COALESCE((SELECT jsonb_agg(a ORDER BY a.created_at,a.id) FROM ascents a WHERE a.route_id=r.id),'[]'::jsonb) AS ascents,
  COALESCE((SELECT jsonb_agg(c ORDER BY c.created_at,c.id) FROM comments c WHERE c.route_id=r.id),'[]'::jsonb) AS comments,
  COALESCE((SELECT jsonb_agg(l.user_id ORDER BY l.user_id) FROM route_likes l WHERE l.route_id=r.id),'[]'::jsonb) AS liked_by,
  (SELECT count(*)::int FROM route_likes l WHERE l.route_id=r.id) AS like_count,
  EXISTS(SELECT 1 FROM route_likes l WHERE l.route_id=r.id AND l.user_id=$1::uuid) AS is_liked
  FROM routes r`;
const access = '(r.is_public=true OR r.user_id=$1::uuid OR $2::boolean)';
function identity(user: Actor | null) { return [user?.id || null, user?.isModerator || false]; }
export async function readRoute(id: string, user: Actor | null, client: PoolClient | Pool = pool()) {
  const result = await client.query(`${routeSelect} WHERE r.id=$3 AND ${access}`, [...identity(user), id]);
  if (!result.rows[0]) throw new ApiError(404, 'not_found', 'Route not found');
  return result.rows[0];
}
async function lockedRoute(client: PoolClient, id: string, user: Actor, manage = false) {
  const result = await client.query('SELECT * FROM routes WHERE id=$1 FOR UPDATE', [id]);
  const row = result.rows[0];
  if (!row || !(row.is_public || row.user_id === user.id || user.isModerator)) throw new ApiError(404, 'not_found', 'Route not found');
  if (manage && row.user_id !== user.id && !user.isModerator) throw new ApiError(403, 'forbidden', 'You do not own this route');
  return row;
}
function valuesFor(data: Record<string, unknown>) {
  return Object.entries(data).map(([key,value]) => [key, key === 'holds' ? JSON.stringify(value) : value] as const);
}
async function insert(client: PoolClient, table: 'routes'|'walls'|'ascents'|'comments', data: Record<string,unknown>) {
  const values = valuesFor(data);
  return client.query(`INSERT INTO ${table} (${values.map(([key]) => key).join(',')}) VALUES (${values.map((_,i) => `$${i+1}`).join(',')}) ON CONFLICT (id) DO NOTHING RETURNING *`, values.map(([,value]) => value));
}
async function update(client: PoolClient, table: 'routes'|'walls'|'profiles', id: string, data: Record<string,unknown>) {
  const values = valuesFor(data);
  if (!values.length) invalid('No editable fields supplied');
  return client.query(`UPDATE ${table} SET ${values.map(([key],i) => `${key}=$${i+2}`).join(',')},updated_at=now() WHERE id=$1 RETURNING *`, [id,...values.map(([,value]) => value)]);
}

export const listRoutes = endpoint(async request => {
  const user = await actor(request);
  return json((await pool().query(`${routeSelect} WHERE ${access} ORDER BY r.created_at DESC,r.id`, identity(user))).rows);
});
export const getRoute = endpoint(async (request, context) => json(await readRoute(uuid((await context.params).id), await actor(request))));
export const getShare = endpoint(async (_request, context) => {
  const { token } = await context.params;
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(token)) throw new ApiError(404,'not_found','Shared route not found');
  const result = await pool().query(`${routeSelect} WHERE r.share_token=$2 AND r.is_public=true`, [null,token]);
  if (!result.rows[0]) throw new ApiError(404,'not_found','Shared route not found');
  return json(result.rows[0]);
});
export const createRoute = endpoint(async request => {
  const user = await requireActor(request);
  const data = payload('route',await body(request),true);
  const id = uuid(data.id);
  return json(await transaction(async client => {
    // Serialize same-id offline retries before checking ownership or attaching files.
    await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`route:${id}`]);
    const existing = (await client.query('SELECT user_id FROM routes WHERE id=$1 FOR UPDATE',[id])).rows[0];
    if (existing) {
      if (existing.user_id !== user.id) throw new ApiError(409,'conflict','This route ID belongs to another account');
      return readRoute(id,user,client);
    }
    await attachFile(client, typeof data.wall_image_url === 'string' ? data.wall_image_url : null, {actor:user,purpose:'route-snapshot',entityId:id});
    await insert(client,'routes',{is_public:false,holds:[],...data,user_id:user.id,user_name:user.displayName});
    return readRoute(id,user,client);
  }),201);
});
export const patchRoute = endpoint(async (request, context) => {
  const user = await requireActor(request), id = uuid((await context.params).id);
  const data = payload('route',await body(request));
  return json(await transaction(async client => {
    await lockedRoute(client,id,user,true);
    if ('wall_image_url' in data) await attachFile(client,typeof data.wall_image_url === 'string' ? data.wall_image_url : null,{actor:user,purpose:'route-snapshot',entityId:id});
    await update(client,'routes',id,data);
    return readRoute(id,user,client);
  }));
});
export const deleteRoute = endpoint(async (request, context) => {
  const user = await requireActor(request), id = uuid((await context.params).id);
  await transaction(async client => { await lockedRoute(client,id,user,true); await client.query('DELETE FROM routes WHERE id=$1',[id]); });
  return json({id});
});

export const listWalls = endpoint(async request => {
  const user = await actor(request);
  return json((await pool().query('SELECT * FROM walls WHERE is_public=true OR user_id=$1 OR $2::boolean ORDER BY created_at DESC,id',identity(user))).rows);
});
async function lockedWall(client: PoolClient,id:string,user:Actor) {
  const row = (await client.query('SELECT * FROM walls WHERE id=$1 FOR UPDATE',[id])).rows[0];
  if (!row || !(row.is_public || row.user_id === user.id || user.isModerator)) throw new ApiError(404,'not_found','Wall not found');
  if (row.user_id !== user.id && !user.isModerator) throw new ApiError(403,'forbidden','You do not own this wall');
  return row;
}
export const createWall = endpoint(async request => {
  const user = await requireActor(request), data = payload('wall',await body(request),true), id = uuid(data.id);
  return json(await transaction(async client => {
    await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`wall:${id}`]);
    const existing = (await client.query('SELECT * FROM walls WHERE id=$1 FOR UPDATE',[id])).rows[0];
    if (existing) {
      if (existing.user_id !== user.id) throw new ApiError(409,'conflict','This wall ID belongs to another account');
      return existing;
    }
    await attachFile(client,String(data.image_url),{actor:user,purpose:'wall',entityId:id});
    return (await insert(client,'walls',{is_public:false,...data,user_id:user.id})).rows[0];
  }),201);
});
export const patchWall = endpoint(async (request,context) => {
  const user = await requireActor(request), id = uuid((await context.params).id), data = payload('wall',await body(request));
  return json(await transaction(async client => {
    await lockedWall(client,id,user);
    if ('image_url' in data) await attachFile(client,String(data.image_url),{actor:user,purpose:'wall',entityId:id});
    return (await update(client,'walls',id,data)).rows[0];
  }));
});
export const deleteWall = endpoint(async (request,context) => {
  const user = await requireActor(request), id = uuid((await context.params).id);
  await transaction(async client => { await lockedWall(client,id,user); await client.query('DELETE FROM walls WHERE id=$1',[id]); });
  return json({id});
});

export function saveSocial(kind:'ascent'|'comment', replay:boolean) {
  return endpoint(async (request,context) => {
    const user = await requireActor(request), params = await context.params, routeId = uuid(params.id);
    const input = await body(request);
    const id = replay ? uuid(params.childId) : input.id === undefined ? randomUUID() : uuid(input.id);
    if (replay && input.id !== undefined && uuid(input.id) !== id) invalid('Child ID does not match URL');
    delete input.id;
    const data = payload(kind,input,true), table = kind === 'ascent' ? 'ascents' : 'comments';
    return json(await transaction(async client => {
      await lockedRoute(client,routeId,user);
      const result = await insert(client,table,{id,...data,route_id:routeId,user_id:user.id,user_name:user.displayName});
      if (result.rows[0]) return result.rows[0];
      const existing = (await client.query(`SELECT * FROM ${table} WHERE id=$1 FOR UPDATE`,[id])).rows[0];
      if (!existing || existing.user_id !== user.id || existing.route_id !== routeId) throw new ApiError(409,'conflict','This record ID is already in use');
      // Offline replay is idempotent, not an unrestricted upsert of old content.
      return existing;
    }),replay ? 200 : 201);
  });
}
export const deleteComment = endpoint(async (request,context) => {
  const user = await requireActor(request), params = await context.params, routeId = uuid(params.id), id = uuid(params.childId);
  await transaction(async client => {
    await lockedRoute(client,routeId,user);
    const result = await client.query('DELETE FROM comments WHERE id=$1 AND route_id=$2 AND (user_id=$3 OR $4::boolean) RETURNING id',[id,routeId,user.id,user.isModerator]);
    if (!result.rows[0]) throw new ApiError(404,'not_found','Comment not found or not owned');
  });
  return json({id});
});
export function likeRoute(liked:boolean) {
  return endpoint(async (request,context) => {
    const user = await requireActor(request), id = uuid((await context.params).id);
    return json(await transaction(async client => {
      await lockedRoute(client,id,user);
      if (liked) await client.query('INSERT INTO route_likes(route_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[id,user.id]);
      else await client.query('DELETE FROM route_likes WHERE route_id=$1 AND user_id=$2',[id,user.id]);
      const row = await readRoute(id,user,client);
      return {liked_by:row.liked_by,like_count:row.like_count,is_liked:row.is_liked};
    }));
  });
}
export const incrementViews = endpoint(async (_request,context) => {
  const id = uuid((await context.params).id);
  const result = await pool().query('UPDATE routes SET view_count=coalesce(view_count,0)+1,updated_at=now() WHERE id=$1 AND is_public=true RETURNING view_count',[id]);
  if (!result.rows[0]) throw new ApiError(404,'not_found','Public route not found');
  return json(result.rows[0]);
});

export async function ensureProfile(client:PoolClient,user:Actor):Promise<QueryResultRow> {
  await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[`profile:${user.id}`]);
  const existing = (await client.query('SELECT * FROM profiles WHERE id=$1 FOR UPDATE',[user.id])).rows[0];
  if (existing) return existing;
  const prefix = user.displayName.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'').slice(0,12) || 'climber';
  // Imported or user-chosen handles can occupy any generated candidate.
  for (let attempt = 0; attempt < 8; attempt++) {
    const username = `${prefix}-${randomUUID().slice(0,8)}`;
    const created = (await client.query('INSERT INTO profiles(id,username,full_name) VALUES($1,$2,$3) ON CONFLICT DO NOTHING RETURNING *',[user.id,username,user.displayName])).rows[0];
    if (created) return created;
  }
  throw new Error('Unable to allocate a unique profile username');
}
export const getProfile = endpoint(async request => {
  const user = await requireActor(request);
  return json(await transaction(client => ensureProfile(client,user)));
});
export const patchProfile = endpoint(async request => {
  const user = await requireActor(request), data = payload('profile',await body(request));
  return json(await transaction(async client => {
    await ensureProfile(client,user);
    if ('avatar_url' in data) await attachFile(client,typeof data.avatar_url === 'string' ? data.avatar_url : null,{actor:user,purpose:'avatar',entityId:user.id});
    return (await update(client,'profiles',user.id,data)).rows[0];
  }));
});
