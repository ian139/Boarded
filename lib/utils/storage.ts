const WALLS_PUBLIC_URL_MARKER = '/storage/v1/object/public/walls/';


/**
 * Extract the storage object path from a public Supabase Storage URL for the
 * `walls` bucket. Returns `null` for non-matching URLs. Strips query strings
 * and fragments and percent-decodes the path so it can be compared with storage
 * listing names.
 */
export function getWallStoragePathFromUrl(publicUrl: string | null | undefined): string | null {
  if (!publicUrl) return null;
  const markerIndex = publicUrl.indexOf(WALLS_PUBLIC_URL_MARKER);
  if (markerIndex === -1) return null;
  let path = publicUrl.slice(markerIndex + WALLS_PUBLIC_URL_MARKER.length).split(/[?#]/, 1)[0];
  if (!path) return null;
  try {
    path = decodeURIComponent(path);
  } catch {
    // Leave the path as-is if decoding fails.
  }
  return path;
}

/**
 * Restrict a freshly computed deletion candidate list to the paths shown in
 * the moderator preview. Set membership keeps both lists deterministic and
 * prevents newly discovered or stale paths from being removed unseen.
 */
export function intersectStoragePaths(
  freshCandidates: readonly string[],
  previewedPaths: readonly string[],
): string[] {
  const previewed = new Set(previewedPaths);
  return freshCandidates.filter((path) => previewed.has(path));
}
