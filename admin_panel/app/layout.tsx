import type { Metadata, Viewport } from "next";
import "./globals.css";
import { NotifyToaster } from "@/components/notify-toaster";

export const metadata: Metadata = {
  title: "Medicine:SBS — Admin",
  description: "Kurslar, darslar va bannerlarni boshqarish uchun admin panel.",
  appleWebApp: {
    capable: true,
    title: "Medicine:SBS",
    statusBarStyle: "default",
  },
  formatDetection: {
    telephone: false,
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
  viewportFit: "cover",
  themeColor: "#f7f9fc",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="uz" className="h-full touch-manipulation antialiased">
      <body className="admin-shell min-h-full min-h-[100dvh] overflow-x-hidden bg-[#f7f9fc] text-slate-900">
        {children}
        <NotifyToaster />
      </body>
    </html>
  );
}
