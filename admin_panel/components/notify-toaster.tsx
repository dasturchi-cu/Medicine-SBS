"use client";

import { AlertCircle, CheckCircle2 } from "lucide-react";
import { useEffect, useState } from "react";
import { subscribeNotify, type NotifyPayload } from "@/lib/notify";

interface ToastItem extends NotifyPayload {
  id: number;
}

export function NotifyToaster() {
  const [items, setItems] = useState<ToastItem[]>([]);

  useEffect(() => {
    const unsubscribe = subscribeNotify((payload) => {
      const id = Date.now() + Math.floor(Math.random() * 1000);
      setItems((prev) => [...prev, { id, ...payload }]);
      window.setTimeout(() => {
        setItems((prev) => prev.filter((item) => item.id !== id));
      }, 2800);
    });
    return unsubscribe;
  }, []);

  if (items.length === 0) return null;

  return (
    <div className="pointer-events-none fixed right-3 top-3 z-[90] flex w-[min(92vw,380px)] flex-col gap-2 sm:right-5 sm:top-5">
      {items.map((item) => (
        <div
          key={item.id}
          className={
            item.type === "error"
              ? "flex items-start gap-2 rounded-xl border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-800 shadow-sm"
              : "flex items-start gap-2 rounded-xl border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-800 shadow-sm"
          }
        >
          {item.type === "error" ? (
            <AlertCircle className="mt-0.5 size-4 shrink-0" />
          ) : (
            <CheckCircle2 className="mt-0.5 size-4 shrink-0" />
          )}
          <p className="leading-5">{item.message}</p>
        </div>
      ))}
    </div>
  );
}
