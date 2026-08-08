export type NotifyType = "success" | "error";

export interface NotifyPayload {
  type: NotifyType;
  message: string;
}

const EVENT_NAME = "admin-notify";

export function notifySuccess(message: string) {
  if (typeof window === "undefined") return;
  window.dispatchEvent(
    new CustomEvent<NotifyPayload>(EVENT_NAME, {
      detail: { type: "success", message },
    }),
  );
}

export function notifyError(message: string) {
  if (typeof window === "undefined") return;
  window.dispatchEvent(
    new CustomEvent<NotifyPayload>(EVENT_NAME, {
      detail: { type: "error", message },
    }),
  );
}

export function subscribeNotify(listener: (payload: NotifyPayload) => void) {
  if (typeof window === "undefined") return () => undefined;
  const handler = (event: Event) => {
    const custom = event as CustomEvent<NotifyPayload>;
    if (!custom.detail) return;
    listener(custom.detail);
  };
  window.addEventListener(EVENT_NAME, handler as EventListener);
  return () => window.removeEventListener(EVENT_NAME, handler as EventListener);
}
