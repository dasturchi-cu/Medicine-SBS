import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface LessonItem {
  id: string;
  course_id: string;
  section_id: string | null;
  title: string;
  video_url: string;
  order_no: number;
  is_free: boolean;
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

export async function fetchLessons(courseId?: string) {
  const suffix = courseId ? `?course_id=${encodeURIComponent(courseId)}` : "";
  const response = await apiFetch(`/api/v1/lessons${suffix}`, { cache: "no-store" });
  if (!response.ok) throw new Error(await parseError(response, "Darslarni olishda xatolik."));
  const data = (await response.json()) as { items: LessonItem[] };
  return data.items ?? [];
}

export async function createLesson(payload: {
  course_id: string;
  title: string;
  video_url: string;
  order_no: number;
  is_free: boolean;
  section_id?: string | null;
}) {
  const response = await apiFetch("/api/v1/lessons", {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Dars qo'shilmadi."));
  return (await response.json()) as LessonItem;
}

export async function updateLesson(id: string, payload: Partial<Omit<LessonItem, "id">>) {
  const response = await apiFetch(`/api/v1/lessons/${id}`, {
    method: "PATCH",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Dars yangilanmadi."));
  return (await response.json()) as LessonItem;
}

export async function removeLesson(id: string) {
  const response = await apiFetch(`/api/v1/lessons/${id}`, {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Dars o'chirilmadi."));
}
