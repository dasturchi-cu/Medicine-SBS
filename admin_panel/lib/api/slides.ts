import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface SlideItem {
  id: string;
  title: string;
  subtitle: string;
  image_url: string;
  button_text: string;
  course_id: string | null;
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
    const data = (await response.json()) as { detail?: string };
    return data.detail?.trim() || fallback;
  } catch {
    return fallback;
  }
}

export async function fetchSlides() {
  const response = await apiFetch("/api/v1/slides", { cache: "no-store" });
  if (!response.ok) throw new Error(await parseError(response, "Slaydlarni olishda xatolik."));
  const data = (await response.json()) as { items: SlideItem[] };
  return data.items ?? [];
}

export async function createSlide(payload: {
  title: string;
  subtitle: string;
  image_url: string;
  button_text: string;
  order_no: number;
  course_id?: string | null;
}) {
  const response = await apiFetch("/api/v1/slides", {
    method: "POST",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Slayd qo'shishda xatolik."));
  return (await response.json()) as SlideItem;
}

export async function deleteSlide(id: string) {
  const response = await apiFetch(`/api/v1/slides/${id}`, {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Slayd o'chirishda xatolik."));
}

export async function updateSlide(
  id: string,
  payload: Partial<{
    title: string;
    subtitle: string;
    image_url: string;
    button_text: string;
    order_no: number;
    course_id: string | null;
    is_active: boolean;
  }>,
) {
  const response = await apiFetch(`/api/v1/slides/${id}`, {
    method: "PATCH",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Slayd yangilashda xatolik."));
  return (await response.json()) as SlideItem;
}
