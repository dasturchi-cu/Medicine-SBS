import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface LessonSlideItem {
  id: string;
  lesson_id: string;
  title: string;
  body: string;
  image_url: string;
  order_no: number;
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

async function parseError(response: Response, fallback: string) {
  try {
    const payload = (await response.json()) as { detail?: string };
    return payload.detail?.trim() || fallback;
  } catch {
    return fallback;
  }
}

export async function fetchLessonSlides(lessonId: string) {
  if (!lessonId) return [] as LessonSlideItem[];
  const response = await apiFetch(`/api/v1/lesson-slides?lesson_id=${lessonId}&active_only=false`, {
    cache: "no-store",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Slaydlarni olishda xatolik."));
  const data = (await response.json()) as { items: LessonSlideItem[] };
  return data.items ?? [];
}

export async function createLessonSlide(payload: {
  lesson_id: string;
  title: string;
  body: string;
  image_url: string;
  order_no: number;
}) {
  const response = await apiFetch("/api/v1/lesson-slides", {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Slayd qo'shishda xatolik."));
  return (await response.json()) as LessonSlideItem;
}

export async function deleteLessonSlide(id: string) {
  const response = await apiFetch(`/api/v1/lesson-slides/${id}`, {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Slayd o'chirishda xatolik."));
}
