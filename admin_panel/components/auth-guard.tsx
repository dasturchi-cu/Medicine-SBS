"use client";

import { useEffect, useSyncExternalStore } from "react";
import type { ReactNode } from "react";
import { usePathname, useRouter } from "next/navigation";
import { isAdminAuthenticated } from "@/lib/admin-auth";

interface AuthGuardProps {
  children: ReactNode;
}

export function AuthGuard({ children }: AuthGuardProps) {
  const router = useRouter();
  const pathname = usePathname();
  const allowed = useSyncExternalStore(subscribeAuthState, getAuthSnapshot, getServerAuthSnapshot);

  useEffect(() => {
    if (!allowed) {
      router.replace(`/login?next=${encodeURIComponent(pathname)}`);
    }
  }, [allowed, pathname, router]);

  if (!allowed) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="surface-card w-full max-w-sm p-6 text-center text-sm text-slate-500">
          Tekshirilmoqda...
        </div>
      </div>
    );
  }

  return <>{children}</>;
}

function subscribeAuthState(callback: () => void) {
  if (typeof window === "undefined") return () => undefined;
  const handler = () => callback();
  window.addEventListener("storage", handler);
  window.addEventListener("admin-auth-changed", handler);
  return () => {
    window.removeEventListener("storage", handler);
    window.removeEventListener("admin-auth-changed", handler);
  };
}

function getAuthSnapshot() {
  return isAdminAuthenticated();
}

function getServerAuthSnapshot() {
  return false;
}
