"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Bell,
  BookOpen,
  BookText,
  FileQuestion,
  House,
  MessageSquareText,
  PanelsTopLeft,
  PlayCircle,
  Shield,
  ShoppingCart,
  Sparkles,
  Users,
  X,
  Presentation,
} from "lucide-react";
import { cn } from "@/lib/utils";

const navItems = [
  { href: "/dashboard", label: "Boshqaruv paneli", icon: House },
  { href: "/courses", label: "Kurslar", icon: BookOpen },
  { href: "/lessons", label: "Darslar", icon: PlayCircle },
  { href: "/users", label: "Foydalanuvchilar", icon: Users },
  { href: "/comments", label: "Izohlar", icon: MessageSquareText },
  { href: "/ratings", label: "Baholar", icon: Shield },
  { href: "/purchases", label: "Xaridlar", icon: ShoppingCart },
  { href: "/home-banners", label: "Bosh sahifa slaydi", icon: PanelsTopLeft },
  { href: "/ads", label: "Reklamalar", icon: Sparkles },
  { href: "/books", label: "Kitoblar", icon: BookText },
  { href: "/slide-assets", label: "Slaydlar (PDF/PPT)", icon: Presentation },
  { href: "/notifications", label: "Bildirishnomalar", icon: Bell },
  { href: "/tests", label: "Testlar", icon: FileQuestion },
];

interface SidebarProps {
  mobileOpen?: boolean;
  onCloseMobile?: () => void;
}

export function Sidebar({ mobileOpen = false, onCloseMobile }: SidebarProps) {
  const pathname = usePathname();

  return (
    <>
      <aside className="surface-card sticky top-4 hidden h-[calc(100vh-2rem)] w-64 shrink-0 p-4 lg:flex lg:flex-col">
        <SidebarContent pathname={pathname} />
      </aside>

      {mobileOpen ? (
        <div
          className="fixed inset-0 z-[55] bg-slate-900/40 backdrop-blur-[2px] lg:hidden"
          role="presentation"
          onClick={onCloseMobile}
        >
          <aside
            className="surface-card h-full w-[min(100vw-2.5rem,20rem)] max-w-sm overflow-y-auto rounded-none border-r border-slate-100 p-4 shadow-xl safe-pad-bottom"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="mb-4 flex items-center justify-between">
              <p className="text-sm font-semibold text-slate-700">Menyu</p>
              <button
                type="button"
                className="inline-flex size-9 items-center justify-center rounded-xl border border-slate-200"
                onClick={onCloseMobile}
              >
                <X className="size-4 text-slate-600" />
              </button>
            </div>
            <SidebarContent pathname={pathname} onNavigate={onCloseMobile} />
          </aside>
        </div>
      ) : null}
    </>
  );
}

interface SidebarContentProps {
  pathname: string;
  onNavigate?: () => void;
}

function SidebarContent({ pathname, onNavigate }: SidebarContentProps) {
  return (
    <>
      <div className="mb-8 border-b border-slate-100 pb-4">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">
          Ta&apos;lim Platformasi
        </p>
        <h2 className="mt-2 text-xl font-semibold text-slate-900">Boshqaruv paneli</h2>
      </div>

      <nav className="space-y-1">
        {navItems.map((item) => {
          const isActive = pathname === item.href || pathname.startsWith(`${item.href}/`);

          return (
            <Link
              key={item.href}
              href={item.href}
              onClick={onNavigate}
              className={cn(
                "flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-medium transition-all",
                isActive
                  ? "bg-primary text-primary-foreground shadow-[0_10px_20px_rgba(47,107,255,0.25)]"
                  : "text-slate-600 hover:bg-slate-50 hover:text-slate-900",
              )}
            >
              <item.icon className="size-4" />
              {item.label}
            </Link>
          );
        })}
      </nav>
    </>
  );
}
