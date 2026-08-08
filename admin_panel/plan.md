# Admin Panel (Web) Development Plan

## 1) Maqsad

Neuroscience ilovasi uchun web admin panel qurish:
- Kurs qo'shish va boshqarish
- Dars/video qo'shish va tartiblash
- Banner qo'shish va kursga bog'lash

Asosiy oqim:
`Admin Panel (Web) -> Supabase -> Flutter App`

## 1.1) Loyiha Chegarasi (Muhim)

- `admin_panel/` mustaqil web loyiha sifatida yuritiladi.
- Flutter qismi (`lib/`, `android/`, `ios/`, `windows/`, `macos/`, `linux/`) admin panel tasklarida o'zgartirilmaydi.
- Admin panelga oid barcha kod, config va assetlar faqat `admin_panel/` ichida bo'ladi.

## 2) Texnik Stack

- Framework: Next.js (App Router)
- UI: Tailwind CSS + shadcn/ui
- Backend/Data: Supabase (PostgreSQL + Storage)
- Hosting: Vercel

## 3) Papkalar Tuzilishi

```text
admin_panel/
├── app/
├── components/
├── lib/
├── services/
├── styles/
├── public/
├── package.json
├── next.config.ts
├── tsconfig.json
├── tailwind.config.ts
├── plan.md
├── rules.md
```

## 4) Modul va Sahifalar

### 4.1 Dashboard
- KPI kartalar: courses count, lessons count, banners count
- Keyingi bosqichda: user count
- Oxirgi qo'shilgan kontent ro'yxati (optional)

### 4.2 Courses
- CRUD: create / edit / delete
- Maydonlar:
  - `title_uz`
  - `title_ru`
  - `title_en`
  - `image_url`
- Rasm yuklash: Supabase Storage

### 4.3 Lessons
- Kurs tanlash (`course_id`)
- `youtube_video_id` saqlash
- `order_index` (1,2,3,...)
- `is_free` (free/lock)
- Course ichida drag/drop yoki order input orqali tartiblash

### 4.4 Banners
- `title`
- `image_url`
- `course_id` (banner bosilganda kursga o'tish)
- Banner active/inactive holati (recommended)

## 5) Supabase Data Model (MVP)

### `courses`
- id (uuid, pk)
- title_uz (text)
- title_ru (text)
- title_en (text)
- image_url (text)
- created_at (timestamp)

### `lessons`
- id (uuid, pk)
- course_id (uuid, fk -> courses.id)
- youtube_video_id (text)
- order_index (int)
- is_free (boolean, default false)
- created_at (timestamp)

### `banners`
- id (uuid, pk)
- title (text)
- image_url (text)
- course_id (uuid, fk -> courses.id)
- is_active (boolean, default true)
- created_at (timestamp)

## 6) UI/UX Yo'nalish

- Minimalistik admin dashboard
- Ko'k rangli theme (primary blue, soft neutrals)
- Responsive: desktop-first, tablet support
- Umumiy layout:
  - Sidebar (Dashboard, Courses, Lessons, Banners)
  - Header (page title, profile/menu)
  - Content area (table + form drawer/modal)

## 7) Bosqichma-bosqich Ish Rejasi

### Phase 1 - UI Foundation
1. Next.js app init (TypeScript, App Router)
2. Tailwind va shadcn/ui setup
3. Global theme va reusable UI komponentlar
4. `admin_panel` ichida alohida `package.json` va scriptlar (`dev`, `build`, `start`) sozlash

### Phase 2 - Layout
1. Sidebar + Header layout
2. Route skeletonlar:
   - `/dashboard`
   - `/courses`
   - `/lessons`
   - `/banners`

### Phase 3 - Courses
1. Courses table (list)
2. Create/Edit modal yoki sahifa
3. Delete action + confirm dialog
4. Image upload (Supabase Storage)

### Phase 4 - Lessons
1. Course filter/select
2. Lessons CRUD
3. Order va free/lock boshqaruvi

### Phase 5 - Banners
1. Banner list + form
2. Course link (`course_id`) tanlash
3. Active/inactive boshqaruv

### Phase 6 - Supabase Integration
1. Supabase client config (`env`)
2. DB jadvallar + relationlar
3. RLS policy (faqat admin access)
4. CRUD service layer (`services/`)

### Phase 7 - Deploy
1. Vercel deploy
2. ENV variables productionga qo'yish
3. Smoke test (CRUD + image upload + relation checks)

## 8) Security va Access

- Admin login (Supabase Auth)
- RLS yoqilgan bo'lishi shart
- Storage bucket policy faqat admin upload uchun
- Input validation (server-side) va error handling

## 9) Done Criteria (MVP)

MVP tayyor deb hisoblanadi agar:
- Courses CRUD to'liq ishlasa
- Lessons CRUD va order ishlasa
- Banners CRUD va course link ishlasa
- Dashboard asosiy statistika ko'rsatsa
- Supabase bilan barqaror ulanib, Vercelga deploy qilingan bo'lsa

## 10) Keyingi Iteratsiya

- User count va faoliyat analytics
- Search/sort/filter
- Audit log (kim nima o'zgartirdi)
- Multi-admin role tizimi
