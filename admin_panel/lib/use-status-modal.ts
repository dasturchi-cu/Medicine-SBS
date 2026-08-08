"use client";

import { useCallback, useRef, useState } from "react";
import type { StatusModalType } from "@/components/status-modal";

interface StatusState {
  open: boolean;
  type: StatusModalType;
  message: string;
}

const AUTO_CLOSE_MS = 1500;

export function useStatusModal() {
  const [state, setState] = useState<StatusState>({
    open: false,
    type: "loading",
    message: "Jarayon bajarilmoqda...",
  });
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const clearTimer = useCallback(() => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
  }, []);

  const close = useCallback(() => {
    clearTimer();
    setState((prev) => ({ ...prev, open: false }));
  }, [clearTimer]);

  const start = useCallback((message: string) => {
    clearTimer();
    setState({ open: true, type: "loading", message });
  }, [clearTimer]);

  const complete = useCallback((type: "success" | "error", message: string) => {
    clearTimer();
    setState({ open: true, type, message });
    timerRef.current = setTimeout(() => {
      setState((prev) => ({ ...prev, open: false }));
    }, AUTO_CLOSE_MS);
  }, [clearTimer]);

  const run = useCallback(
    async <T>(options: {
      loadingMessage: string;
      successMessage: string;
      errorMessage?: string;
      action: () => Promise<T>;
    }) => {
      start(options.loadingMessage);
      try {
        const result = await options.action();
        complete("success", options.successMessage);
        return result;
      } catch (error) {
        const fallback = options.errorMessage ?? "Xatolik yuz berdi";
        const message = error instanceof Error && error.message ? error.message : fallback;
        complete("error", message);
        throw error;
      }
    },
    [complete, start],
  );

  return { state, run, close };
}
