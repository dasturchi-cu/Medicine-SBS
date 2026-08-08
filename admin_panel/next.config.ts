import type { NextConfig } from "next";

const backendOrigin = (process.env.NEXT_PUBLIC_API_BASE_URL ?? "").replace(/\/+$/, "");

function supabaseImageHostname(): string | null {
  const raw = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim() ?? "";
  if (!raw) return null;
  try {
    const host = new URL(raw).hostname;
    return host || null;
  } catch {
    return null;
  }
}

const supabaseHost = supabaseImageHostname();
const imageRemotePatterns =
  supabaseHost != null
    ? [{ protocol: "https" as const, hostname: supabaseHost }]
    : [];

const nextConfig: NextConfig = {
  allowedDevOrigins: ["192.168.100.168"],
  images: {
    remotePatterns: imageRemotePatterns,
  },
  async rewrites() {
    if (!backendOrigin.startsWith("http")) return [];
    return [
      {
        source: "/api/backend-proxy/:path*",
        destination: `${backendOrigin}/:path*`,
      },
    ];
  },
};

export default nextConfig;
