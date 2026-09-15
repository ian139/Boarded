import "server-only";

import { createHash, randomUUID } from "node:crypto";
import { constants } from "node:fs";
import { mkdir, open, realpath, unlink } from "node:fs/promises";
import path from "node:path";
import type { PoolClient } from "pg";
import sharp, { type OutputInfo } from "sharp";
import { pool, transaction } from "./db";
import { actor as getActor, ApiError, json, requireActor, requireModerator, type Actor } from "./http";

export type FilePurpose = "wall" | "route-snapshot" | "avatar";
type FileRow = {
  id: string;
  owner_id: string | null;
  purpose: FilePurpose;
  entity_id: string | null;
  mime_type: string;
  bytes: string;
  checksum: string;
  width: number;
  height: number;
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MAX_FILE_BYTES = 10 * 1024 * 1024;
const MAX_BODY_BYTES = MAX_FILE_BYTES + 64 * 1024;
const MAX_PIXELS = 25_000_000;
// Server-owned budgets include every stored file, including unreferenced uploads.
const MAX_ACCOUNT_BYTES = 250 * 1024 * 1024;
const MAX_ACCOUNT_FILES = 500;
const MAX_STORED_BYTES = 10 * 1024 * 1024 * 1024;
const MAX_STORED_FILES = 10_000;
// Production runs one standalone Node process. Share across route bundles; never queue decodes.
const uploadState = globalThis as typeof globalThis & { boardedUploadsInFlight?: number };
const MAX_UPLOADS_IN_FLIGHT = 2;
const STATIC_WALL = "/walls/default-wall.jpg";
const FILE_URL = /^\/api\/files\/([0-9a-f-]{36})$/;
const UNREFERENCED = `NOT EXISTS (SELECT 1 FROM file_references r WHERE r.file_id = f.id)
  AND NOT EXISTS (SELECT 1 FROM walls w WHERE w.image_url = '/api/files/' || f.id::text)
  AND NOT EXISTS (SELECT 1 FROM routes r WHERE r.wall_image_url = '/api/files/' || f.id::text)
  AND NOT EXISTS (SELECT 1 FROM profiles p WHERE p.avatar_url = '/api/files/' || f.id::text)`;

function invalid(message: string): never {
  throw new ApiError(422, "invalid_file", message);
}

function uuid(value: string, label: string): string {
  if (!UUID.test(value)) invalid(`${label} must be a UUID`);
  return value.toLowerCase();
}

function isErrno(error: unknown, code: string): error is NodeJS.ErrnoException {
  return error instanceof Error && "code" in error && error.code === code;
}

async function uploadDirectory(): Promise<string> {
  const configured = process.env.UPLOAD_DIR;
  if (!configured || !path.isAbsolute(configured)) {
    throw new Error("UPLOAD_DIR must be an absolute directory outside public");
  }
  await mkdir(configured, { recursive: true, mode: 0o700 });
  const directory = await realpath(configured);
  const publicDirectory = await realpath(path.join(process.cwd(), "public"));
  const relative = path.relative(publicDirectory, directory);
  if (!relative || (!relative.startsWith(`..${path.sep}`) && relative !== ".." && !path.isAbsolute(relative))) {
    throw new Error("UPLOAD_DIR must not be inside public");
  }
  return directory;
}

// The caller holds the metadata row lock until reading or attachment has completed.
async function verifiedFileBytes(file: FileRow): Promise<Buffer> {
  let handle;
  try {
    handle = await open(path.join(await uploadDirectory(), file.id), constants.O_RDONLY | constants.O_NOFOLLOW);
  } catch (error) {
    if (isErrno(error, "ENOENT")) throw new ApiError(409, "file_unavailable", "Image bytes are missing; upload the image again");
    throw error;
  }
  try {
    const stat = await handle.stat();
    if (!stat.isFile() || stat.size !== Number(file.bytes) || stat.size > MAX_FILE_BYTES) {
      throw new ApiError(409, "file_unavailable", "Image bytes are incomplete; upload the image again");
    }
    const bytes = await handle.readFile();
    if (bytes.byteLength !== Number(file.bytes) || createHash("sha256").update(bytes).digest("hex") !== file.checksum) {
      throw new ApiError(409, "file_unavailable", "Image integrity check failed; upload the image again");
    }
    return bytes;
  } finally {
    await handle.close();
  }
}

// Limit bytes while consuming the stream, before the multipart parser can allocate.
async function boundedBody(request: Request, maximum: number): Promise<Uint8Array<ArrayBuffer>> {
  const advertised = request.headers.get("content-length");
  if (advertised && (!/^\d+$/.test(advertised) || Number(advertised) > maximum)) {
    throw new ApiError(413, "body_too_large", "Request body is too large");
  }
  if (!request.body) invalid("A request body is required");
  const reader = request.body.getReader();
  const bytes = new Uint8Array(maximum);
  let length = 0;
  let timer: NodeJS.Timeout | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      reject(new ApiError(408, "upload_timeout", "Request body took too long"));
      void reader.cancel().catch(() => undefined);
    }, 30_000);
  });
  try {
    for (;;) {
      const part = await Promise.race([reader.read(), timeout]);
      if (part.done) break;
      length += part.value.byteLength;
      if (length > maximum) {
        void reader.cancel().catch(() => undefined);
        throw new ApiError(413, "body_too_large", "Request body is too large");
      }
      bytes.set(part.value, length - part.value.byteLength);
    }
    return bytes.subarray(0, length);
  } finally {
    clearTimeout(timer);
    reader.releaseLock();
  }
}

