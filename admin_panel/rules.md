# Admin Panel Rules

## 1) Scope (Ajratilgan Loyiha)
- Admin panel faqat web loyiha, joylashuvi: `admin_panel/`.
- Flutter fayllariga tegilmaydi: `lib/`, `android/`, `ios/`, `windows/`, `macos/`, `linux/`.
- Admin panelga oid har qanday o'zgarish faqat `admin_panel/` ichida bo'ladi.

## 2) Code Rules
- TypeScript strict mode ishlatilsin.
- Feature-based structure saqlansin (`app/`, `components/`, `services/`, `lib/`).
- Reusable komponentlar alohida yozilsin, inline style ishlatilmasin.

## 3) Design Rules
- Primary rang: Blue (`#2F6BFF`), minimalistik uslub.
- Taqiqlar: gradient, neon rang, ortiqcha animatsiya, messy layout.
- Layout: chap sidebar + yuqori header + toza content area.

## 4) UX Rules
- Formlar sodda va tez to'ldiriladigan bo'lsin.
- Har bir sahifada loading, empty va error holatlari bo'lsin.
- Actionlar aniq nomlansin (Create, Save, Delete, Publish).

## 5) Data/Supabase Rules
- Querylar service layer orqali ishlasin (`services/`).
- Asosiy jadvallar: `courses`, `lessons`, `banners`.
- FK va relationlar doim tekshirilsin.

## 6) Security Rules
- Admin auth bo'lmasa CRUD ishlamasin.
- RLS policy yoqilgan bo'lishi shart.
- `.env` va maxfiy keylar repoga commit qilinmasin.

## 7) Delivery Rules
- Har modul uchun smoke test: create/read/update/delete.
- Deploydan oldin `lint` va `type-check` ishlatiladi.
- Natija: professional, minimal, tez web dashboard.

