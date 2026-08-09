# Medicine:SBS — To'liq deploy qo'llanmasi (Neon + Backend + Cloudflare)

Bu qo'llanma Supabase'dan **butunlay chiqib**, quyidagilarga o'tish uchun:
- **Neon** → Database (Postgres)
- **Backend host** → FastAPI (Oracle o'rniga osonroq variant tavsiya etiladi)
- **Cloudflare** → R2 (fayllar + APK yuklab olish) + Pages (admin panel)

> ⚠️ **Muhim:** Cloudflare Python backend'ni (FastAPI) ishlata olmaydi. Backend
> alohida Python hostda turadi. Cloudflare faqat: fayllar (R2), APK, admin panel (Pages).

Ketma-ketlik: **1) Neon → 2) Backend → 3) Cloudflare (R2/APK) → 4) Admin → 5) Flutter build.**

---

## 1-QADAM: Neon (Database) — `DATABASE_URL` olish

1. https://neon.tech → **Sign up** (GitHub yoki Google bilan, bepul).
2. **Create project** bosing:
   - Name: `medicine-sbs`
   - Postgres version: default (eng yangi)
   - Region: **Europe (Frankfurt)** — O'zbekistonga eng yaqin, tez ishlaydi.
3. Loyiha ochilgach: **Dashboard → Connect** (yoki "Connection string").
4. **Connection pooling YOQILGAN** URL'ni tanlang (❗ muhim — ko'p user uchun):
   - "Pooled connection" belgisini yoqing.
   - URL shunday ko'rinadi:
     ```
     postgresql://neondb_owner:PAROL@ep-xxxx-pooler.eu-central-1.aws.neon.tech/neondb?sslmode=require
     ```
5. Shu URL — bu sizning **`DATABASE_URL`**. Uni saqlab qo'ying.
   - ❌ Hech kimga bermang (parol bor). GitHub'ga qo'ymang. Faqat backend env'ga.
6. **Jadvallarni yaratish:** Neon → **SQL Editor** → men beradigan `neon/neon_schema.sql`
   faylini to'liq nusxalab, **Run** bosing. (Bu barcha jadval/funksiyalarni yaratadi.)

**Neon bepul reja:** ~0.5 GB storage. Ishlatilmasa "uxlaydi", lekin so'rov kelganda
~1 soniyada uyg'onadi (Supabase kabi butunlay o'chib qolmaydi). 100+ user uchun yetadi.
Keyin kerak bo'lsa arzon planga o'tasiz.

---

## 2-QADAM: Backend host — Oracle o'rniga osonroq

| Host | Narx | Qiyinlik | 100+ user | Izoh |
|------|------|----------|-----------|------|
| **Railway** ⭐ | ~$5/oy | 🟢 Juda oson | ✅ | GitHub'dan deploy, uxlamaydi. **Tavsiya.** |
| **Render** | $7/oy (Starter) | 🟢 Oson | ✅ | `render.yaml` allaqachon bor. Bepul reja uxlaydi. |
| **Koyeb** | Bepul reja | 🟢 Oson | ✅ (cheklangan) | GitHub deploy, karta shart emas. |
| **Oracle Cloud** | Bepul (kuchli) | 🔴 Qiyin | ✅✅ | VM + SSH + Linux kerak. |

> **Tavsiya:** **Railway** (eng oson) yoki **Render** (config tayyor). Oracle faqat
> pulni tejash uchun, lekin ancha vaqt/bilim talab qiladi.

