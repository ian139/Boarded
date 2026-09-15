import { constants } from 'node:fs';
import { access, realpath, stat } from 'node:fs/promises';
import path from 'node:path';
import { auth } from '@/lib/server/auth';
import { pool } from '@/lib/server/db';
import { json } from '@/lib/server/http';
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
export async function GET() {
  try {
    auth(); // Validate auth, origin and mail configuration without connecting SMTP.
    const configured = process.env.UPLOAD_DIR;
    if (!configured || !path.isAbsolute(configured)) throw new Error('Invalid upload directory');
    const directory = await realpath(configured);
    const publicDirectory = await realpath(path.join(process.cwd(),'public'));
    const relative = path.relative(publicDirectory,directory);
    if (!relative || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative))) throw new Error('Public upload directory');
    if (!(await stat(directory)).isDirectory()) throw new Error('Upload path is not a directory');
    await access(directory,constants.R_OK | constants.W_OK);
    const result = await pool().query(`SELECT
      (SELECT rolsuper OR rolcreatedb OR rolcreaterole OR rolbypassrls FROM pg_roles WHERE rolname=current_user) AS elevated,
      EXISTS(SELECT 1 FROM schema_migrations WHERE version='003_retained_social.sql') AS migrated,
      (SELECT bool_and(has_table_privilege(current_user,t.name,p.name))
        FROM unnest(ARRAY['public.routes','public.walls','public.profiles','public.ascents','public.comments','public.files','public.file_references']) t(name)
        CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE']) p(name)) AS domain_access,
      (SELECT bool_and(has_table_privilege(current_user,t.name,p.name))
        FROM unnest(ARRAY['public."user"','public."session"','public.account','public.verification','public."rateLimit"']) t(name)
        CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE']) p(name)) AS auth_access,
      has_table_privilege(current_user,'public.user_roles','INSERT,UPDATE,DELETE,TRUNCATE') AS role_write,
      has_schema_privilege(current_user,'public','CREATE') AS schema_write`);
    const state = result.rows[0];
    if (state.elevated || !state.migrated || !state.domain_access || !state.auth_access || state.role_write || state.schema_write) throw new Error('Database is not ready');
    return json({status:'ok'});
  } catch {
    return json({status:'unavailable'},503);
  }
}
