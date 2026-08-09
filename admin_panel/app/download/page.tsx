import type { Metadata } from "next";
import { DownloadClient } from "./download-client";

export const metadata: Metadata = {
  title: "Medicine:SBS — Ilovani yuklab olish",
  description: "Medicine:SBS tibbiyot kurslari ilovasini Android telefoningizga yuklab oling.",
};

export default function DownloadPage() {
  return <DownloadClient />;
}
