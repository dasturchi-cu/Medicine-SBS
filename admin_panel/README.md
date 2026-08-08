# Admin Panel

Course platform uchun admin panel (`Next.js App Router + TypeScript + Tailwind + shadcn/ui`).

## Lokal ishga tushirish

```bash
npm install
npm run dev
```

Brauzer: `http://localhost:3000`

## Production tekshiruv

```bash
npm run lint
npm run build
```

## Vercel deploy

1. Reponi GitHubga push qiling.
2. [Vercel](https://vercel.com/) ga kirib **New Project** bosing.
3. GitHub repositoryni tanlang.
4. Root Directory sifatida `admin_panel` ni tanlang.
5. Build sozlamalari:
   - Framework Preset: `Next.js`
   - Build Command: `npm run build`
   - Output: `.next` (default)
6. Deploy bosing.

## Muhim

- Admin panel client-side auth ishlatadi (`localStorage`).
- Login: telefon formati `+998 XX XXX XX XX`, parol bilan kiriladi.
