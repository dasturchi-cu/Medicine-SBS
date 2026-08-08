import { ConfirmModal } from "@/components/confirm-modal";

interface ConfirmDialogProps {
  open: boolean;
  title: string;
  description: string;
  confirmText?: string;
  cancelText?: string;
  onConfirm: () => void;
  onCancel: () => void;
}

export function ConfirmDialog({
  open,
  title,
  description,
  confirmText = "Tasdiqlash",
  cancelText = "Bekor qilish",
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  return <ConfirmModal open={open} title={title} description={description} confirmText={confirmText} cancelText={cancelText} onConfirm={onConfirm} onCancel={onCancel} />;
}
