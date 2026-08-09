# 🔁 REBRAND PROMT — yangi mijoz uchun loyihani ko'chirish

> **Qanday ishlatiladi:** Bu papkani (butun loyihani) yangi joyga **copy** qiling.
> Yangi papkada AI (Claude Code / Cursor / boshqa) ochib, pastdagi **«AI'GA BERILADIGAN PROMT»** qismini to'ldirib, to'liq yuboring.
> AI hamma joyni yangi mijozga moslab o'zgartiradi.

---

## ⚠️ AVVAL SIZ TO'LDIRASIZ (o'zgaruvchilar)

Yangi mijoz uchun quyidagilarni tayyorlang va promtga qo'ying:

| # | O'zgaruvchi | Namuna (eski) | Yangi qiymat |
|---|-------------|---------------|--------------|
| 1 | Ilova nomi (ko'rinadigan) | `Medicine:SBS` | `__________` |
| 2 | Package / applicationId | `uz.medicine.sbs` | `uz.________.____` (kichik harf, unikal) |
| 3 | Muallif ismi | `Abdurahmonov Tohirjon` | `__________` |
| 4 | Asosiy rang (HEX) | `#1AA0AE` (turkuaz) | `#______` |
| 5 | Admin Telegram username | `Mr_Xusanboy` | `__________` (@ siz) |
| 6 | Admin User ID (bazadagi) | `6264440682` | `__________` |
| 7 | Logo fayl | `assets/images/logo.png` | yangi logoni **shu nom bilan** almashtiring (≥1024×1024, oq fon) |
| 8 | Admin panel logo | `admin_panel/public/logo.png` | yangi logo |
| 9 | Backend URL (Render) | `https://medicine-sbs.onrender.com` | `https://________.onrender.com` |
| 10 | Admin panel URL (Vercel) | `https://medicine-sbs.vercel.app` | `https://________.vercel.app` |
| 11 | R2 public bazasi | `https://pub-6ef940b147524cc6aeacec5f401192fa.r2.dev` | yangi R2 public URL |
| 12 | Feedback/content kaliti | `app_medicine_sbs` | `app_________` |

**Infratuzilma (siz yangi akkauntlarda ochasiz — pastdagi CHECKLIST'ga qarang):**
Neon (DB), Cloudflare R2 (fayl+APK), Render (backend), Vercel (admin panel), Firebase (push), GitHub (repo), release keystore.

---

## 🤖 AI'GA BERILADIGAN PROMT (shu qismni to'ldirib yuboring)

```
Salom. Bu — sotib olgan "kurs ilovasi" loyihasining nusxasi. Uni YANGI MIJOZ uchun
to'liq rebrand qil (nom, logo, rang, Telegram, URL va h.k.). Loyiha tuzilishi:

- Flutter mobil ilova (lib/, android/, assets/)
- FastAPI backend — IKKI NUSXADA: `fastapi/` va `backend/fastapi/`
  (⚠️ HAR BIR backend o'zgarishini IKKALASIGA ham qil — aks holda deployда farq chiqadi)
- Next.js admin panel: `admin_panel/`
- Download sahifasi: `admin_panel/app/download/` (va eski `download/index.html`)
- DB=Neon (Postgres), fayllar+APK=Cloudflare R2, backend=Render, admin=Vercel, push=Firebase

YANGI QIYMATLAR:
- Ilova nomi: "<<YANGI_NOM>>"
- applicationId: "<<uz.yangi.app>>"
- Muallif: "<<Yangi Muallif>>"
- Asosiy rang: "<<#RANG>>"
- Admin Telegram: "<<username>>"  (@ belgisiz)
- Admin User ID: "<<id>>"
- Backend URL: "<<https://yangi.onrender.com>>"
- Admin panel URL: "<<https://yangi.vercel.app>>"
- R2 public URL: "<<https://pub-....r2.dev>>"
- Content kaliti: "<<app_yangi>>"

BAJAR (har biriga aniq fayl ko'rsatilgan; agar joy o'zgargan bo'lsa grep bilan top):

1) ILOVA NOMI:
   - android/app/src/main/AndroidManifest.xml → android:label="<<YANGI_NOM>>"
   - admin_panel/app/layout.tsx (title/metadata), admin_panel/components/sidebar.tsx (brend)
   - lib/ ichida "Medicine:SBS" bo'lgan hamma matnni <<YANGI_NOM>>ga almashtir (grep "Medicine:SBS")
   - assets/lang/uz.json, en.json, ru.json ichidagi brend matnlari

2) PACKAGE / applicationId:
   - android/app/build.gradle.kts → applicationId = "<<uz.yangi.app>>"
   - (namespace "com.example.medical_app" ni O'ZGARTIRMA — sinishi mumkin; faqat applicationId kifoya)
   - android/app/google-services.json — yangi Firebase loyihasinikiga almashtiriladi (7-bandga qara)

3) LOGO / SPLASH / IKONKA:
   - assets/images/logo.png ni yangi logo bilan almashtir (≥1024×1024, oq fon)
   - admin_panel/public/logo.png ni ham almashtir
   - keyin build oldidan ishga tushir:
       dart run flutter_launcher_icons
       dart run flutter_native_splash:create
   - splash rangi kerak bo'lsa: pubspec.yaml → flutter_native_splash.color

4) MUALLIF ISMI:
   - lib/ ichida "Abdurahmonov Tohirjon" ni <<Yangi Muallif>>ga almashtir (grep bilan)

5) RANG / TEMA:
   - lib/core/theme/design_system.dart → AppColors asosiy rangini <<#RANG>> qil
   - download sahifasidagi rang (admin_panel/app/download/download-client.tsx CSS)

6) TELEGRAM ADMIN:
   - lib/core/services/telegram_service.dart → _adminUsername = '<<username>>'
   - backend env ADMIN_CONTACT_TELEGRAM = <<username>> (Render'da o'rnatiladi)

7) FIREBASE (push bildirishnoma):
   - Yangi Firebase loyihasi ochilgach:
     * android/app/google-services.json ni yangisiga almashtir
     * lib/firebase_options.dart ni yangi loyiha qiymatlari bilan yangila
     * backend env FIREBASE_CREDENTIALS_JSON = yangi service-account JSON (Render)

8) API URL:
   - lib/core/config/api_config.dart → default 'https://medicine-sbs.onrender.com' ni <<Backend URL>>ga
   - build vaqtida ham: --dart-define=API_BASE_URL=<<Backend URL>>
   - admin_panel/next.config.ts va admin_panel/lib/api/config.ts — backend URL

9) DOWNLOAD SAHIFA:
   - admin_panel/app/download/download-client.tsx:
     * APK_URL = "<<R2 public URL>>/medicine-sbs.apk" (yoki yangi fayl nomi)
     * CONTENT_KEY = "<<app_yangi>>"
     * brend matnlari, muallif, rang
   - download/index.html (agar ishlatilsa) — brend

10) KEYSTORE (APK imzosi — yangi mijoz uchun YANGI keystore):
    - keytool bilan yangi keystore yarat:
        keytool -genkey -v -keystore android/app/<<yangi>>-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias <<alias>>
    - android/key.properties ni yangi keystore ma'lumotlari bilan yoz
    - key.properties va *.jks .gitignore'da — commit qilinmasin
    - ⚠️ keystore parollarini xavfsiz saqla (yo'qolsa ilova yangilanmaydi)

11) ENV / SEKRETLAR (kod emas — hosting panelida o'rnatiladi):
    - Render (backend): DATABASE_URL(Neon), R2_ENDPOINT_URL, R2_ACCESS_KEY_ID,
      R2_SECRET_ACCESS_KEY, R2_BUCKET, R2_PUBLIC_BASE_URL, ADMIN_API_KEY,
      ADMIN_CONTACT_TELEGRAM, ADMIN_USER_ID, FIREBASE_CREDENTIALS_JSON, FRONTEND_ORIGIN
    - Vercel (admin panel): NEXT_PUBLIC_API_BASE_URL, NEXT_PUBLIC_ADMIN_API_KEY
    - Neon: neon/neon_schema.sql ni yangi bazada bir marta ishga tushir
      (va neon/ ichidagi qo'shimcha *.sql migratsiyalar bo'lsa ular ham)

12) TEKSHIR (o'zgartirgach):
    - grep bilan qoldiq brend qidir: "Medicine:SBS", "medicine-sbs", "uz.medicine.sbs",
      "Mr_Xusanboy", "Abdurahmonov", "pub-6ef940b147524cc6aeacec5f401192fa" — hech biri qolmasin
    - flutter analyze lib   → xatosiz bo'lsin
    - fastapi ikkala nusxasi bir xilligini tekshir

QO'SHIMCHA (agar shu mijozga kerak bo'lsa — men aytaman):
- QO'SHILADIGAN funksiyalar: <<masalan: test/kviz bo'limi, sertifikat, to'lov integratsiyasi>>
- OLIB TASHLANADIGAN funksiyalar: <<masalan: Pomodoro, Kitoblar, Onlayn kurslar>>
  (olib tashlashda: home_page.dart kategoriya chip'lari + tegishli sahifa/provider'ni o'chir)

Oxirida: nima o'zgartirganingni qisqa ro'yxat qilib ber va build/deploy qadamlarini yoz.
```

---

## ✅ INFRATUZILMA CHECKLIST (har yangi mijoz uchun siz ochasiz)

1. **GitHub** — yangi repo yarat, kodni push qil.
2. **Neon** — yangi loyiha/DB → `DATABASE_URL` (pooled) ol → `neon/neon_schema.sql` ni SQL editorда ishga tushir.
3. **Cloudflare R2** — yangi bucket + "Object Read & Write" token + public URL yoq → R2_* qiymatlari.
4. **Render** — backend deploy (root: `fastapi/` yoki `backend/fastapi/`), 11-banddagi env'larni qo'y.
5. **Vercel** — admin panel deploy (root: `admin_panel/`), NEXT_PUBLIC_* env'larni qo'y.
6. **Firebase** — yangi loyiha → google-services.json + firebase_options.dart + service-account JSON.
7. **Keystore** — yangi release keystore (10-band), parollarni saqla.
8. **APK** — `flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=API_BASE_URL=<<Backend URL>>`
   → arm64 APK'ni R2'ga `medicine-sbs.apk` (yoki yangi nom) bilan yukla → download sahifa versiyasini oshir.

---

## 📌 MUHIM ESLATMALAR

- **FastAPI ikki nusxada** (`fastapi/` + `backend/fastapi/`): har o'zgarishni ikkalasiga qil.
- **Sekretlar hech qachon git'ga tushmasin**: `.env`, `key.properties`, `*.jks` — `.gitignore`da.
- **APK cache**: download linkida `?v=RAQAM` bor — har yangi APK'da raqamni oshir (brauzer eski nusxani bermasin).
- **Namespace** (`com.example.medical_app`) ni o'zgartirmaslik xavfsizroq; faqat **applicationId** unikal bo'lsa kifoya.
