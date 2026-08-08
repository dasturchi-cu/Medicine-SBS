"use client";

import { useState } from "react";
import type { ReactNode } from "react";
import { AuthGuard } from "@/components/auth-guard";
import { Header } from "@/components/header";
import { MobileBottomNav } from "@/components/mobile-bottom-nav";
import { Sidebar } from "@/components/sidebar";

interface AdminLayoutProps {
  children: ReactNode;
}

export default function AdminLayout({ children }: AdminLayoutProps) {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <AuthGuard>
      <div className="safe-pad-x mx-auto flex w-full max-w-[1440px] gap-3 p-2 sm:gap-4 sm:p-4 md:gap-6 md:p-6">
        <Sidebar mobileOpen={mobileOpen} onCloseMobile={() => setMobileOpen(false)} />
        <main className="min-h-[calc(100dvh-1rem)] min-w-0 flex-1 pb-[calc(4.75rem+env(safe-area-inset-bottom))] sm:min-h-[calc(100dvh-2rem)] lg:pb-0">
          <Header onOpenMobileMenu={() => setMobileOpen(true)} />
          {children}
        </main>
      </div>
      <MobileBottomNav onOpenMenu={() => setMobileOpen(true)} />
    </AuthGuard>
  );
}
