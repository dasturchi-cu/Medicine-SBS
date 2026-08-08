import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface AdminCommentItem {
  id: string;
  course_id: string;
  course_title?: string;
  user_id: string;
  user_name: string;
  text: string;
  hearts: number;
  parent_id: string | null;
  created_at: string;
  hearted_by_admin: boolean;
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

export async function fetchAdminComments() {
  let response = await apiFetch("/api/v1/admin/comments", { cache: "no-store", headers: headers() });
  if (response.status === 404) {
    response = await apiFetch("/api/v1/comments/admin", { cache: "no-store", headers: headers() });
  }
  if (!response.ok) throw new Error(await parseError(response, "Izohlarni olishda xatolik."));
  const data = (await response.json()) as { items: AdminCommentItem[] };
  return data.items ?? [];
}

export async function replyAdminComment(commentId: string, text: string) {
  let response = await apiFetch(`/api/v1/admin/comments/${commentId}/reply`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({ text }),
  });
  if (response.status === 404) {
    response = await apiFetch(`/api/v1/comments/admin/${commentId}/reply`, {
      method: "POST",
      headers: headers(),
      body: JSON.stringify({ text }),
    });
  }
  if (!response.ok) throw new Error(await parseError(response, "Javob yuborishda xatolik."));
  return (await response.json()) as AdminCommentItem;
}

export async function toggleAdminCommentHeart(commentId: string) {
  let response = await apiFetch(`/api/v1/admin/comments/${commentId}/toggle-heart`, {
    method: "POST",
    headers: headers(),
  });
  if (response.status === 404) {
    response = await apiFetch(`/api/v1/comments/admin/${commentId}/toggle-heart`, {
      method: "POST",
      headers: headers(),
    });
  }
  if (!response.ok) throw new Error(await parseError(response, "Yurakcha bosishda xatolik."));
  return (await response.json()) as AdminCommentItem;
}

export async function deleteAdminComment(commentId: string) {
  let response = await apiFetch(`/api/v1/admin/comments/${commentId}`, {
    method: "DELETE",
    headers: headers(),
  });
  if (response.status === 404) {
    response = await apiFetch(`/api/v1/comments/admin/${commentId}`, {
      method: "DELETE",
      headers: headers(),
    });
  }
  if (!response.ok) throw new Error(await parseError(response, "Izohni o'chirishda xatolik."));
}
