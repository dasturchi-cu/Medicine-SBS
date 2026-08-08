"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { BookOpen, House, Menu, MessageSquareText, Users } from "lucide-react";
import { cn } from "@/lib/utils";

const items = [
  { href: "/dashboard", label: "Panel", icon: House, match: (p: string) => p === "/dashboard" },
  {
    href: "/courses",
    label: "Kurslar",
    icon: BookOpen,
    match: (p: string) => p === "/courses" || p.startsWith("/courses/"),
  },
  {
    href: "/users",
    label: "Foydalanuvchi",
    icon: Users,
    match: (p: string) => p === "/users" || p.startsWith("/users/"),
  },
  {
    href: "/comments",
    label: "Izohlar",
    icon: MessageSquareText,
    match: (p: string) => p === "/comments" || p.startsWith("/comments/"),
  },
];

interface MobileBottomNavProps {
  onOpenMenu: () => void;
}

export function MobileBottomNav({ onOpenMenu }: MobileBottomNavProps) {
  const pathname = usePathname() ?? "";

  return (
    <nav
      aria-label="Asosiy navigatsiya"
      className="fixed bottom-0 left-0 right-0 z-[45] border-t border-slate-200/90 bg-white/95 shadow-[0_-4px_24px_rgba(15,23,42,0.06)] backdrop-blur-md lg:hidden safe-pad-bottom"
    >
      <div className="safe-pad-x mx-auto flex max-w-[1440px] items-stretch justify-between gap-0.5 px-1 pb-1 pt-0.5">
        {items.map((item) => {
          const active = item.match(pathname);
          return (
            <Link
              key={item.href}
              href={item.href}
              prefetch={true}
              className={cn(
                "flex min-h-[52px] min-w-0 flex-1 flex-col items-center justify-center gap-0.5 rounded-xl px-1 py-1 transition-colors active:bg-slate-100",
                active ? "text-primary" : "text-slate-500",
              )}
            >
              <item.icon className={cn("size-[22px] shrink-0", active && "text-primary")} aria-hidden />
              <span className="max-w-full truncate text-[10px] font-semibold leading-tight">{item.label}</span>
            </Link>
          );
        })}
        <button
          type="button"
          onClick={onOpenMenu}
          className="flex min-h-[52px] min-w-0 flex-1 flex-col items-center justify-center gap-0.5 rounded-xl px-1 py-1 text-slate-500 transition-colors active:bg-slate-100"
        >
          <Menu className="size-[22px] shrink-0" aria-hidden />
          <span className="max-w-full truncate text-[10px] font-semibold leading-tight">Menyu</span>
        </button>
      </div>
    </nav>
  );
}
