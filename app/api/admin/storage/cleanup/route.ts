import "server-only";

import { cleanupFiles } from "@/lib/server/files";
import { endpoint } from "@/lib/server/http";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const POST = endpoint(cleanupFiles);
