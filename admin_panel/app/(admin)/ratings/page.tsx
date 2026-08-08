"use client";

import { useEffect, useMemo, useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { StatusModal } from "@/components/status-modal";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { deleteRating, fetchRatings, fetchRatingsAnalytics, resetRatings, type RatingItem, type RatingsAnalytics, updateRating } from "@/lib/api/ratings";
import { notifyError, notifySuccess } from "@/lib/notify";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { useStatusModal } from "@/lib/use-status-modal";

export default function RatingsPage() {
  const [items, setItems] = useState<RatingItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [analytics, setAnalytics] = useState<RatingsAnalytics | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const pageSize = 10;
  const statusModal = useStatusModal();
  const runStatus = statusModal.run;

  useEffect(() => {
    let mounted = true;
    const loadRatings = async (silent = false) => {
      try {
        const [response, analyticsResponse] = await Promise.all([
          fetchRatings({ search, page, pageSize }),
          fetchRatingsAnalytics(),
        ]);
        if (!mounted) return;
        setItems(response.items);
        setTotal(response.total);
        setAnalytics(analyticsResponse);
      } catch (error) {
        if (!mounted || silent) return;
        notifyError(error instanceof Error ? error.message : "Reytinglar yuklanmadi.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void loadRatings();
    const supabase = getSupabaseBrowserClient();
    const channel = supabase
      ?.channel("admin-ratings-live")
      .on("postgres_changes", { event: "*", schema: "public", table: "ratings" }, () => {
        void loadRatings(true);
      })
      .subscribe();
    return () => {
      mounted = false;
      if (channel) void supabase?.removeChannel(channel);
    };
  }, [search, page]);

  const pageCount = Math.max(1, Math.ceil(total / pageSize));
  const columns = useMemo(
    () => [
      { key: "course_title", label: "Kurs" },
      { key: "user_name", label: "Foydalanuvchi" },
      {
        key: "stars",
        label: "Bahosi",
        render: (item: RatingItem) => (
          <div className="flex items-center gap-2">
            <select
              value={item.stars}
              onChange={async (event) => {
                const nextStars = Number(event.target.value);
                try {
                  await runStatus({
                    loadingMessage: "Baho saqlanmoqda...",
                    successMessage: "Baho muvaffaqiyatli yangilandi",
                    errorMessage: "Reytingni yangilashda xatolik.",
                    action: async () => updateRating(item.id, nextStars),
                  });
                  setItems((prev) => prev.map((entry) => (entry.id === item.id ? { ...entry, stars: nextStars } : entry)));
                  notifySuccess("Reyting yangilandi.");
                } catch (error) {
                  notifyError(error instanceof Error ? error.message : "Reytingni yangilashda xatolik.");
                }
              }}
              className="h-8 rounded-lg border border-slate-200 px-2 text-xs outline-none focus:border-primary"
            >
              {[1, 2, 3, 4, 5].map((value) => (
                <option key={value} value={value}>
                  {value}
                </option>
              ))}
            </select>
          </div>
        ),
      },
      { key: "created_at", label: "Yaratilgan vaqti", render: (item: RatingItem) => item.created_at.slice(0, 19).replace("T", " ") },
      {
        key: "actions",
        label: "Amallar",
        render: (item: RatingItem) => (
          <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteId(item.id)}>
            O&apos;chirish
          </Button>
        ),
      },
    ],
    [runStatus],
  );

  return (
    <section className="admin-page space-y-4">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <StatCard label="Jami baholar" value={String(analytics?.total_ratings ?? 0)} />
        <StatCard label="O'rtacha baho" value={(analytics?.average_stars ?? 0).toFixed(2)} />
        <StatCard label="5 yulduz" value={String(analytics?.five_star_count ?? 0)} />
        <StatCard label="4 yulduz" value={String(analytics?.four_star_count ?? 0)} />
        <StatCard label="Past baholar (<=3)" value={String(analytics?.low_rating_count ?? 0)} />
      </div>
      <div className="surface-card grid gap-3 p-4 sm:grid-cols-[1fr_auto_auto] sm:items-end">
        <div>
          <label htmlFor="search" className="mb-2 block text-sm font-medium text-slate-700">
            Baholarni qidirish
          </label>
          <Input id="search" value={search} onChange={(event) => setSearch(event.target.value)} className="h-11 rounded-xl border-slate-200" />
        </div>
        <Button
          variant="outline"
          className="h-10 rounded-xl px-4"
          onClick={async () => {
            try {
              const result = await runStatus({
                loadingMessage: "Baholar tozalanmoqda...",
                successMessage: "Baholar muvaffaqiyatli tozalandi",
                errorMessage: "Reset amalga oshmadi.",
                action: async () => resetRatings({}),
              });
              notifySuccess(`${result.deleted} ta rating reset qilindi.`);
              setPage(1);
              const response = await fetchRatings({ search, page: 1, pageSize });
              setItems(response.items);
              setTotal(response.total);
            } catch (error) {
              notifyError(error instanceof Error ? error.message : "Reset amalga oshmadi.");
            }
          }}
        >
          Barchasini tozalash
        </Button>
      </div>

      {loading ? <p className="text-sm text-slate-500">Yuklanmoqda...</p> : <AppTable columns={columns} data={items} emptyText="Reytinglar topilmadi." />}
      <div className="flex items-center justify-between text-sm text-slate-500">
        <p>
          Jami: {total} | Sahifa: {page}/{pageCount}
        </p>
        <div className="flex gap-2">
          <Button variant="outline" className="h-8 rounded-lg px-3 text-xs" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
            Oldingi
          </Button>
          <Button variant="outline" className="h-8 rounded-lg px-3 text-xs" disabled={page >= pageCount} onClick={() => setPage((p) => p + 1)}>
            Keyingi
          </Button>
        </div>
      </div>

      <ConfirmDialog
        open={Boolean(deleteId)}
        title="Reytingni o'chirish"
        description="Ushbu reyting yozuvini o'chirmoqchimisiz?"
        confirmText="Ha, o'chirish"
        onCancel={() => setDeleteId(null)}
        onConfirm={async () => {
          if (!deleteId) return;
          try {
            await runStatus({
              loadingMessage: "Baho o'chirilmoqda...",
              successMessage: "Muvaffaqiyatli o'chirildi",
              errorMessage: "Reytingni o'chirishda xatolik.",
              action: async () => deleteRating(deleteId),
            });
            notifySuccess("Reyting o'chirildi.");
            setDeleteId(null);
            const response = await fetchRatings({ search, page, pageSize });
            setItems(response.items);
            setTotal(response.total);
          } catch (error) {
            notifyError(error instanceof Error ? error.message : "Reytingni o'chirishda xatolik.");
          }
        }}
      />
      <StatusModal open={statusModal.state.open} type={statusModal.state.type} message={statusModal.state.message} />
    </section>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="surface-card p-4">
      <p className="text-sm text-slate-500">{label}</p>
      <p className="mt-2 text-2xl font-semibold text-slate-900">{value}</p>
    </div>
  );
}
