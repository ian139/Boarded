import type { NextConfig } from "next";
import { readFileSync } from "node:fs";

const pkg = JSON.parse(readFileSync(new URL("./package.json", import.meta.url), "utf8"));

const buildVersion = process.env.VERCEL_GIT_COMMIT_SHA ||
  process.env.NEXT_PUBLIC_BUILD_ID ||
  pkg.version;
const nextConfig: NextConfig = {
  output: 'standalone',
  images: { unoptimized: true },
  transpilePackages: ['@boarded/shared'],
  env: {
    NEXT_PUBLIC_APP_VERSION: buildVersion,
  },
};

export default nextConfig;
