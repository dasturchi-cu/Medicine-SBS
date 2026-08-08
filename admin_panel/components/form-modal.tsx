import type { ReactNode } from "react";
import { AppModal } from "@/components/modal";

interface FormModalProps {
  open: boolean;
  title: string;
  description?: string;
  onOpenChange: (open: boolean) => void;
  children: ReactNode;
}

export function FormModal({ open, title, description, onOpenChange, children }: FormModalProps) {
  return (
    <AppModal open={open} onOpenChange={onOpenChange} title={title} description={description}>
      {children}
    </AppModal>
  );
}
