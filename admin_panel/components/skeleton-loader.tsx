interface SkeletonLoaderProps {
  rows?: number;
}

export function SkeletonLoader({ rows = 4 }: SkeletonLoaderProps) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
      {Array.from({ length: rows }).map((_, index) => (
        <div key={index} className="surface-card h-28 animate-pulse bg-slate-100" />
      ))}
    </div>
  );
}
