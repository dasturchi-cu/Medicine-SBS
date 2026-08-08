import { Button } from "@/components/ui/button";
import { AppModal } from "@/components/modal";

interface ConfirmModalProps {
  open: boolean;
  title: string;
  description: string;
  confirmText?: string;
  cancelText?: string;
  onConfirm: () => void;
  onCancel: () => void;
}

export function ConfirmModal({
  open,
  title,
  description,
  confirmText = "Tasdiqlash",
  cancelText = "Bekor qilish",
  onConfirm,
  onCancel,
}: ConfirmModalProps) {
  return (
    <AppModal open={open} onOpenChange={(nextOpen) => (!nextOpen ? onCancel() : undefined)} title={title} description={description}>
      <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
        <Button variant="outline" className="h-11 w-full rounded-xl sm:h-10 sm:w-auto" onClick={onCancel}>
          {cancelText}
        </Button>
        <Button variant="destructive" className="h-11 w-full rounded-xl sm:h-10 sm:w-auto" onClick={onConfirm}>
          {confirmText}
        </Button>
      </div>
    </AppModal>
  );
}
