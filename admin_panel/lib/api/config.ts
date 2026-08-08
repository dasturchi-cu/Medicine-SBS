const apiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL;
const adminApiKey = process.env.NEXT_PUBLIC_ADMIN_API_KEY;
const requestTimeoutMs = Number(process.env.NEXT_PUBLIC_API_TIMEOUT_MS ?? 25000);

function resolveApiBaseUrl() {
  const fromEnv = apiBaseUrl?.trim();
  if (fromEnv) return fromEnv;
  if (typeof window !== "undefined") {
    const host = window.location.hostname || "localhost";
    return `http://${host}:8000`;
  }
  return "http://localhost:8000";
}

/** Brauzer boshqa origin dagi backend ga to'g'ridan fetch qilganda CORS / TLS sabab "Failed to fetch" chiqishi mumkin — Next.js rewrite orqali same-origin proxy ishlatiladi. */
function sameOriginBackendProxyBase(): string | null {
  if (typeof window === "undefined") return null;
  const fromEnv = apiBaseUrl?.trim();
  if (!fromEnv?.startsWith("http")) return null;
  try {
    if (new URL(fromEnv).origin === window.location.origin) return null;
  } catch {
    return null;
  }
  return `${window.location.origin}/api/backend-proxy`;
}

function resolveApiBaseCandidates() {
  const fromEnv = apiBaseUrl?.trim();
  const candidates: string[] = [];
  const localhostCandidates = ["http://localhost:8000", "http://127.0.0.1:8000"];
  const pushCandidate = (value?: string) => {
    const normalized = value?.trim();
    if (!normalized) return;
    if (!candidates.includes(normalized)) candidates.push(normalized);
  };

  if (typeof window !== "undefined") {
    const host = window.location.hostname?.trim();
    if (host) {
      if (fromEnv) {
        const proxy = sameOriginBackendProxyBase();
        if (proxy) pushCandidate(proxy);
        pushCandidate(fromEnv);
        pushCandidate(`http://${host}:8000`);
        localhostCandidates.forEach(pushCandidate);
        return candidates;
      }
      pushCandidate(`http://${host}:8000`);
      localhostCandidates.forEach(pushCandidate);
      return candidates;
    }
  }
  pushCandidate(fromEnv);
  localhostCandidates.forEach(pushCandidate);
  return candidates;
}

export function getApiConfig() {
  const resolvedBaseUrl = resolveApiBaseUrl();
  return {
    apiBaseUrl: resolvedBaseUrl,
    apiBaseCandidates: resolveApiBaseCandidates(),
    adminApiKey: adminApiKey?.trim() ?? "",
    requestTimeoutMs: Number.isFinite(requestTimeoutMs) && requestTimeoutMs > 0 ? requestTimeoutMs : 15000,
    isConfigured: Boolean(resolvedBaseUrl),
  };
}

async function fetchWithTimeout(url: string, init: RequestInit | undefined, timeoutMs: number) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort("Request timeout"), timeoutMs);
  try {
    return await fetch(url, {
      ...init,
      credentials: init?.credentials ?? "omit",
      mode: init?.mode ?? "cors",
      signal: init?.signal ?? controller.signal,
    });
  } finally {
    clearTimeout(timer);
  }
}

function shouldRetry(response: Response) {
  return response.status >= 500 || response.status === 429;
}

export async function apiFetch(path: string, init?: RequestInit) {
  const { apiBaseCandidates, requestTimeoutMs } = getApiConfig();
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  let lastError: unknown = null;
  let lastResponse: Response | null = null;

  for (const baseUrl of apiBaseCandidates) {
    const url = `${baseUrl}${normalizedPath}`;
    for (let attempt = 0; attempt < 2; attempt += 1) {
      try {
        const response = await fetchWithTimeout(url, init, requestTimeoutMs);
        if (shouldRetry(response) && attempt === 0) {
          lastResponse = response;
          await new Promise((resolve) => setTimeout(resolve, 300));
          continue;
        }
        return response;
      } catch (error) {
        lastError = error;
        if (attempt === 0) {
          await new Promise((resolve) => setTimeout(resolve, 300));
          continue;
        }
      }
    }
  }
  if (lastResponse) return lastResponse;
  const message = lastError instanceof Error ? lastError.message : "Server bilan aloqa yo'q.";
  return new Response(JSON.stringify({ detail: `Backendga ulanishda xatolik: ${message}` }), {
    status: 503,
    headers: { "Content-Type": "application/json" },
  });
}
