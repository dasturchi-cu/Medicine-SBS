"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { apiFetch } from "@/lib/api/config";

// Versiya (versionCode) — har APK yangilanishida oshiring. Bu brauzer/CDN keshini
// chetlab o'tadi, aks holda eski/buzuq nusxa yuklanib "paket invalid" chiqadi.
const APK_VERSION = "2019";
const APK_URL = `https://pub-6ef940b147524cc6aeacec5f401192fa.r2.dev/medicine-sbs.apk?v=${APK_VERSION}`;
const CONTENT_KEY = "app_medicine_sbs";

type Review = {
  id: string;
  author_name: string;
  text: string;
  created_at: string;
};

function getWebUserId(): string {
  if (typeof window === "undefined") return "web-anon";
  let id = window.localStorage.getItem("msbs_web_uid");
  if (!id) {
    id = "web-" + Math.random().toString(36).slice(2) + Date.now().toString(36);
    window.localStorage.setItem("msbs_web_uid", id);
  }
  return id;
}

function formatDateTime(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const p = (n: number) => String(n).padStart(2, "0");
  return `${p(d.getDate())}.${p(d.getMonth() + 1)}.${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

const features = [
  { icon: "🎓", title: "Tibbiyot kurslari", text: "Video darslar, slaydlar va testlar" },
  { icon: "📊", title: "Reyting", text: "Kunlik, haftalik, oylik, yillik" },
  { icon: "⏱️", title: "Pomodoro", text: "Diqqatni jamlab o'qish rejimi" },
  { icon: "📚", title: "Kitoblar", text: "PDF darsliklar va manbalar" },
];

export function DownloadClient() {
  const [avg, setAvg] = useState(0);
  const [count, setCount] = useState(0);
  const [reviews, setReviews] = useState<Review[]>([]);
  const [stars, setStars] = useState(0);
  const [hover, setHover] = useState(0);
  const [name, setName] = useState("");
  const [text, setText] = useState("");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  const userId = useMemo(getWebUserId, []);

  const load = useCallback(async () => {
    try {
      const [statsRes, listRes] = await Promise.all([
        apiFetch(`/api/v1/feedback/${CONTENT_KEY}/stats?user_id=${encodeURIComponent(userId)}`),
        apiFetch(`/api/v1/comments?course_key=${CONTENT_KEY}&user_id=${encodeURIComponent(userId)}`),
      ]);
      if (statsRes.ok) {
        const s = await statsRes.json();
        setAvg(Number(s.rating_avg) || 0);
        setCount(Number(s.rating_count) || 0);
        if (s.my_rating) setStars(Number(s.my_rating));
      }
      if (listRes.ok) {
        const l = await listRes.json();
        setReviews(Array.isArray(l.items) ? l.items : []);
      }
    } catch {
      // jim
    }
  }, [userId]);

  useEffect(() => {
    void load();
    // Real-time'ga yaqin: har 15 soniyada baho va izohlar avtomatik yangilanadi.
    const timer = setInterval(() => void load(), 15000);
    return () => clearInterval(timer);
  }, [load]);

  // Yulduz bosilganda — darhol baho yuboriladi va o'rtacha baho real-time yangilanadi.
  async function rate(n: number) {
    setStars(n);
    try {
      await apiFetch(`/api/v1/feedback/${CONTENT_KEY}/rate`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ user_id: userId, stars: n }),
      });
      await load();
      setMsg("Bahoyingiz saqlandi ⭐");
    } catch {
      setMsg("Baho yuborilmadi. Qayta urinib ko'ring.");
    }
  }

  async function submit() {
    setMsg(null);
    if (!name.trim()) return setMsg("Ismingizni yozing.");
    if (!text.trim()) return setMsg("Izoh yozing.");
    setBusy(true);
    try {
      // Baho yulduz bosilganda alohida yuboriladi; bu yerda faqat izoh (baho tanlangan bo'lsa ham yuboramiz).
      if (stars >= 1) {
        await apiFetch(`/api/v1/feedback/${CONTENT_KEY}/rate`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ user_id: userId, stars }),
        });
      }
      const res = await apiFetch(`/api/v1/comments`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ course_key: CONTENT_KEY, user_id: userId, author_name: name.trim(), text: text.trim() }),
      });
      if (!res.ok) throw new Error();
      setText("");
      setMsg("Rahmat! Fikringiz qo'shildi ✅");
      await load();
    } catch {
      setMsg("Xatolik. Qayta urinib ko'ring.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="msbs-wrap">
      <style>{`
        .msbs-wrap{min-height:100vh;background:linear-gradient(160deg,#e9f7f8,#fff 55%);
          font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;color:#0f2a2e;
          display:flex;justify-content:center;padding:20px 14px;}
        .msbs-col{width:100%;max-width:640px;}
        .msbs-card{background:#fff;border-radius:22px;box-shadow:0 16px 40px rgba(26,160,174,.14);padding:22px;}
        .msbs-hero{display:flex;gap:18px;align-items:center;}
        .msbs-logo{width:96px;height:96px;border-radius:22px;object-fit:contain;background:#fff;
          box-shadow:0 8px 20px rgba(0,0,0,.06);flex-shrink:0;}
        .msbs-title{font-size:26px;margin:0;font-weight:800;}
        .msbs-title span{color:#1AA0AE;}
        .msbs-sub{color:#5b7377;margin:4px 0 8px;font-size:14px;}
        .msbs-meta{color:#5b7377;font-size:13px;display:flex;gap:10px;flex-wrap:wrap;align-items:center;}
        .msbs-btn{display:block;width:100%;text-align:center;margin-top:16px;padding:15px;border:none;border-radius:14px;
          background:linear-gradient(135deg,#1AA0AE,#12808c);color:#fff;font-size:17px;font-weight:700;
          text-decoration:none;box-shadow:0 12px 24px rgba(26,160,174,.35);cursor:pointer;}
        .msbs-feats{display:grid;grid-template-columns:repeat(2,1fr);gap:12px;margin-top:16px;}
        .msbs-feat{background:#fff;border-radius:16px;padding:14px;box-shadow:0 6px 16px rgba(15,42,46,.05);}
        .msbs-feat h3{font-size:14px;margin:6px 0 2px;}
        .msbs-feat p{font-size:12px;color:#5b7377;margin:0;}
        .msbs-h2{font-size:17px;margin:0 0 4px;font-weight:800;}
        .msbs-bigrate{display:flex;align-items:center;gap:14px;margin:8px 0 14px;}
        .msbs-bignum{font-size:40px;font-weight:800;line-height:1;}
        .msbs-star{font-size:26px;cursor:pointer;color:#d8e0e1;background:none;border:none;padding:0 2px;}
        .msbs-star.on{color:#f5a623;}
        .msbs-input,.msbs-area{width:100%;border:1px solid #dfeaeb;border-radius:12px;padding:12px;font-size:15px;
          font-family:inherit;margin-top:8px;box-sizing:border-box;}
        .msbs-area{min-height:80px;resize:vertical;}
        .msbs-review{border-top:1px solid #eef4f5;padding:14px 0;}
        .msbs-review:first-child{border-top:none;}
        .msbs-rvhead{display:flex;justify-content:space-between;gap:10px;align-items:baseline;}
        .msbs-rvname{font-weight:700;font-size:15px;}
        .msbs-rvdate{color:#9fb3b6;font-size:12px;white-space:nowrap;}
        .msbs-rvtext{color:#3d5559;font-size:14px;margin-top:4px;line-height:1.5;}
        .msbs-foot{text-align:center;color:#9fb3b6;font-size:12px;margin:22px 0 8px;}
        @media(max-width:560px){
          .msbs-hero{flex-direction:column;text-align:center;}
          .msbs-meta{justify-content:center;}
          .msbs-feats{grid-template-columns:1fr 1fr;}
        }
      `}</style>

      <div className="msbs-col">
        {/* Hero */}
        <section className="msbs-card msbs-hero-card">
          <div className="msbs-hero">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img className="msbs-logo" src="/logo.png" alt="Medicine:SBS" />
            <div style={{ flex: 1 }}>
              <h1 className="msbs-title">Medicine<span>:SBS</span></h1>
              <p className="msbs-sub">Tibbiyot kurslari · Abdurahmonov Tohirjon</p>
              <div className="msbs-meta">
                <span style={{ color: "#f5a623" }}>★★★★★ <b style={{ color: "#0f2a2e" }}>{avg > 0 ? avg.toFixed(1) : "4.9"}</b></span>
                <span>· Android 6.0+</span>
                <span>· APK</span>
              </div>
            </div>
          </div>
          <a className="msbs-btn" href={APK_URL} download>⬇️ Ilovani o'rnatish (APK)</a>
        </section>

        {/* Features */}
        <div className="msbs-feats">
          {features.map((f) => (
            <div key={f.title} className="msbs-feat">
              <div style={{ fontSize: 26 }}>{f.icon}</div>
              <h3>{f.title}</h3>
              <p>{f.text}</p>
            </div>
          ))}
        </div>

        {/* Baholash + izoh */}
        <section className="msbs-card" style={{ marginTop: 16 }}>
          <h2 className="msbs-h2">Baholash va fikrlar</h2>
          <div className="msbs-bigrate">
            <div className="msbs-bignum">{avg > 0 ? avg.toFixed(1) : "—"}</div>
            <div>
              <div style={{ color: "#f5a623", fontSize: 20 }}>
                {"★".repeat(Math.round(avg)) || "☆☆☆☆☆"}
              </div>
              <div style={{ color: "#5b7377", fontSize: 13 }}>{count} ta baho · {reviews.length} ta izoh</div>
            </div>
          </div>

          <div>
            <div style={{ fontSize: 14, color: "#5b7377", marginBottom: 4 }}>Sizning bahoyingiz:</div>
            {[1, 2, 3, 4, 5].map((n) => (
              <button
                key={n}
                type="button"
                className={`msbs-star ${(hover || stars) >= n ? "on" : ""}`}
                onMouseEnter={() => setHover(n)}
                onMouseLeave={() => setHover(0)}
                onClick={() => rate(n)}
                aria-label={`${n} yulduz`}
              >★</button>
            ))}
          </div>

          <input className="msbs-input" placeholder="Ismingiz" value={name} maxLength={120}
            onChange={(e) => setName(e.target.value)} />
          <textarea className="msbs-area" placeholder="Fikringizni yozing..." value={text} maxLength={2000}
            onChange={(e) => setText(e.target.value)} />
          {msg ? <div style={{ fontSize: 13, color: msg.includes("Rahmat") ? "#1AA0AE" : "#e23744", marginTop: 8 }}>{msg}</div> : null}
          <button className="msbs-btn" style={{ marginTop: 12 }} onClick={submit} disabled={busy}>
            {busy ? "Yuborilmoqda..." : "Fikr yuborish"}
          </button>
        </section>

        {/* Fikrlar ro'yxati */}
        {reviews.length > 0 ? (
          <section className="msbs-card" style={{ marginTop: 16 }}>
            <h2 className="msbs-h2" style={{ marginBottom: 8 }}>Foydalanuvchilar fikri</h2>
            {reviews.map((r) => (
              <div key={r.id} className="msbs-review">
                <div className="msbs-rvhead">
                  <span className="msbs-rvname">{r.author_name}</span>
                  <span className="msbs-rvdate">{formatDateTime(r.created_at)}</span>
                </div>
                <div className="msbs-rvtext">{r.text}</div>
              </div>
            ))}
          </section>
        ) : null}

        <p className="msbs-foot">© Medicine:SBS · Barcha huquqlar himoyalangan</p>
      </div>
    </div>
  );
}