async function multipart(request: Request): Promise<FormData> {
  const contentType = request.headers.get("content-type");
  if (!contentType?.toLowerCase().startsWith("multipart/form-data;")) {
    invalid("Expected a multipart image upload");
  }
  const bytes = await boundedBody(request, MAX_BODY_BYTES);
  try {
    return await new Response(bytes, { headers: { "content-type": contentType } }).formData();
  } catch {
    return invalid("Malformed multipart upload");
  }
}

function field(form: FormData, name: string): string | null {
  const value = form.get(name);
  if (value === null) return null;
  if (typeof value !== "string" || value.length > 160 || !value.trim()) invalid(`Invalid ${name}`);
  return value;
}

async function saveUpload(request: Request, actor: Actor, avatar: boolean) {
  // Both callers authenticate before entering this process-wide admission gate.
  if ((uploadState.boardedUploadsInFlight ?? 0) >= MAX_UPLOADS_IN_FLIGHT) {
    throw new ApiError(429, "upload_busy", "Uploads are busy; try again shortly");
  }
  uploadState.boardedUploadsInFlight = (uploadState.boardedUploadsInFlight ?? 0) + 1;
  try {
    const client = await pool().connect();
    let accountLocked: boolean | undefined;
    let transactionOpen = false;
    let discardClient = false;
    try {
      // A session lock spans decoding and disk I/O without holding a transaction open.
      const accountLock = await client.query<{ acquired: boolean }>(
        "SELECT pg_try_advisory_lock(hashtextextended('upload:' || $1::text, 0)) AS acquired",
        [actor.id],
      );
      accountLocked = accountLock.rows[0].acquired;
      if (!accountLocked) {
        throw new ApiError(429, "upload_busy", "Another upload for this account is in progress");
      }
      const budgetSql = `SELECT COUNT(*)::text AS files, COALESCE(SUM(bytes), 0)::text AS bytes,
        COUNT(*) FILTER (WHERE owner_id = $1)::text AS account_files,
        COALESCE(SUM(bytes) FILTER (WHERE owner_id = $1), 0)::text AS account_bytes FROM files`;
      type Budget = { files: string; bytes: string; account_files: string; account_bytes: string };
      const initialBudget = (await client.query<Budget>(budgetSql, [actor.id])).rows[0];
      if (Number(initialBudget.account_files) >= MAX_ACCOUNT_FILES || Number(initialBudget.account_bytes) >= MAX_ACCOUNT_BYTES) {
        throw new ApiError(413, "storage_quota", "Account image storage limit reached (250 MiB or 500 files)");
      }
      // Early global check is advisory-free; the final check below is serialized across processes.
      if (Number(initialBudget.files) >= MAX_STORED_FILES || Number(initialBudget.bytes) >= MAX_STORED_BYTES) {
        throw new ApiError(413, "storage_quota", "Server image storage limit reached (10 GiB or 10000 files)");
      }
      const form = await multipart(request);
      const allowed: Record<string, true> = avatar ? { file: true } : { file: true, purpose: true, wall_id: true, route_id: true };
      const seen = new Set<string>();
      for (const key of form.keys()) {
        if (!Object.hasOwn(allowed, key) || seen.has(key)) invalid(`Unexpected or duplicate upload field: ${key}`);
        seen.add(key);
      }
      const file = form.get("file");
      if (!file || typeof file === "string" || !file.size) invalid("An image file is required");
      if (file.size > MAX_FILE_BYTES) throw new ApiError(413, "file_too_large", "Image must be at most 10 MiB");
      const purpose = avatar ? "avatar" : field(form, "purpose");
      if (purpose !== "wall" && purpose !== "route-snapshot" && purpose !== "avatar") invalid("Invalid file purpose");
      if (!avatar && purpose === "avatar") invalid("Use the avatar endpoint for avatars");
      const wallId = avatar ? null : field(form, "wall_id");
      const routeId = avatar ? null : field(form, "route_id");
      if (purpose === "wall" && routeId) invalid("Wall images cannot have a route_id");
      const entityId = avatar ? actor.id : purpose === "wall"
        ? (wallId ? uuid(wallId, "wall_id") : null)
        : (routeId ? uuid(routeId, "route_id") : null);
      const mimeFormats: Record<string, string> = { "image/jpeg": "jpeg", "image/png": "png", "image/webp": "webp" };
      if (!Object.hasOwn(mimeFormats, file.type)) invalid("Only JPEG, PNG, and WebP images are supported");
      const input = Buffer.from(await file.arrayBuffer());
      let result: { data: Buffer; info: OutputInfo };
      try {
        const image = sharp(input, { limitInputPixels: MAX_PIXELS, failOn: "warning", animated: false }).timeout({ seconds: 15 });
        const metadata = await image.metadata();
        if (metadata.format !== mimeFormats[file.type] || (metadata.pages ?? 1) !== 1 || !metadata.width || !metadata.height) {
          invalid("Image format does not match its content, or image is animated");
        }
        // Re-encoding strips source metadata and prevents serving uploaded active content.
        result = await image.rotate().webp({ quality: 85, effort: 4 }).toBuffer({ resolveWithObject: true });
      } catch (error) {
        if (error instanceof ApiError) throw error;
        return invalid("Image could not be safely decoded; maximum resolution is 25 megapixels");
      }
      if (result.data.byteLength > MAX_FILE_BYTES) throw new ApiError(413, "file_too_large", "Processed image is too large");
      // Serialize only storage admission, not expensive decodes. Includes owner-null files.
      transactionOpen = true;
      await client.query("BEGIN ISOLATION LEVEL READ COMMITTED");
      const globalLock = await client.query<{ acquired: boolean }>(
        "SELECT pg_try_advisory_xact_lock(hashtextextended('upload-global-budget', 0)) AS acquired",
      );
      if (!globalLock.rows[0].acquired) {
        throw new ApiError(429, "upload_busy", "Another upload is being stored; try again shortly");
      }
      const finalBudget = (await client.query<Budget>(budgetSql, [actor.id])).rows[0];
      if (Number(finalBudget.account_files) + 1 > MAX_ACCOUNT_FILES ||
          Number(finalBudget.account_bytes) + result.data.byteLength > MAX_ACCOUNT_BYTES) {
        throw new ApiError(413, "storage_quota", "Image exceeds the account storage limit (250 MiB or 500 files)");
      }
      if (Number(finalBudget.files) + 1 > MAX_STORED_FILES ||
          Number(finalBudget.bytes) + result.data.byteLength > MAX_STORED_BYTES) {
        throw new ApiError(413, "storage_quota", "Image exceeds the server storage limit (10 GiB or 10000 files)");
      }
      const id = randomUUID();
      const filename = path.join(await uploadDirectory(), id);
      await client.query(
        `INSERT INTO files (id, owner_id, purpose, entity_id, wall_id, mime_type, width, height, bytes, checksum)
         VALUES ($1, $2, $3, $4, $5, 'image/webp', $6, $7, $8, $9)`,
        [id, actor.id, purpose, entityId, wallId, result.info.width, result.info.height,
          result.data.byteLength, createHash("sha256").update(result.data).digest("hex")],
      );
      // Commit the byte reservation first: crashes/failed writes remain quota-counted
      // and discoverable by orphan cleanup, even when no disk file was created.
      await client.query("COMMIT");
      transactionOpen = false;
      const handle = await open(filename, "wx", 0o600);
      try {
        await handle.writeFile(result.data);
      } finally {
        await handle.close();
      }
      return { id, url: `/api/files/${id}`, width: result.info.width, height: result.info.height };
    } catch (error) {
      if (transactionOpen) {
        try {
          await client.query("ROLLBACK");
        } catch (rollbackError) {
          discardClient = true;
          throw new AggregateError([error, rollbackError], "Upload failed and its transaction could not be rolled back");
        }
      }
      throw error;
    } finally {
      try {
        // An uncertain acquisition outcome must never return a potentially locked session.
        if (accountLocked === undefined) discardClient = true;
        if (accountLocked && !discardClient) {
          const unlocked = await client.query<{ released: boolean }>(
            "SELECT pg_advisory_unlock(hashtextextended('upload:' || $1::text, 0)) AS released",
            [actor.id],
          );
          if (!unlocked.rows[0].released) throw new Error("Upload account lock could not be released");
        }
      } catch (error) {
        discardClient = true;
        throw error;
      } finally {
        client.release(discardClient);
      }
    }
  } finally {
    uploadState.boardedUploadsInFlight = (uploadState.boardedUploadsInFlight ?? 1) - 1;
  }
}

