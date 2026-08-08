"use client";

import { AlertCircle, CheckCircle2 } from "lucide-react";

export type StatusModalType = "loading" | "success" | "error";

interface StatusModalProps {
  open: boolean;
  type: StatusModalType;
  message: string;
}

export function StatusModal({ open, type, message }: StatusModalProps) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[120] flex items-center justify-center bg-slate-950/55 p-4 backdrop-blur-[2px]">
      <div className="w-full max-w-sm rounded-3xl border border-white/35 bg-white/90 p-7 text-center shadow-[0_20px_45px_rgba(15,23,42,0.25)] backdrop-blur-xl">
        <div className="mx-auto mb-4 flex size-16 items-center justify-center rounded-full bg-slate-100/80">
          {type === "loading" ? (
            <span className="status-spinner" />
          ) : type === "success" ? (
            <CheckCircle2 className="size-10 text-emerald-500 status-icon-enter" />
          ) : (
            <AlertCircle className="size-10 text-red-500 status-icon-enter" />
          )}
        </div>
        <p className="text-base font-semibold text-slate-900">{message}</p>
      </div>
    </div>
  );
}
