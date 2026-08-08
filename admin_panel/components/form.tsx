import type { FormEvent, ReactNode } from "react";
import { Button } from "@/components/ui/button";

interface AppFormProps {
  title: string;
  description?: string;
  children: ReactNode;
  submitLabel?: string;
  onSubmit?: (event: FormEvent<HTMLFormElement>) => void;
}

export function AppForm({
  title,
  description,
  children,
  submitLabel = "Saqlash",
  onSubmit,
}: AppFormProps) {
  return (
    <form onSubmit={onSubmit} className="surface-card space-y-5 p-4 sm:p-6">
      <div>
        <h3 className="text-lg font-semibold text-slate-900">{title}</h3>
        {description ? <p className="text-sm text-slate-500">{description}</p> : null}
      </div>
      <div className="grid gap-4">{children}</div>
      <Button type="submit" className="h-11 w-full rounded-xl bg-primary px-5 hover:bg-primary/90 sm:w-auto">
        {submitLabel}
      </Button>
    </form>
  );
}