export async function uploadFile(request: Request): Promise<Response> {
  return json(await saveUpload(request, await requireActor(request), false), 201);
}

export async function uploadAvatar(request: Request, actor: Actor) {
  return saveUpload(request, actor, true);
}

/** Call in the same transaction as the corresponding entity write. */
export async function attachFile(
  client: PoolClient,
  url: string | null,
  options: { actor: Actor; purpose: FilePurpose; entityId: string },
): Promise<void> {
  const entityId = uuid(options.entityId, "entityId");
  if (url === null || (url === STATIC_WALL && options.purpose !== "avatar")) {
    await client.query("DELETE FROM file_references WHERE purpose = $1 AND entity_id = $2", [options.purpose, entityId]);
    return;
  }
  const match = typeof url === "string" ? FILE_URL.exec(url) : null;
  if (!match) invalid("Image URL must identify an uploaded file");
  const id = uuid(match[1], "File ID");
  const { rows } = await client.query<FileRow>("SELECT * FROM files WHERE id = $1 FOR UPDATE", [id]);
  const file = rows[0];
  if (!file) throw new ApiError(404, "file_not_found", "Uploaded file not found");
  if (file.purpose !== options.purpose || (file.entity_id !== null && file.entity_id !== entityId)) {
    throw new ApiError(403, "file_binding", "Image belongs to a different purpose or entity");
  }
  if (file.owner_id !== options.actor.id) {
    const existing = await client.query(
      "SELECT 1 FROM file_references WHERE file_id = $1 AND purpose = $2 AND entity_id = $3",
      [id, options.purpose, entityId],
    );
    if (!options.actor.isModerator || !existing.rowCount) {
      throw new ApiError(403, "file_owner", "Image belongs to a different account");
    }
  }
  await verifiedFileBytes(file);
  await client.query("UPDATE files SET entity_id = $2, updated_at = now() WHERE id = $1", [id, entityId]);
  await client.query(
    `INSERT INTO file_references (file_id, purpose, entity_id) VALUES ($1, $2, $3)
     ON CONFLICT (purpose, entity_id) DO UPDATE SET file_id = EXCLUDED.file_id`,
    [id, options.purpose, entityId],
  );
}

