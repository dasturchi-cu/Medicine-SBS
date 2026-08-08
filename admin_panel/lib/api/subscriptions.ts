import { apiFetch, getApiConfig } from "@/lib/api/config";

export interface CourseBuyerItem {
  user_id: string;
  user_name: string;
  user_email: string;
  purchased_at: string;
}

export interface CourseSubscriptionItem {
  course_id: string;
  course_title: string;
  buyers: CourseBuyerItem[];
}

export interface SubscriptionsOverview {
  total_course_sales: number;
  total_unique_buyers: number;
  items: CourseSubscriptionItem[];
}

export interface PurchaseAdminItem {
  entitlement_id: string;
  user_id: string;
  user_name: string;
  user_email: string;
  course_id: string;
  course_title: string;
  purchased_at: string;
  is_active: boolean;
}

function headers() {
  const { adminApiKey } = getApiConfig();
  return {
    "Content-Type": "application/json",
    ...(adminApiKey ? { "x-admin-api-key": adminApiKey } : {}),
  };
}

export async function fetchSubscriptionsOverview() {
  const response = await apiFetch("/api/v1/subscriptions/overview", {
    cache: "no-store",
    headers: headers(),
  });
  if (!response.ok) {
    throw new Error("Obunalar ma'lumotini olishda xatolik.");
  }
  return (await response.json()) as SubscriptionsOverview;
}

export async function fetchPurchasesAdmin(search = "") {
  const suffix = search.trim() ? `?search=${encodeURIComponent(search.trim())}` : "";
  const response = await apiFetch(`/api/v1/subscriptions/purchases${suffix}`, {
    cache: "no-store",
    headers: headers(),
  });
  if (!response.ok) {
    throw new Error("Xaridlar ma'lumotini olishda xatolik.");
  }
  return (await response.json()) as { total: number; items: PurchaseAdminItem[] };
}

export async function revokePurchase(entitlementId: string) {
  const response = await apiFetch(`/api/v1/subscriptions/purchases/${entitlementId}`, {
    method: "DELETE",
    headers: headers(),
  });
  if (!response.ok) {
    throw new Error("Xaridni bekor qilishda xatolik.");
  }
  return (await response.json()) as { revoked: boolean; notification_sent: boolean; detail: string };
}
