"use client";

import { useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { ConfirmModal } from "@/components/confirm-modal";
import { FormModal } from "@/components/form-modal";
import { PageSkeleton } from "@/components/page-skeleton";
import { StatusModal } from "@/components/status-modal";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import {
  blockUser,
  fetchUserEntitlements,
  fetchUserOverview,
  fetchUsers,
  grantCourse,
  removeUser,
  revokeCourse,
  type AdminUserItem,
  type UserEntitlementItem,
  type UserOverviewResponse,
  unblockUser,
  updateUser,
} from "@/lib/api/users";
import { fetchCourses } from "@/lib/api/courses";
import { notifyError, notifySuccess } from "@/lib/notify";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { useStatusModal } from "@/lib/use-status-modal";

export default function UserDetailPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const userId = params.id;
  const [loading, setLoading] = useState(true);
  const [users, setUsers] = useState<AdminUserItem[]>([]);
  const [courses, setCourses] = useState<Array<{ id: string; title_uz: string }>>([]);
  const [entitlements, setEntitlements] = useState<UserEntitlementItem[]>([]);
  const [overview, setOverview] = useState<UserOverviewResponse | null>(null);
  const [selectedCourse, setSelectedCourse] = useState("");
  const [editOpen, setEditOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [editValues, setEditValues] = useState({ name: "", email: "" });
  const statusModal = useStatusModal();
  const runStatus = statusModal.run;

  useEffect(() => {
    let mounted = true;
    const load = async (silent = false) => {
      try {
        const [userItems, courseItems, entitlementItems] = await Promise.all([
          fetchUsers(),
          fetchCourses(),
          fetchUserEntitlements(userId),
        ]);
        if (!mounted) return;
        setUsers(userItems);
        setCourses(courseItems.map((item) => ({ id: item.id, title_uz: item.title_uz })));
        setEntitlements(entitlementItems);
        setSelectedCourse(courseItems[0]?.id ?? "");

        // Keep page usable even if backend has not deployed /overview yet.
        try {
          const overviewData = await fetchUserOverview(userId);
          if (!mounted) return;
          setOverview(overviewData);
        } catch {
          if (!mounted) return;
          setOverview(null);
        }
      } catch (error) {
        if (!mounted || silent) return;
        notifyError(error instanceof Error ? error.message : "Foydalanuvchi ma'lumotlarini olishda xatolik.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();
    const supabase = getSupabaseBrowserClient();
    const channel = supabase
      ?.channel(`admin-user-${userId}-live`)
      .on("postgres_changes", { event: "*", schema: "public", table: "users", filter: `id=eq.${userId}` }, () => {
        void load(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "user_entitlements", filter: `user_id=eq.${userId}` }, () => {
        void load(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "video_progress", filter: `user_id=eq.${userId}` }, () => {
        void load(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "app_comments", filter: `user_id=eq.${userId}` }, () => {
        void load(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "ratings", filter: `user_id=eq.${userId}` }, () => {
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
  }, [userId]);

  const user = useMemo(() => users.find((item) => item.id === userId), [users, userId]);
  const activeEntitlements = useMemo(() => entitlements.filter((item) => item.is_active), [entitlements]);
  const selectedCourseData = useMemo(
    () => courses.find((course) => course.id === selectedCourse),
    [courses, selectedCourse],
  );
  const courseTitleById = useMemo(
    () => new Map(courses.map((course) => [course.id, course.title_uz])),
    [courses],
  );
  const metrics = overview?.metrics;

  if (loading) return <PageSkeleton />;

  if (!user) {
    return <div className="surface-card p-6 text-sm text-slate-500">Foydalanuvchi topilmadi.</div>;
  }

  return (
    <section className="admin-page">
      <div className="surface-card p-5">
        <h2 className="text-xl font-semibold text-slate-900">{user.name}</h2>
        <p className="mt-1 text-sm text-slate-500">{user.email || "-"}</p>
        <p className="mt-2 text-xs text-slate-500">Ro&apos;yxatdan o&apos;tgan: {user.registration_date || "-"}</p>
        <p className="mt-1 text-xs text-slate-500">Foydalanuvchi ID: {user.id}</p>
        <div className="mt-4 flex flex-wrap gap-2">
          {user.is_blocked ? (
            <Button
              variant="outline"
              onClick={async () => {
                try {
                  await runStatus({
                    loadingMessage: "Foydalanuvchi blokdan chiqarilmoqda...",
                    successMessage: "Foydalanuvchi muvaffaqiyatli blokdan chiqarildi",
                    errorMessage: "Unblockda xatolik.",
                    action: async () => unblockUser(user.id),
                  });
                  setUsers((prev) => prev.map((item) => (item.id === user.id ? { ...item, is_blocked: false } : item)));
                  notifySuccess("Foydalanuvchi blokdan chiqarildi.");
                } catch (error) {
                  notifyError(error instanceof Error ? error.message : "Unblockda xatolik.");
                }
              }}
            >
              Blokdan chiqarish
            </Button>
          ) : (
            <Button
              variant="destructive"
              onClick={async () => {
                try {
                  await runStatus({
                    loadingMessage: "Foydalanuvchi bloklanmoqda...",
                    successMessage: "Foydalanuvchi muvaffaqiyatli bloklandi",
                    errorMessage: "Bloklashda xatolik.",
                    action: async () => blockUser(user.id),
                  });
                  setUsers((prev) => prev.map((item) => (item.id === user.id ? { ...item, is_blocked: true } : item)));
                  notifySuccess("Foydalanuvchi bloklandi.");
                } catch (error) {
                  notifyError(error instanceof Error ? error.message : "Bloklashda xatolik.");
                }
              }}
            >
              Bloklash
            </Button>
          )}
          <Button
            variant="outline"
            onClick={() => {
              setEditValues({ name: user.name, email: user.email });
              setEditOpen(true);
            }}
          >
            Tahrirlash
          </Button>
          <Button variant="destructive" onClick={() => setDeleteOpen(true)}>
            O&apos;chirish
          </Button>
        </div>
        <div className="mt-4 grid gap-3 sm:grid-cols-3">
          <StatItem label="Roli" value="Talaba" />
          <StatItem label="Holati" value={user.is_blocked ? "Bloklangan" : "Faol"} />
          <StatItem label="Sotib olingan kurslar" value={String(activeEntitlements.length)} />
        </div>
      </div>

      <div className="surface-card p-5">
        <h3 className="text-base font-semibold text-slate-900">Foydalanuvchi analytics</h3>
        <div className="mt-3 grid gap-3 md:grid-cols-3">
          <StatItem label="Faol kurslar" value={String(metrics?.active_courses ?? 0)} />
          <StatItem label="Jami entitlement" value={String(metrics?.total_entitlements ?? 0)} />
          <StatItem label="Reytinglar" value={String(metrics?.ratings_count ?? 0)} />
          <StatItem label="Izohlar" value={String(metrics?.comments_count ?? 0)} />
          <StatItem label="Like bosganlar" value={String(metrics?.likes_given_count ?? 0)} />
          <StatItem label="Replylar" value={String(metrics?.replies_count ?? 0)} />
          <StatItem label="Ko'rilgan darslar" value={String(metrics?.watched_lessons_count ?? 0)} />
          <StatItem label="Yakunlangan darslar" value={String(metrics?.completed_lessons_count ?? 0)} />
          <StatItem label="Ko'rilgan sekund" value={String(metrics?.watched_seconds_total ?? 0)} />
          <StatItem label="Xaridlar soni" value={String(metrics?.purchases_count ?? 0)} />
          <StatItem label="To'langan summa" value={`${Math.round(metrics?.paid_total_uzs ?? 0).toLocaleString("ru-RU")} so'm`} />
        </div>
      </div>

      <div className="surface-card p-5">
        <h3 className="text-base font-semibold text-slate-900">Kurs berish</h3>
        <p className="mt-2 text-sm text-slate-600">
          Bu yerda berilgan kurs <strong>user_entitlements</strong> jadvaliga yoziladi — foydalanuvchi ilovada kirganda «Mening kurslarim» va kurs ochiq deb ko‘rinadi (internet bor-yo‘qligiga qarab bir necha soniya ichida yangilanadi).
        </p>
        <div className="mt-3 flex flex-col gap-2 sm:flex-row">
          <Select value={selectedCourse} onValueChange={(value) => setSelectedCourse(value ?? "")}>
            <SelectTrigger className="h-10 rounded-xl border-slate-200 sm:max-w-sm">
              <SelectValue placeholder="Kursni tanlang">
                {selectedCourseData?.title_uz ?? "Kursni tanlang"}
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              {courses.map((course) => (
                <SelectItem key={course.id} value={course.id}>
                  {course.title_uz}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button
            className="h-10 rounded-xl"
            onClick={async () => {
              if (!selectedCourse) {
                notifyError("Avval kurs tanlang.");
                return;
              }
              try {
                await runStatus({
                  loadingMessage: "Kurs berilmoqda...",
                  successMessage: "Kurs muvaffaqiyatli berildi",
                  errorMessage: "Kurs berishda xatolik.",
                  action: async () => grantCourse(user.id, selectedCourse),
                });
                const nextEntitlements = await fetchUserEntitlements(user.id);
                setEntitlements(nextEntitlements);
                try {
                  const overviewData = await fetchUserOverview(user.id);
                  setOverview(overviewData);
                } catch {
                  setOverview(null);
                }
                notifySuccess("Kurs muvaffaqiyatli berildi");
              } catch (error) {
                notifyError(error instanceof Error ? error.message : "Kurs berishda xatolik.");
              }
            }}
          >
            Kurs berish
          </Button>
        </div>
      </div>

      <div className="surface-card p-5">
        <h3 className="text-base font-semibold text-slate-900">Faol kurslar</h3>
        <div className="mt-3 space-y-2">
          {activeEntitlements.length > 0 ? (
            activeEntitlements.map((item) => (
              <div key={item.id} className="flex flex-col gap-2 rounded-xl bg-slate-50 p-3 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <p className="text-sm font-medium text-slate-900">
                    {courseTitleById.get(item.course_id) || item.course_title || item.course_id}
                  </p>
                  <p className="text-xs text-slate-500">{item.purchased_at ? item.purchased_at.slice(0, 16).replace("T", " ") : "Qo'lda berilgan"}</p>
                </div>
                <Button
                  variant="destructive"
                  className="h-8 rounded-lg px-3 text-xs"
                  onClick={async () => {
                    try {
                      await revokeCourse(user.id, item.course_id);
                      const nextEntitlements = await fetchUserEntitlements(user.id);
                      setEntitlements(nextEntitlements);
                      try {
                        const overviewData = await fetchUserOverview(user.id);
                        setOverview(overviewData);
                      } catch {
                        setOverview(null);
                      }
                      notifySuccess("Kurs foydalanuvchidan olindi.");
                    } catch (error) {
                      notifyError(error instanceof Error ? error.message : "Kursni olib tashlashda xatolik.");
                    }
                  }}
                >
                  Olib tashlash
                </Button>
              </div>
            ))
          ) : (
            <p className="text-sm text-slate-500">Faol kurslar yo&apos;q.</p>
          )}
        </div>
      </div>

      <div className="surface-card p-5">
        <h3 className="text-base font-semibold text-slate-900">So&apos;nggi baholar</h3>
        <div className="mt-3 space-y-2">
          {(overview?.recent_ratings ?? []).length > 0 ? (
            overview!.recent_ratings.map((item, idx) => (
              <div key={`${item.course_id}-${idx}`} className="rounded-xl bg-slate-50 p-3 text-sm">
                <p className="font-medium text-slate-900">{item.course_title || item.course_id}</p>
                <p className="text-slate-600">⭐ {item.stars} · {(item.created_at || "").replace("T", " ").slice(0, 16)}</p>
              </div>
            ))
          ) : (
            <p className="text-sm text-slate-500">Baholar yo&apos;q.</p>
          )}
        </div>
      </div>

      <div className="surface-card p-5">
        <h3 className="text-base font-semibold text-slate-900">So&apos;nggi izohlar</h3>
        <div className="mt-3 space-y-2">
          {(overview?.recent_comments ?? []).length > 0 ? (
            overview!.recent_comments.map((item) => (
              <div key={item.id} className="rounded-xl bg-slate-50 p-3 text-sm">
                <p className="font-medium text-slate-900">{item.course_title || item.course_key}</p>
                <p className="text-slate-700">{item.text}</p>
                <p className="text-slate-500">Like: {item.likes_count} · Reply: {item.replies_count}</p>
              </div>
            ))
          ) : (
            <p className="text-sm text-slate-500">Izohlar yo&apos;q.</p>
          )}
        </div>
      </div>

      <div className="surface-card p-5">
        <h3 className="text-base font-semibold text-slate-900">Video progress</h3>
        <div className="mt-3 space-y-2">
          {(overview?.progress_items ?? []).length > 0 ? (
            overview!.progress_items.map((item, idx) => (
              <div key={`${item.lesson_id}-${idx}`} className="rounded-xl bg-slate-50 p-3 text-sm">
                <p className="font-medium text-slate-900">{item.course_title || item.course_id}</p>
                <p className="text-slate-600">
                  Lesson: {item.lesson_title || item.lesson_id} · {item.watched_sec}s · {item.completed ? "Tugagan" : "Jarayonda"}
                </p>
                <p className="text-slate-500">{(item.updated_at || "").replace("T", " ").slice(0, 16)}</p>
              </div>
            ))
          ) : (
            <p className="text-sm text-slate-500">Progress yo&apos;q.</p>
          )}
        </div>
      </div>

      <FormModal
        open={editOpen}
        onOpenChange={(open) => setEditOpen(open)}
        title="Foydalanuvchini tahrirlash"
        description="Foydalanuvchi ma'lumotlarini yangilang."
      >
        <form
          className="space-y-3"
          onSubmit={async (event) => {
            event.preventDefault();
            try {
              const updated = await runStatus({
                loadingMessage: "Foydalanuvchi saqlanmoqda...",
                successMessage: "Foydalanuvchi muvaffaqiyatli yangilandi",
                errorMessage: "Foydalanuvchini yangilashda xatolik.",
                action: async () => updateUser(user.id, { name: editValues.name.trim(), email: editValues.email.trim() }),
              });
              setUsers((prev) => prev.map((item) => (item.id === updated.id ? updated : item)));
              setEditOpen(false);
              notifySuccess("Foydalanuvchi yangilandi.");
            } catch (error) {
              notifyError(error instanceof Error ? error.message : "Foydalanuvchini yangilashda xatolik.");
            }
          }}
        >
          <div className="grid gap-2">
            <Label htmlFor="user-name">Name</Label>
            <Input id="user-name" value={editValues.name} onChange={(event) => setEditValues((prev) => ({ ...prev, name: event.target.value }))} />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="user-email">Telefon raqam</Label>
            <Input id="user-email" value={editValues.email} onChange={(event) => setEditValues((prev) => ({ ...prev, email: event.target.value }))} />
          </div>
          <Button type="submit" className="h-10 rounded-xl">
            Saqlash
          </Button>
        </form>
      </FormModal>

      <ConfirmModal
        open={deleteOpen}
        onCancel={() => setDeleteOpen(false)}
        onConfirm={async () => {
          try {
            await runStatus({
              loadingMessage: "Foydalanuvchi o'chirilmoqda...",
              successMessage: "Muvaffaqiyatli o'chirildi",
              errorMessage: "Foydalanuvchini o'chirishda xatolik.",
              action: async () => removeUser(user.id),
            });
            notifySuccess("Foydalanuvchi o'chirildi.");
            setDeleteOpen(false);
            router.replace("/users");
          } catch (error) {
            notifyError(error instanceof Error ? error.message : "Foydalanuvchini o'chirishda xatolik.");
          }
        }}
        title="Foydalanuvchini o'chirish"
        description="Ushbu foydalanuvchini o'chirishni tasdiqlaysizmi? Bu amal ortga qaytmaydi."
        confirmText="O'chirish"
      />
      <StatusModal open={statusModal.state.open} type={statusModal.state.type} message={statusModal.state.message} />
    </section>
  );
}

function StatItem({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-slate-50 p-3">
      <p className="text-xs text-slate-500">{label}</p>
      <p className="mt-1 text-lg font-semibold text-slate-900">{value}</p>
    </div>
  );
}
