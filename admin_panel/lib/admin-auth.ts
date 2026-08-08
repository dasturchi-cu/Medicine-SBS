export const ADMIN_AUTH_STORAGE_KEY = "admin_auth_v1";
export const ADMIN_PHONE_PREFIX = "+998";
export const ADMIN_PHONE_SUFFIX = "77 777 77 77";
export const ADMIN_PHONE_FULL = "+998777777777";
export const ADMIN_PASSWORD = "123456";

export function normalizePhone(phone: string) {
  return phone.replace(/\D/g, "");
}

export function formatPhoneSuffix(value: string) {
  const digits = normalizePhone(value).slice(0, 9);
  const parts = [
    digits.slice(0, 2),
    digits.slice(2, 5),
    digits.slice(5, 7),
    digits.slice(7, 9),
  ].filter(Boolean);
  return parts.join(" ");
}

export function getFullPhoneFromSuffix(suffix: string) {
  return `${ADMIN_PHONE_PREFIX}${normalizePhone(suffix)}`;
}

export function isAdminAuthenticated() {
  if (typeof window === "undefined") return false;
  return window.localStorage.getItem(ADMIN_AUTH_STORAGE_KEY) === "1";
}

export function setAdminAuthenticated(value: boolean) {
  if (typeof window === "undefined") return;
  if (value) {
    window.localStorage.setItem(ADMIN_AUTH_STORAGE_KEY, "1");
  } else {
    window.localStorage.removeItem(ADMIN_AUTH_STORAGE_KEY);
  }
  window.dispatchEvent(new Event("admin-auth-changed"));
}
