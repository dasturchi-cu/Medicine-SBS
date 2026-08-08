import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface CourseItem {
  id: string;
  title_uz: string;
  title_ru: string;
  title_en: string;
  price_uzs: number;
  admin_telegram: string;
  image_url: string;
  description_uz: string;
  is_active: boolean;
  views: number;
  sales: number;
}

export interface CourseStatsItem {
  course_id: string;
  enrolled_count: number;
  comments_count: number;
  rating_avg: number;
  rating_count: number;
  my_rating: number | null;
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

export async function fetchCourses() {
  const response = await apiFetch("/api/v1/courses", { cache: "no-store" });
  if (!response.ok) throw new Error(await parseError(response, "Kurslarni olishda xatolik."));
  const data = (await response.json()) as { items: CourseItem[] };
  return data.items ?? [];
}

export async function createCourse(payload: {
  title_uz: string;
  title_ru: string;
  title_en: string;
  price_uzs: number;
  admin_telegram: string;
  image_url: string;
  description_uz: string;
}) {
  const response = await apiFetch("/api/v1/courses", {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kurs qo'shilmadi."));
  return (await response.json()) as CourseItem;
}

export async function updateCourse(courseId: string, payload: Partial<Omit<CourseItem, "id" | "views" | "sales">>) {
  const response = await apiFetch(`/api/v1/courses/${courseId}`, {
    method: "PATCH",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kurs yangilanmadi."));
  return (await response.json()) as CourseItem;
}

export async function removeCourse(courseId: string) {
  const response = await apiFetch(`/api/v1/courses/${courseId}`, {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kurs o'chirilmadi."));
}

export async function fetchCourseStats(courseId: string) {
  const response = await apiFetch(`/api/v1/courses/${courseId}/stats`, { cache: "no-store" });
  if (!response.ok) throw new Error(await parseError(response, "Kurs statistikasi olinmadi."));
  return (await response.json()) as CourseStatsItem;
}
