import "server-only";

import { readFileResponse } from "@/lib/server/files";
import { endpoint } from "@/lib/server/http";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const GET = endpoint(async (request, context) => {
  const { id } = await context.params;
  return readFileResponse(request, id);
});
