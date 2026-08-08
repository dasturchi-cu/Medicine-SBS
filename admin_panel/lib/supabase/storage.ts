import { apiFetch, getApiConfig } from "@/lib/api/config";

/** Brauzer/terminaldan kelgan tashqi bo‘shliqlar Next/Image va fetch ni sindirmasin. */
function normalizePublicUrl(url: string) {
  return String(url ?? "").replace(/[\s\n\r]+/g, "").trim();
}

/**
 * Faylni backend orqali Cloudflare R2'ga yuklaydi (Supabase Storage o'rniga).
 * `bucket` endi ishlatilmaydi (R2'da bitta bucket) — eski chaqiruvlar bilan
 * moslik uchun qoldirilgan. Funksiya nomi ham moslik uchun saqlangan.
 */
export async function uploadFileToSupabase(params: {
  bucket?: string;
  folder: string;
  file: File;
}) {
  const { folder, file } = params;
  const { adminApiKey } = getApiConfig();
  console.log("[storage.upload.start]", { folder, name: file.name, size: file.size, type: file.type });

  const form = new FormData();
  form.append("file", file);
  form.append("folder", folder);

  const response = await apiFetch("/api/v1/content/upload", {
    method: "POST",
    headers: adminApiKey ? { "x-admin-api-key": adminApiKey } : undefined,
    body: form,
  });

  if (!response.ok) {
    let detail = `Faylni yuklab bo'lmadi (${response.status}).`;
    try {
      const body = await response.json();
      if (body?.detail) detail = String(body.detail);
    } catch {
      // ignore
    }
    throw new Error(detail);
  }

  const data = await response.json();
  return {
    path: String(data.path ?? ""),
    publicUrl: normalizePublicUrl(String(data.publicUrl ?? "")),
    storageBacked: Boolean(data.storageBacked ?? true),
  };
}
