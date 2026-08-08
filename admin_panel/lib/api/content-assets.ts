import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface BookCategory {
  id: string;
  name: string;
  slug: string;
}

export interface BookItem {
  id: string;
  title: string;
  description: string;
  cover_image_url: string;
  file_url: string;
  file_mime: string;
  page_count: number;
  author: string;
  category_id: string | null;
  category_name: string | null;
  course_id: string | null;
  lesson_id: string | null;
  is_active: boolean;
  created_at: string;
}

export interface LessonAssetItem {
  id: string;
  title: string;
  description: string;
  file_url: string;
  file_type: "pdf" | "ppt";
  preview_image_url: string;
  order_no: number;
  is_active: boolean;
  course_id: string | null;
  lesson_id: string | null;
  created_at: string;
}

function headers(): HeadersInit {
  const { adminApiKey } = getApiConfig();
  return {
    "Content-Type": "application/json",
    ...(adminApiKey ? { "x-admin-api-key": adminApiKey } : {}),
  };
}

async function parseError(response: Response, fallback: string) {
  try {
    const payload = (await response.json()) as { detail?: unknown };
    const detail = payload.detail;
    if (typeof detail === "string" && detail.trim()) return detail.trim();
    if (Array.isArray(detail) && detail.length > 0) {
      const first = detail[0] as { msg?: string };
      if (typeof first?.msg === "string" && first.msg.trim()) return first.msg.trim();
    }
    return fallback;
  } catch {
    return fallback;
  }
}

export async function fetchBooks(courseId?: string): Promise<BookItem[]> {
  const query = courseId ? `?course_id=${encodeURIComponent(courseId)}` : "";
  const response = await apiFetch(`/api/v1/content/books${query}`, {
    method: "GET",
    cache: "no-store",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kitoblarni olishda xatolik."));
  const payload = (await response.json()) as { items: BookItem[] };
  return payload.items ?? [];
}

export async function fetchBookCategories(): Promise<BookCategory[]> {
  const response = await apiFetch("/api/v1/content/books/categories", {
    method: "GET",
    cache: "no-store",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kategoriyalarni olishda xatolik."));
  const payload = (await response.json()) as { items: BookCategory[] };
  return payload.items ?? [];
}

export async function createBookCategory(payload: { name: string; slug: string }) {
  const response = await apiFetch("/api/v1/content/books/categories", {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kategoriya qo'shib bo'lmadi."));
  return (await response.json()) as BookCategory;
}

export async function createBook(payload: Partial<BookItem> & { title: string; file_url: string }) {
  const response = await apiFetch("/api/v1/content/books", {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kitob qo'shishda xatolik."));
  return (await response.json()) as BookItem;
}

export async function updateBook(id: string, payload: Partial<BookItem>) {
  const response = await apiFetch(`/api/v1/content/books/${id}`, {
    method: "PATCH",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kitobni tahrirlashda xatolik."));
  return (await response.json()) as BookItem;
}

export async function deleteBook(id: string) {
  const response = await apiFetch(`/api/v1/content/books/${id}`, {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kitobni o'chirishda xatolik."));
}

export async function fetchLessonAssets(params?: { lessonId?: string; courseId?: string }) {
  const query = new URLSearchParams();
  if (params?.lessonId) query.set("lesson_id", params.lessonId);
  if (params?.courseId) query.set("course_id", params.courseId);
  const response = await apiFetch(`/api/v1/content/assets${query.toString() ? `?${query.toString()}` : ""}`, {
    method: "GET",
    cache: "no-store",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Fayllarni olishda xatolik."));
  const payload = (await response.json()) as { items: LessonAssetItem[] };
  return payload.items ?? [];
}

export async function createLessonAsset(payload: Partial<LessonAssetItem> & { title: string; file_url: string; file_type: "pdf" | "ppt" }) {
  const response = await apiFetch("/api/v1/content/assets", {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Slayd qo'shishda xatolik."));
  return (await response.json()) as LessonAssetItem;
}

export async function updateLessonAsset(id: string, payload: Partial<LessonAssetItem>) {
  const response = await apiFetch(`/api/v1/content/assets/${id}`, {
    method: "PATCH",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Slaydni tahrirlashda xatolik."));
  return (await response.json()) as LessonAssetItem;
}

export async function deleteLessonAsset(id: string) {
  const response = await apiFetch(`/api/v1/content/assets/${id}`, {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Slaydni o'chirishda xatolik."));
}