### 2A variant — Railway (TAVSIYA, eng oson)
1. https://railway.app → **Login with GitHub**.
2. **New Project → Deploy from GitHub repo** → loyihangizni tanlang.
3. Sozlamalar:
   - **Root Directory:** `fastapi`  (yoki `backend/fastapi` — ikkovi ham to'liq)
   - **Start Command:** `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
4. **Variables** (env) qo'shing:
   ```
   DATABASE_URL = (1-qadamdagi Neon URL)
   ADMIN_API_KEY = (o'zingiz o'ylab topgan maxfiy kalit)
   ADMIN_USER_ID = (admin foydalanuvchi id — Neon users jadvalidan)
   FRONTEND_ORIGIN = https://admin.seningdomening.uz  (admin panel manzili)
   ADMIN_CONTACT_TELEGRAM = medicinesbs_admin
   FIREBASE_CREDENTIALS_JSON = (push kerak bo'lsa, Firebase service account JSON)
   ```
5. **Deploy** → tayyor bo'lgach URL beriladi, masalan `https://medicine-sbs.up.railway.app`.
6. Tekshirish: brauzerda `https://.../health` → `{"ok": true, ...}` chiqishi kerak.

### 2B variant — Render (config tayyor)
1. https://render.com → GitHub bilan kiring → **New → Web Service** → repo tanlang.
2. `render.yaml` avtomatik o'qiladi. **Root:** `backend/fastapi`.
3. **Environment** bo'limida yuqoridagi env'larni qo'ying (`DATABASE_URL` va h.k.).
4. Plan: **Starter ($7/oy)** tanlang (bepul reja 15 daqiqadan keyin uxlaydi — userlar uchun yomon).
5. Deploy → URL olasiz.

### 2C variant — Oracle (bepul, lekin qiyin — qisqacha)
1. Oracle Cloud → Always Free → **VM.Standard.A1.Flex** (ARM, 4 CPU/24GB bepul).
2. Ubuntu VM oching, SSH bilan kiring.
3. `sudo apt install python3-pip`, repo'ni clone qiling, `pip install -r requirements.txt`.
4. `.env` faylida `DATABASE_URL` va boshqalarni yozing.
5. `uvicorn`ni **systemd** xizmati sifatida ishga tushiring + **nginx** reverse proxy + SSL.
6. Security List'da 80/443 portlarni oching.
> Bu variant Linux/server bilimi talab qiladi. Yangi bo'lsangiz — Railway'dan boshlang.

---

## 3-QADAM: Cloudflare — R2 (fayllar + APK yuklab olish)

1. https://dash.cloudflare.com → **Sign up** (bepul).
2. Chap menyu → **R2** → **Create bucket** → nom: `medicine-sbs-files`.
   - R2 bepul: **10 GB** saqlash, **yuklab olish (egress) BEPUL** — shuning uchun APK/rasm
     minglab marta yuklansa ham pul ketmaydi. Bu Cloudflare'ning asosiy afzalligi.
3. **Ommaviy (public) qilish:**
   - Bucket → **Settings → Public access** → "R2.dev subdomain" yoqing
     → `https://pub-xxxx.r2.dev` manzili beriladi.
   - (Ixtiyoriy) O'z domeningizni ulang: **Custom Domain** → `files.seningdomening.uz`.

### 3A: APK'ni R2'ga qo'yish (userlar yuklab olishi uchun)
1. `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.
2. R2 bucket → **Upload** → APK'ni tashlang (drag-drop). Nomini `medicine-sbs.apk` qo'ying.
3. Yuklab olish havolasi: `https://pub-xxxx.r2.dev/medicine-sbs.apk`
   (yoki `https://files.seningdomening.uz/medicine-sbs.apk`).
4. Shu havolani userlarga bering — telefondan bosib yuklab oladi.
   - Android: "Noma'lum manbadan o'rnatish"ga ruxsat berish kerak bo'ladi.

### 3B: Kontent fayllari (rasm/pdf/video) R2'ga
- Eski Supabase Storage'dagi fayllarni R2 bucket'ga ko'chiring (yuklang).
- DB'dagi `image_url` va boshqa URL maydonlarini yangi R2 manzillariga yangilang.
  (Buni men SQL bilan yordam beraman — eski URL → yangi URL almashtirish.)

### 3C: R2 API kalitlari (admin paneldan avtomatik upload uchun) ⭐
Admin panelda "Upload" tugmasi ishlashi uchun backend R2'ga yoza olishi kerak:
1. Cloudflare → **R2 → Manage R2 API Tokens → Create API token**
2. Ruxsat: **Object Read & Write**, bucket: `medicine-sbs-files`
3. Beriladi: **Access Key ID** + **Secret Access Key** + **endpoint** (`https://<accountid>.r2.cloudflarestorage.com`)
4. Bularni **backend env**'iga (Render) qo'shing:
   ```
   R2_ENDPOINT_URL = https://<accountid>.r2.cloudflarestorage.com
   R2_ACCESS_KEY_ID = <access key id>
   R2_SECRET_ACCESS_KEY = <secret>
   R2_BUCKET = medicine-sbs-files
   R2_PUBLIC_BASE_URL = https://pub-xxxx.r2.dev   (bucketning public manzili)
   ```
> R2 kalitlari faqat backend'da turadi — brauzerga/kodga chiqmaydi (xavfsiz).
> Admin panel faylni backend'ga yuboradi, backend R2'ga yuklaydi va public URL qaytaradi.

---

## 4-QADAM: Admin panel — Cloudflare Pages

1. Cloudflare dash → **Workers & Pages → Create → Pages → Connect to Git** → repo tanlang.
2. Sozlama:
   - **Root / build directory:** `admin_panel`
   - **Framework preset:** Next.js
   - **Build command:** `npm run build`
3. **Environment variables:**
   ```
   NEXT_PUBLIC_API_BASE_URL = https://medicine-sbs.onrender.com
   NEXT_PUBLIC_ADMIN_API_KEY = (backend ADMIN_API_KEY bilan bir xil bo'lsin)
   ```
   > `NEXT_PUBLIC_ADMIN_API_KEY` backend'dagi `ADMIN_API_KEY` bilan **aynan bir xil**
   > bo'lishi shart — aks holda admin panel/upload ishlamaydi.
4. Deploy → admin panel manzili: `https://medicine-sbs-admin.pages.dev`
   (yoki custom domain: `admin.seningdomening.uz`).
> Eslatma: Next.js'ning ba'zi versiyalarida Cloudflare Pages uchun
> `@cloudflare/next-on-pages` kerak bo'lishi mumkin — deploy vaqtida ko'rsatma beradi.

---

## 5-QADAM: Flutter ilovani backend'ga ulash

APK'ni backend URL bilan qayta build qiling:
```
flutter build apk --release --dart-define=API_BASE_URL=https://medicine-sbs.up.railway.app
```
- Realtime (Supabase) olib tashlangan — endi `SUPABASE_URL`/`SUPABASE_ANON_KEY` shart emas.
- Yangi APK'ni 3A qadamdagidek R2'ga qo'ying.

---

## Xulosa — ketma-ketlik
1. **Neon** ochish → `DATABASE_URL` olish → `neon_schema.sql` ni Run qilish.
2. (Men tugataman) Neon schema + realtime olib tashlash (kod).
3. **Railway** (yoki Render) → backend deploy → env'larga `DATABASE_URL`.
4. **Cloudflare R2** → fayllar + APK yuklash → public havola.
5. **Cloudflare Pages** → admin panel deploy.
6. **Flutter** → `API_BASE_URL` bilan build → APK'ni R2'ga.

## Xavfsizlik eslatmalari
- `DATABASE_URL`, `ADMIN_API_KEY`, Firebase JSON — faqat backend env'da. GitHub'ga hech qachon qo'ymang.
- `.env` fayl `.gitignore`da turishini tekshiring.
