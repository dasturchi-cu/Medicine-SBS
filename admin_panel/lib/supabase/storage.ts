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
  key?: string;
  onProgress?: (percent: number) => void;
}) {
  const { folder, file, key, onProgress } = params;
  const { adminApiKey, apiBaseCandidates } = getApiConfig();
  console.log("[storage.upload.start]", { folder, name: file.name, size: file.size, type: file.type });

  const form = new FormData();
  form.append("file", file);
  form.append("folder", folder);
  if (key) form.append("key", key);

  // Progress kerak bo'lsa — XHR (fetch upload progress hodisasini bermaydi).
  if (onProgress) {
    const base = apiBaseCandidates[0] || "";
    const url = `${base}/api/v1/content/upload`;
    return await new Promise<{ path: string; publicUrl: string; storageBacked: boolean }>((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open("POST", url);
      if (adminApiKey) xhr.setRequestHeader("x-admin-api-key", adminApiKey);
      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) onProgress(Math.round((e.loaded / e.total) * 100));
      };
      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          try {
            const data = JSON.parse(xhr.responseText);
            onProgress(100);
            resolve({
              path: String(data.path ?? ""),
              publicUrl: normalizePublicUrl(String(data.publicUrl ?? "")),
              storageBacked: Boolean(data.storageBacked ?? true),
            });
          } catch {
            reject(new Error("Server javobini o'qib bo'lmadi."));
          }
        } else {
          let detail = `Faylni yuklab bo'lmadi (${xhr.status}).`;
          try {
            const b = JSON.parse(xhr.responseText);
            if (b?.detail) detail = String(b.detail);
          } catch {
            // ignore
          }
          reject(new Error(detail));
        }
      };
      xhr.onerror = () => reject(new Error("Tarmoq xatosi (fayl yuklash)."));
      xhr.send(form);
    });
  }

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
