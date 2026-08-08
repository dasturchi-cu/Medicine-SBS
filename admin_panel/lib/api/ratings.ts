import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface RatingItem {
  id: string;
  course_id: string;
  course_title: string;
  user_id: string;
  user_name: string;
  stars: number;
  created_at: string;
}

export interface RatingsAnalytics {
  total_ratings: number;
  average_stars: number;
  five_star_count: number;
  four_star_count: number;
  low_rating_count: number;
}

function headers() {
  const { adminApiKey } = getApiConfig();
  return {
    "Content-Type": "application/json",
    ...(adminApiKey ? { "x-admin-api-key": adminApiKey } : {}),
  };
}

async function parseError(response: Response, fallback: string) {
  try {
    const data = (await response.json()) as { detail?: string };
    return data.detail?.trim() || fallback;
  } catch {
    return fallback;
  }
}

export async function fetchRatings(params: { search?: string; page?: number; pageSize?: number }) {
  const query = new URLSearchParams();
  if (params.search) query.set("search", params.search);
  query.set("page", String(params.page ?? 1));
  query.set("page_size", String(params.pageSize ?? 10));
  const response = await apiFetch(`/api/v1/admin/ratings?${query.toString()}`, {
    cache: "no-store",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Reytinglarni olishda xatolik."));
  return (await response.json()) as { items: RatingItem[]; total: number };
}

export async function fetchRatingsAnalytics() {
  const response = await apiFetch("/api/v1/admin/ratings/analytics", {
    cache: "no-store",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Reyting analytics olishda xatolik."));
  return (await response.json()) as RatingsAnalytics;
}

export async function deleteRating(ratingId: string) {
  const response = await apiFetch(`/api/v1/admin/ratings/${ratingId}`, {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Reytingni o'chirishda xatolik."));
}

export async function updateRating(ratingId: string, stars: number) {
  const response = await apiFetch(`/api/v1/admin/ratings/${ratingId}`, {
    method: "PATCH",
    headers: headers(),
    body: JSON.stringify({ stars }),
  });
  if (!response.ok) throw new Error(await parseError(response, "Reytingni yangilashda xatolik."));
}

export async function resetRatings(payload: { course_id?: string; user_id?: string }) {
  const response = await apiFetch("/api/v1/admin/ratings/reset", {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Reytinglarni reset qilishda xatolik."));
  return (await response.json()) as { deleted: number };
}
