import { cn } from "@/lib/utils";

interface BlueBannerProps {
  className?: string;
}

export function BlueBanner({ className }: BlueBannerProps) {
  return (
    <div
      className={cn(
        "h-12 w-20 rounded-xl bg-linear-to-r from-[#2F6BFF] via-[#3E78FF] to-[#5D90FF]",
        className,
      )}
    />
  );
}
