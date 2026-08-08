"use client";

import { useEffect, useMemo, useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { StatusModal } from "@/components/status-modal";
import { fetchPurchasesAdmin, revokePurchase, type PurchaseAdminItem } from "@/lib/api/subscriptions";
import { notifyError, notifySuccess } from "@/lib/notify";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { useStatusModal } from "@/lib/use-status-modal";

export default function PurchasesPage() {
  const [loading, setLoading] = useState(true);
  const [items, setItems] = useState<PurchaseAdminItem[]>([]);
  const [search, setSearch] = useState("");
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const statusModal = useStatusModal();
  const runStatus = statusModal.run;

  useEffect(() => {
    let mounted = true;
    const load = async (silent = false) => {
      try {
        const overview = await fetchPurchasesAdmin();
        if (!mounted) return;
        setItems(overview.items ?? []);
      } catch (error) {
        if (!mounted || silent) return;
        notifyError(error instanceof Error ? error.message : "Sotuvlarni olishda xatolik.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();
    const supabase = getSupabaseBrowserClient();
    const channel = supabase
      ?.channel("admin-purchases-live")
      .on("postgres_changes", { event: "*", schema: "public", table: "user_entitlements" }, () => {
        void load(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "payments" }, () => {
        void load(true);
      })
      .subscribe();
    const onVisible = () => {
      if (document.visibilityState === "visible") void load(true);
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      mounted = false;
      document.removeEventListener("visibilitychange", onVisible);
      if (channel) {
        void supabase?.removeChannel(channel);
      }
    };
  }, []);

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase();
    return items.filter((item) => !q || `${item.course_title} ${item.user_name} ${item.user_email}`.toLowerCase().includes(q));
  }, [items, search]);

  return (
    <section className="admin-page space-y-4">
      <div className="surface-card p-4">
        <label htmlFor="purchase-search" className="mb-2 block text-sm font-medium text-slate-700">
          Xaridlarni qidirish (telefon)
        </label>
        <input
          id="purchase-search"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          className="h-11 w-full rounded-xl border border-slate-200 px-3 text-sm outline-none focus:border-primary"
          placeholder="Kurs, foydalanuvchi yoki telefon bo'yicha qidiring"
        />
      </div>

      <div className="surface-card overflow-hidden">
        <div className="grid grid-cols-1 gap-px bg-slate-100 sm:grid-cols-4">
          <div className="bg-slate-50 p-3 text-xs font-semibold uppercase tracking-wide text-slate-500">Kurs</div>
          <div className="bg-slate-50 p-3 text-xs font-semibold uppercase tracking-wide text-slate-500">Foydalanuvchi</div>
          <div className="bg-slate-50 p-3 text-xs font-semibold uppercase tracking-wide text-slate-500">Telefon raqam</div>
          <div className="bg-slate-50 p-3 text-xs font-semibold uppercase tracking-wide text-slate-500">Xarid vaqti</div>
        </div>
        {loading ? (
          <p className="p-4 text-sm text-slate-500">Yuklanmoqda...</p>
        ) : rows.length === 0 ? (
          <p className="p-4 text-sm text-slate-500">Sotuv yozuvlari topilmadi.</p>
        ) : (
          rows.map((row) => (
            <div key={row.entitlement_id} className="grid grid-cols-1 gap-px border-t border-slate-100 sm:grid-cols-4">
              <div className="p-3 text-sm text-slate-700">{row.course_title}</div>
              <div className="p-3 text-sm text-slate-700">{row.user_name}</div>
              <div className="p-3 text-sm text-slate-700">{row.user_email}</div>
              <div className="flex items-center justify-between gap-2 p-3 text-sm text-slate-500">
                <span>{row.purchased_at || "manual"}</span>
                <button
                  type="button"
                  className="rounded-lg border border-red-200 px-2 py-1 text-xs text-red-600"
                  onClick={() => setDeleteId(row.entitlement_id)}
                >
                  Bekor qilish
                </button>
              </div>
            </div>
          ))
        )}
      </div>
      <ConfirmDialog
        open={Boolean(deleteId)}
        title="Xaridni bekor qilish"
        description="Ushbu xarid ruxsatini bekor qilmoqchimisiz?"
        confirmText="Ha, bekor qilish"
        onCancel={() => setDeleteId(null)}
        onConfirm={async () => {
          if (!deleteId) return;
          try {
            await runStatus({
              loadingMessage: "Xarid bekor qilinmoqda...",
              successMessage: "Xarid muvaffaqiyatli bekor qilindi",
              errorMessage: "Xaridni bekor qilishda xatolik.",
              action: async () => revokePurchase(deleteId),
            });
            setItems((prev) => prev.filter((item) => item.entitlement_id !== deleteId));
            setDeleteId(null);
            notifySuccess("Xarid bekor qilindi va foydalanuvchiga realtime notification yuborildi.");
          } catch (error) {
            notifyError(error instanceof Error ? error.message : "Xaridni bekor qilishda xatolik.");
          }
        }}
      />
      <StatusModal open={statusModal.state.open} type={statusModal.state.type} message={statusModal.state.message} />
    </section>
  );
}
