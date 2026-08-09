import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Medicine:SBS — Ilovani yuklab olish",
  description: "Medicine:SBS tibbiyot kurslari ilovasini Android telefoningizga yuklab oling.",
};

// APK Cloudflare R2'ga 'medicine-sbs.apk' nomi bilan yuklanadi.
const APK_URL = "https://pub-6ef940b147524cc6aeacec5f401192fa.r2.dev/medicine-sbs.apk";

const features = [
  { icon: "🎓", title: "Tibbiyot kurslari", text: "Video darslar, slaydlar va testlar" },
  { icon: "📊", title: "Reyting", text: "Kunlik, haftalik, oylik, yillik" },
  { icon: "⏱️", title: "Pomodoro", text: "Diqqatni jamlab o'qish rejimi" },
  { icon: "📚", title: "Kitoblar", text: "PDF darsliklar va manbalar" },
];

export default function DownloadPage() {
  return (
    <main
      style={{
        minHeight: "100vh",
        background: "linear-gradient(160deg, #e9f7f8 0%, #ffffff 55%)",
        display: "flex",
        justifyContent: "center",
        padding: "24px 16px",
        fontFamily: "-apple-system, Segoe UI, Roboto, Arial, sans-serif",
        color: "#0f2a2e",
      }}
    >
      <div style={{ width: "100%", maxWidth: 720 }}>
        {/* Play Store uslubidagi sarlavha */}
        <section
          style={{
            background: "#fff",
            borderRadius: 24,
            boxShadow: "0 20px 50px rgba(26,160,174,.15)",
            padding: 24,
            display: "flex",
            gap: 20,
            alignItems: "center",
            flexWrap: "wrap",
          }}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/logo.png"
            alt="Medicine:SBS"
            width={112}
            height={112}
            style={{ borderRadius: 24, background: "#fff", objectFit: "contain", boxShadow: "0 8px 20px rgba(0,0,0,.06)" }}
          />
          <div style={{ flex: 1, minWidth: 220 }}>
            <h1 style={{ fontSize: 28, margin: 0 }}>
              Medicine<span style={{ color: "#1AA0AE" }}>:SBS</span>
            </h1>
            <p style={{ color: "#5b7377", margin: "6px 0 10px" }}>
              Tibbiyot kurslari · Abdurahmonov Tohirjon
            </p>
            <div style={{ display: "flex", gap: 16, alignItems: "center", flexWrap: "wrap", fontSize: 14, color: "#5b7377" }}>
              <span style={{ color: "#f5a623", fontSize: 16 }}>★★★★★ <b style={{ color: "#0f2a2e" }}>4.9</b></span>
              <span>· Android 6.0+</span>
              <span>· ~32 MB</span>
            </div>
          </div>
          <a
            href={APK_URL}
            download
            style={{
              display: "inline-block",
              padding: "16px 28px",
              borderRadius: 16,
              background: "linear-gradient(135deg, #1AA0AE, #12808c)",
              color: "#fff",
              fontSize: 17,
              fontWeight: 700,
              textDecoration: "none",
              boxShadow: "0 12px 24px rgba(26,160,174,.35)",
            }}
          >
            ⬇️ O'rnatish (APK)
          </a>
        </section>

        {/* Xususiyatlar */}
        <section
          style={{
            marginTop: 20,
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))",
            gap: 14,
          }}
        >
          {features.map((f) => (
            <div key={f.title} style={{ background: "#fff", borderRadius: 18, padding: 18, boxShadow: "0 8px 20px rgba(15,42,46,.05)" }}>
              <div style={{ fontSize: 28 }}>{f.icon}</div>
              <h3 style={{ fontSize: 15, margin: "8px 0 4px" }}>{f.title}</h3>
              <p style={{ fontSize: 13, color: "#5b7377", margin: 0 }}>{f.text}</p>
            </div>
          ))}
        </section>

        {/* O'rnatish yo'riqnomasi */}
        <section style={{ marginTop: 20, background: "#f4fafb", borderRadius: 18, padding: "18px 22px" }}>
          <h2 style={{ fontSize: 15, color: "#12808c", margin: "0 0 8px" }}>O'rnatish yo'riqnomasi</h2>
          <ol style={{ margin: "0 0 0 18px", color: "#5b7377", fontSize: 14, lineHeight: 1.8 }}>
            <li>Yuqoridagi <b>O'rnatish</b> tugmasini bosing.</li>
            <li>Yuklangan <b>medicine-sbs.apk</b> faylini oching.</li>
            <li>&quot;Noma&apos;lum manbadan o&apos;rnatish&quot;ga ruxsat bering.</li>
            <li>&quot;O&apos;rnatish&quot; tugmasini bosing — tayyor! ✅</li>
          </ol>
        </section>

        <p style={{ textAlign: "center", color: "#9fb3b6", fontSize: 12, marginTop: 22 }}>
          © Medicine:SBS · Barcha huquqlar himoyalangan
        </p>
      </div>
    </main>
  );
}
