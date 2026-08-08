import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface NotificationCampaign {
  id: string;
  title: string;
  message: string;
  image: string;
  sent_at: string;
  recipients_count: number;
  viewed_count: number;
  clicked_count: number;
}

interface NotificationApiResponse {
  id: string;
  title: string;
  message: string;
  image_url: string;
  sent_at: string;
  recipients_count: number;
  viewed_count: number;
  clicked_count: number;
}

function toCampaign(item: NotificationApiResponse): NotificationCampaign {
  return {
    id: item.id,
    title: item.title,
    message: item.message,
    image: item.image_url,
    sent_at: item.sent_at.replace("T", " ").slice(0, 16),
    recipients_count: Number(item.recipients_count) || 0,
    viewed_count: Number(item.viewed_count) || 0,
    clicked_count: Number(item.clicked_count) || 0,
  };
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
    const payload = (await response.json()) as { detail?: string };
    return payload.detail?.trim() || fallback;
  } catch {
    return fallback;
  }
}

export async function fetchNotifications(): Promise<NotificationCampaign[]> {
  const response = await apiFetch("/api/v1/notifications", {
    method: "GET",
    headers: headers(),
    cache: "no-store",
  });
  if (!response.ok) throw new Error(await parseError(response, "Notificationlarni olishda xatolik yuz berdi."));
  const payload = (await response.json()) as { items: NotificationApiResponse[] };
  return (payload.items ?? []).map(toCampaign);
}

export async function createNotification(payload: { title: string; message: string; image: string }) {
  const response = await apiFetch("/api/v1/notifications", {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({
      title: payload.title.trim(),
      message: payload.message.trim(),
      image_url: payload.image.trim(),
    }),
  });
  if (!response.ok) throw new Error(await parseError(response, "Notification yuborishda xatolik yuz berdi."));
  const data = (await response.json()) as { item: NotificationApiResponse };
  return toCampaign(data.item);
}

export async function removeNotification(id: string) {
  const response = await apiFetch(`/api/v1/notifications/${id}`, {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Notificationni o'chirishda xatolik yuz berdi."));
}
