import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface AdItem {
  id: string;
  title: string;
  message: string;
  image_url: string;
  price_label: string;
  course_id: string | null;
  telegram: string;
  is_active: boolean;
  created_at: string;
}

function headers() {
  const { adminApiKey } = getApiConfig();
  return {
    "Content-Type": "application/json",
    ...(adminApiKey ? { "x-admin-api-key": adminApiKey } : {}),
  };
}

function formatFastApiIssue(raw: unknown): string {
  if (!raw || typeof raw !== "object") return "";
  const o = raw as { msg?: string; loc?: unknown[] };
  const msg = typeof o.msg === "string" ? o.msg.trim() : "";
  const loc = Array.isArray(o.loc) ? o.loc : [];
  const field = loc
    .filter((x): x is string | number => typeof x === "string" || typeof x === "number")
    .filter((x) => x !== "body")
    .join(".");
  if (field && msg) return `${field}: ${msg}`;
  return msg;
}

async function parseError(response: Response, fallback: string) {
  try {
    const payload = (await response.json()) as { detail?: unknown };
    const detail = payload.detail;
    if (typeof detail === "string" && detail.trim()) return detail.trim();
    if (Array.isArray(detail) && detail.length > 0) {
      const lines = detail.map(formatFastApiIssue).filter(Boolean);
      if (lines.length > 0) return lines.join("; ");
    }
    return fallback;
  } catch {
    return fallback;
  }
}

export async function fetchAds() {
  const response = await apiFetch("/api/v1/admin/ads", { cache: "no-store", headers: headers() });
  if (!response.ok) throw new Error(await parseError(response, "Reklamalarni olishda xatolik."));
  const data = (await response.json()) as { items: AdItem[] };
  return data.items ?? [];
}

export async function createAd(payload: {
  title: string;
  message: string;
  image_url: string;
  price_label: string;
  telegram: string;
  course_id?: string | null;
  is_active?: boolean;
}) {
  const body = {
    title: payload.title,
    message: payload.message,
    image_url: payload.image_url,
    price_label: payload.price_label,
    telegram: payload.telegram,
    course_id: payload.course_id ?? null,
    is_active: payload.is_active ?? false,
  };
  const response = await apiFetch("/api/v1/admin/ads", {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error(await parseError(response, "Reklama qo'shilmadi."));
  return (await response.json()) as AdItem;
}

export async function updateAd(adId: string, payload: Partial<Omit<AdItem, "id">>) {
  const response = await apiFetch(`/api/v1/admin/ads/${adId}`, {
    method: "PATCH",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Reklama yangilanmadi."));
  return (await response.json()) as AdItem;
}

export async function removeAd(adId: string) {
  const response = await apiFetch(`/api/v1/admin/ads/${adId}`, {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Reklama o'chirilmadi."));
}
