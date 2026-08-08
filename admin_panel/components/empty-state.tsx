interface EmptyStateProps {
  title?: string;
  description?: string;
}

export function EmptyState({
  title = "Ma'lumot topilmadi",
  description = "Filtrlarni o'zgartiring yoki yangi ma'lumot qo'shing.",
}: EmptyStateProps) {
  return (
    <div className="mx-auto max-w-xs py-8 text-center">
      <p className="text-sm font-semibold text-slate-700">{title}</p>
      <p className="mt-1 text-xs text-slate-400">{description}</p>
    </div>
  );
}