export async function readFileResponse(request: Request, fileId: string): Promise<Response> {
  const id = uuid(fileId, "File ID");
  const actor = await getActor(request);
  return transaction(async (client) => {
    const { rows } = await client.query<FileRow>(
      `SELECT f.* FROM files f WHERE f.id = $1 AND (
        f.owner_id = $2 OR $3 OR EXISTS (
          SELECT 1 FROM file_references fr WHERE fr.file_id = f.id AND (
            (fr.purpose = 'wall' AND EXISTS (SELECT 1 FROM walls w WHERE w.id = fr.entity_id AND w.is_public = true AND w.image_url = '/api/files/' || f.id::text))
            OR (fr.purpose = 'route-snapshot' AND EXISTS (SELECT 1 FROM routes r WHERE r.id = fr.entity_id AND r.is_public = true AND r.wall_image_url = '/api/files/' || f.id::text))
            OR (fr.purpose = 'avatar' AND EXISTS (SELECT 1 FROM profiles p WHERE p.id = fr.entity_id AND p.avatar_url = '/api/files/' || f.id::text))
          )
        )
      ) FOR SHARE OF f`, [id, actor?.id ?? null, actor?.isModerator ?? false],
    );
    const file = rows[0];
    if (!file) throw new ApiError(404, "file_not_found", "Image not found");
    const bytes = await verifiedFileBytes(file);
    return new Response(new Uint8Array(bytes), {
      headers: {
        "Content-Type": file.mime_type,
        "Content-Length": String(bytes.byteLength),
        "Cache-Control": "private, no-store, max-age=0",
        "Vary": "Cookie",
        "X-Content-Type-Options": "nosniff",
        "Content-Disposition": `inline; filename="${id}.webp"`,
        "Content-Security-Policy": "default-src 'none'; sandbox",
      },
    });
  });
}

