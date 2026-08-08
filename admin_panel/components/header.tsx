"use client";

import { usePathname, useRouter } from "next/navigation";
import { Menu } from "lucide-react";
import { Button } from "@/components/ui/button";
import { setAdminAuthenticated } from "@/lib/admin-auth";

const titleByPath: Record<string, string> = {
  "/dashboard": "Boshqaruv paneli",
  "/courses": "Kurslar",
  "/lessons": "Darslar",
  "/users": "Foydalanuvchilar",
  "/comments": "Izohlar",
  "/ratings": "Baholar",
  "/purchases": "Xaridlar",
  "/subscriptions": "Obunalar",
  "/home-banners": "Bosh sahifa slaydi",
  "/ads": "Reklamalar",
  "/books": "Kitoblar",
  "/slide-assets": "Slaydlar",
  "/notifications": "Bildirishnomalar",
  "/tests": "Testlar",
};

interface HeaderProps {
  onOpenMobileMenu?: () => void;
}

export function Header({ onOpenMobileMenu }: HeaderProps) {
  const router = useRouter();
  const pathname = usePathname();
  const title = pathname.startsWith("/users/")
    ? "Foydalanuvchi profili"
    : pathname.startsWith("/courses/")
      ? "Kurs analitikasi"
      : titleByPath[pathname] ?? "Boshqaruv paneli";

  return (
    <header className="surface-card sticky top-0 z-30 mb-3 flex flex-wrap items-start justify-between gap-3 border border-white/80 p-3 backdrop-blur-md safe-pad-top sm:top-2 sm:mb-6 sm:rounded-2xl sm:px-5 sm:py-4 lg:top-3">
      <div className="min-w-0 flex-1">
        <div className="mb-1.5 flex items-center gap-2 lg:hidden">
          <button
            type="button"
            aria-label="Menyun ochish"
            className="inline-flex size-11 shrink-0 items-center justify-center rounded-xl border border-slate-200 bg-white active:bg-slate-50"
            onClick={onOpenMobileMenu}
          >
            <Menu className="size-5 text-slate-600" />
          </button>
          <span className="text-[11px] font-semibold uppercase tracking-wide text-slate-500">Menyu</span>
        </div>
        <h1 className="text-pretty text-lg font-semibold leading-snug text-slate-900 sm:text-2xl">{title}</h1>
        <p className="mt-0.5 text-xs text-slate-500 sm:text-sm">Barcha kontentni bitta joydan boshqaring.</p>
      </div>
      <div className="flex w-full flex-wrap items-center justify-end gap-2 sm:w-auto">
        <span className="hidden rounded-xl bg-[#eff4ff] px-3 py-2 text-xs font-semibold uppercase tracking-wide text-primary sm:inline-flex">
          Administrator
        </span>
        <Button
          variant="outline"
          className="h-11 min-w-[5.5rem] rounded-xl border-slate-200 px-4 text-xs font-semibold sm:h-9"
          onClick={() => {
            setAdminAuthenticated(false);
            router.replace("/login");
          }}
        >
          Chiqish
        </Button>
      </div>
    </header>
  );
}
