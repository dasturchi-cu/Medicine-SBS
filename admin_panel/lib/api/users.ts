import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface AdminUserItem {
  id: string;
  name: string;
  email: string;
  registration_date: string;
  login_count: number;
  app_open_count: number;
  is_blocked: boolean;
}

export interface UserEntitlementItem {
  id: string;
  course_id: string;
  course_title: string;
  purchased_at: string;
  is_active: boolean;
}

export interface UserOverviewMetrics {
  active_courses: number;
  total_entitlements: number;
  ratings_count: number;
  comments_count: number;
  likes_given_count: number;
  replies_count: number;
  watched_lessons_count: number;
  completed_lessons_count: number;
  watched_seconds_total: number;
  purchases_count: number;
  paid_total_uzs: number;
}

export interface UserRecentRatingItem {
  course_id: string;
  course_title: string;
  stars: number;
  created_at: string;
}

export interface UserRecentCommentItem {
  id: string;
  course_key: string;
  course_title: string;
  lesson_title: string;
  text: string;
  likes_count: number;
  replies_count: number;
  created_at: string;
}

export interface UserProgressItem {
  lesson_id: string;
  lesson_title: string;
  course_id: string;
  course_title: string;
  watched_sec: number;
  completed: boolean;
  updated_at: string;
}

export interface UserOverviewResponse {
  user_id: string;
  metrics: UserOverviewMetrics;
  recent_ratings: UserRecentRatingItem[];
  recent_comments: UserRecentCommentItem[];
  progress_items: UserProgressItem[];
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
    const body = (await response.json()) as { detail?: string };
    return body.detail?.trim() || fallback;
  } catch {
    return fallback;
  }
}

export async function fetchUsers() {
  const response = await apiFetch("/api/v1/admin/users", {
    cache: "no-store",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Foydalanuvchilarni olishda xatolik."));
  const data = (await response.json()) as { items: AdminUserItem[] };
  return data.items ?? [];
}

export async function blockUser(userId: string) {
  const response = await apiFetch(`/api/v1/admin/users/${userId}/block`, {
    method: "POST",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Foydalanuvchini bloklashda xatolik."));
}

export async function unblockUser(userId: string) {
  const response = await apiFetch(`/api/v1/admin/users/${userId}/unblock`, {
    method: "POST",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Foydalanuvchini blokdan chiqarishda xatolik."));
}

export async function updateUser(userId: string, payload: { name?: string; email?: string; is_blocked?: boolean }) {
  const response = await apiFetch(`/api/v1/admin/users/${userId}`, {
    method: "PATCH",
    headers: headers(),
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(await parseError(response, "Foydalanuvchini yangilashda xatolik."));
  return (await response.json()) as AdminUserItem;
}

export async function removeUser(userId: string) {
  const response = await apiFetch(`/api/v1/admin/users/${userId}`, {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Foydalanuvchini o'chirishda xatolik."));
}

export async function grantCourse(userId: string, courseId: string) {
  const response = await apiFetch(`/api/v1/admin/users/${userId}/grant-course`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({ course_id: courseId }),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kurs berishda xatolik."));
}

export async function fetchUserEntitlements(userId: string) {
  const response = await apiFetch(`/api/v1/admin/users/${userId}/entitlements`, {
    cache: "no-store",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kurs ruxsatlarini olishda xatolik."));
  const data = (await response.json()) as { items: UserEntitlementItem[] };
  return data.items ?? [];
}

export async function revokeCourse(userId: string, courseId: string) {
  const response = await apiFetch(`/api/v1/admin/users/${userId}/revoke-course`, {
    method: "POST",
    headers: headers(),
    body: JSON.stringify({ course_id: courseId }),
  });
  if (!response.ok) throw new Error(await parseError(response, "Kursni olib tashlashda xatolik."));
}

export async function fetchUserOverview(userId: string) {
  const response = await apiFetch(`/api/v1/admin/users/${userId}/overview`, {
    cache: "no-store",
    headers: headers(),
  });
  if (!response.ok) throw new Error(await parseError(response, "Foydalanuvchi overview olishda xatolik."));
  return (await response.json()) as UserOverviewResponse;
}