export async function storageUsage(request: Request): Promise<Response> {
  await requireModerator(request);
  const { rows } = await pool().query<{ wallId: string; bytes: string; latestTs: Date }>(
    `SELECT COALESCE(wall_id, entity_id::text, purpose) AS "wallId", SUM(bytes)::text AS bytes,
      MAX(updated_at) AS "latestTs" FROM files GROUP BY COALESCE(wall_id, entity_id::text, purpose)
      ORDER BY SUM(bytes) DESC`,
  );
  const breakdown = rows.map((row) => ({ ...row, bytes: Number(row.bytes) }));
  return json({ totalBytes: breakdown.reduce((sum, row) => sum + row.bytes, 0), breakdown });
}

export async function cleanupPreview(request: Request): Promise<Response> {
  await requireModerator(request);
  const { rows } = await pool().query(
    `SELECT f.id, f.purpose || ' / ' || COALESCE(f.wall_id, f.entity_id::text, f.id::text) AS label,
      f.bytes::text AS bytes, f.updated_at FROM files f
      WHERE f.updated_at < now() - interval '7 days' AND ${UNREFERENCED}
      ORDER BY f.updated_at, f.id`,
  );
  return json({ files: rows.map((row) => ({ ...row, bytes: Number(row.bytes) })) });
}

export async function cleanupFiles(request: Request): Promise<Response> {
  await requireModerator(request);
  let body: unknown;
  try {
    body = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(await boundedBody(request, 64 * 1024)));
  } catch (error) {
    if (error instanceof ApiError) throw error;
    return invalid("Expected a JSON object with fileIds");
  }
  if (!body || typeof body !== "object" || Array.isArray(body) || !("fileIds" in body)
    || Object.keys(body).length !== 1 || !Array.isArray(body.fileIds) || body.fileIds.length > 1000) {
    invalid("fileIds must be an array of at most 1000 UUIDs");
  }
  const ids = [...new Set(body.fileIds.map((value: unknown) => {
    if (typeof value !== "string") invalid("fileIds must contain UUIDs");
    return uuid(value, "File ID");
  }))].sort();
  const directory = await uploadDirectory();
  const deletedIds: string[] = [];
  const failedIds: string[] = [];
  for (const id of ids) {
    try {
      const deleted = await transaction(async (client) => {
        // Lock first, then re-check in a new statement snapshot after any concurrent attachment commits.
        const locked = await client.query("SELECT id FROM files WHERE id = $1 FOR UPDATE", [id]);
        if (!locked.rowCount) return false;
        const eligible = await client.query(
          `SELECT f.id FROM files f WHERE f.id = $1 AND f.updated_at < now() - interval '7 days' AND ${UNREFERENCED}`, [id],
        );
        if (!eligible.rowCount) return false;
        try {
          await unlink(path.join(directory, id));
        } catch (error) {
          // A previous attempt may have removed bytes before its DB transaction failed.
          if (!isErrno(error, "ENOENT")) throw error;
        }
        await client.query("DELETE FROM files WHERE id = $1", [id]);
        return true;
      });
      if (deleted) deletedIds.push(id);
    } catch {
      failedIds.push(id);
    }
  }
  // Preserve metadata on failed filesystem deletion and report partial progress honestly.
  if (failedIds.length) {
    return json({ error: { code: "cleanup_failed", message: "Some files could not be deleted; retry is safe" }, deletedIds, failedIds }, 500);
  }
  return json({ deletedIds });
}
