import 'server-only';
import { ApiError } from './http';

export function invalid(message: string): never { throw new ApiError(422, 'invalid_payload', message); }
export function uuid(value: unknown): string {
  if (typeof value !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) invalid('Invalid record ID');
  return value.toLowerCase();
}
export async function body(request: Request): Promise<Record<string, unknown>> {
  if (!request.headers.get('content-type')?.startsWith('application/json')) throw new ApiError(415, 'unsupported_media_type', 'JSON required');
  const reader = request.body?.getReader();
  if (!reader) invalid('Request body required');
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 256 * 1024) { await reader.cancel(); throw new ApiError(413, 'payload_too_large', 'JSON exceeds 256 KiB'); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  let value: unknown;
  try { value = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { invalid('Invalid JSON'); }
  if (!value || typeof value !== 'object' || Array.isArray(value)) invalid('JSON object required');
  return value as Record<string, unknown>;
}
type Validator = (value: unknown) => unknown;
const text = (max: number, nullable = true): Validator => value => {
  if (value === null && nullable) return null;
  if (typeof value !== 'string' || value.length > max || (!nullable && !value.trim())) invalid(`Expected text up to ${max} characters`);
  return value;
};
const boolean: Validator = value => { if (typeof value !== 'boolean') invalid('Expected boolean'); return value; };
const number = (min: number, max: number, integer = false): Validator => value => {
  if (value === null) return null;
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max || (integer && !Number.isInteger(value))) invalid('Number outside allowed range');
  return value;
};
const image: Validator = value => {
  if (value === null || value === '/walls/default-wall.jpg') return value;
  if (typeof value !== 'string' || !value.startsWith('/api/files/')) invalid('Upload an image before associating it');
  return `/api/files/${uuid(value.slice('/api/files/'.length))}`;
};
const holds: Validator = value => {
  if (!Array.isArray(value) || value.length > 500) invalid('Expected at most 500 holds');
  return value.map(item => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) invalid('Invalid hold');
    const h = item as Record<string, unknown>;
    if (Object.keys(h).some(key => !['id','x','y','type','color','sequence','size','notes'].includes(key))) invalid('Unknown hold field');
    text(128, false)(h.id); number(0,100)(h.x); number(0,100)(h.y);
    if (h.x === null || h.y === null || !['start','hand','foot','finish'].includes(String(h.type)) || !['small','medium','large'].includes(String(h.size))) invalid('Invalid hold position or type');
    text(64,false)(h.color); number(0,10000,true)(h.sequence);
    if (h.notes !== undefined) text(2000)(h.notes);
    return h;
  });
};
const definitions: Record<string, Record<string, Validator>> = {
  route: { wall_id: text(200,false), name: text(200,false), description: text(10000), grade_v: text(24), grade_font: text(24), rating: number(1,5), holds, is_public: boolean, share_token: value => {
    if (value === null) return null;
    if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(value)) invalid('Invalid share token');
    return value;
  }, wall_image_url: image, wall_image_width: number(1,10000,true), wall_image_height: number(1,10000,true) },
  wall: { name: text(200,false), description: text(10000), image_url: value => { if (value === null) invalid('Wall image required'); return image(value); }, image_width: number(1,10000,true), image_height: number(1,10000,true), is_public: boolean },
  profile: { username: value => { if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,80}$/.test(value)) invalid('Invalid username'); return value; }, full_name: text(200), avatar_url: image, bio: text(2000), home_area: value => { const result = text(120)(value); if (typeof result === 'string' && !result.trim()) invalid('Home area cannot be blank'); return result; } },
  ascent: { grade_v: text(24), rating: number(1,5,true), notes: text(10000), flashed: boolean },
  comment: { content: text(2000,false), is_beta: boolean },
};
export function payload(kind: string, input: Record<string, unknown>, create = false): Record<string, unknown> {
  const validators = definitions[kind];
  const output: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(input)) {
    if (key === 'id' && create) { output.id = uuid(value); continue; }
    const validator = validators[key];
    if (!Object.hasOwn(validators,key)) invalid(`Field ${key} is not editable`);
    output[key] = validator(value);
  }
  if (create) {
    const required: Record<string,string[]> = { route: ['id','wall_id','name'], wall: ['id','name','image_url'], ascent: [], comment: ['content'], profile: [] };
    for (const key of required[kind]) if (output[key] === undefined) invalid(`Missing ${key}`);
  }
  return output;
}
