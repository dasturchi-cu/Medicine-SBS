"use client";

import { type ComponentType, type FormEvent, useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { BarChart3, MessageSquare, Star, Users, Video } from "lucide-react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppForm } from "@/components/form";
import { AppModal } from "@/components/modal";
import { StatusModal } from "@/components/status-modal";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { fetchAdminComments, deleteAdminComment, type AdminCommentItem } from "@/lib/api/admin-comments";
import { fetchCourseStats, fetchCourses, type CourseItem, type CourseStatsItem } from "@/lib/api/courses";
import { fetchLessons, removeLesson, updateLesson, type LessonItem } from "@/lib/api/lessons";
import { fetchPurchasesAdmin } from "@/lib/api/subscriptions";
import { notifyError, notifySuccess } from "@/lib/notify";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { useStatusModal } from "@/lib/use-status-modal";

export default function CourseDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [course, setCourse] = useState<CourseItem | null>(null);
  const [lessons, setLessons] = useState<LessonItem[]>([]);
  const [buyers, setBuyers] = useState<Array<{ user_name: string; purchased_at: string }>>([]);
  const [comments, setComments] = useState<AdminCommentItem[]>([]);
  const [stats, setStats] = useState<CourseStatsItem | null>(null);
  const [loading, setLoading] = useState(true);
  const [editLesson, setEditLesson] = useState<LessonItem | null>(null);
  const [deleteLessonId, setDeleteLessonId] = useState<string | null>(null);
  const [deleteCommentId, setDeleteCommentId] = useState<string | null>(null);
  const [editValues, setEditValues] = useState({ title: "", videoId: "", order: "1" });
  const statusModal = useStatusModal();
  const runStatus = statusModal.run;

  useEffect(() => {
    let mounted = true;
    const load = async (silent = false) => {
      try {
        const [courseItems, lessonItems, purchases, commentItems, courseStats] = await Promise.all([
          fetchCourses(),
          fetchLessons(id),
          fetchPurchasesAdmin(),
          fetchAdminComments(),
          fetchCourseStats(id),
        ]);
        if (!mounted) return;
        setCourse(courseItems.find((item) => item.id === id) ?? null);
        setLessons([...lessonItems].sort((a, b) => a.order_no - b.order_no));
        setComments(commentItems.filter((item) => item.course_id === id));
        setStats(courseStats);
        const buyersForCourse = purchases.items
          .filter((item) => item.course_id === id)
          .map((item) => ({ user_name: item.user_name, purchased_at: item.purchased_at }));
        setBuyers(buyersForCourse);
      } catch (error) {
        if (!mounted || silent) return;
        notifyError(error instanceof Error ? error.message : "Kurs sahifasini ochishda xatolik.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();

    const supabase = getSupabaseBrowserClient();
    const channel = supabase
      ?.channel(`admin-course-${id}-live`)
      .on("postgres_changes", { event: "*", schema: "public", table: "courses", filter: `id=eq.${id}` }, () => {
        void load(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "lessons", filter: `course_id=eq.${id}` }, () => {
        void load(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "app_comments", filter: `course_key=eq.${id}` }, () => {
        void load(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "comments", filter: `course_id=eq.${id}` }, () => {
        void load(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "ratings", filter: `course_id=eq.${id}` }, () => {
        void load(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "app_ratings", filter: `content_key=eq.${id}` }, () => {
        void load(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "user_entitlements", filter: `course_id=eq.${id}` }, () => {
        void load(true);
      })
      .subscribe();

    return () => {
      mounted = false;
      if (channel) {
        void supabase?.removeChannel(channel);
      }
    };
  }, [id]);

  const avgRating = stats ? stats.rating_avg.toFixed(1) : "0.0";

  const onEditLesson = (lesson: LessonItem) => {
    setEditLesson(lesson);
    setEditValues({
      title: lesson.title,
      videoId: lesson.video_url,
      order: String(lesson.order_no),
    });
  };

  const onSubmitEdit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!editLesson) return;
    const submit = async () => {
      try {
        const updated = await runStatus({
          loadingMessage: "Dars yangilanmoqda...",
          successMessage: "Dars muvaffaqiyatli yangilandi",
          errorMessage: "Darsni yangilashda xatolik.",
          action: async () => updateLesson(editLesson.id, {
            title: editValues.title,
            video_url: editValues.videoId,
            order_no: Number(editValues.order) || 1,
          }),
        });
        setLessons((prev) => prev.map((item) => (item.id === updated.id ? updated : item)).sort((a, b) => a.order_no - b.order_no));
        setEditLesson(null);
        notifySuccess("Dars yangilandi.");
      } catch (error) {
        notifyError(error instanceof Error ? error.message : "Darsni yangilashda xatolik.");
      }
    };
    void submit();
  };

  const reorder = async (lessonId: string, direction: "up" | "down") => {
    const ordered = [...lessons].sort((a, b) => a.order_no - b.order_no);
    const currentIndex = ordered.findIndex((item) => item.id === lessonId);
    if (currentIndex < 0) return;
    const targetIndex = direction === "up" ? currentIndex - 1 : currentIndex + 1;
    if (targetIndex < 0 || targetIndex >= ordered.length) return;
    const current = ordered[currentIndex];
    const target = ordered[targetIndex];
    try {
      const [a, b] = await runStatus({
        loadingMessage: "Dars tartibi yangilanmoqda...",
        successMessage: "Dars tartibi muvaffaqiyatli yangilandi",
        errorMessage: "Dars tartibini o'zgartirishda xatolik.",
        action: async () => Promise.all([
          updateLesson(current.id, { order_no: target.order_no }),
          updateLesson(target.id, { order_no: current.order_no }),
        ]),
      });
      setLessons((prev) => prev.map((item) => (item.id === a.id ? a : item.id === b.id ? b : item)).sort((x, y) => x.order_no - y.order_no));
      notifySuccess(direction === "up" ? "Dars yuqoriga ko'chdi." : "Dars pastga ko'chdi.");
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Dars tartibini o'zgartirishda xatolik.");
    }
  };

  if (loading) {
    return <div className="surface-card p-6 text-sm text-slate-500">Yuklanmoqda...</div>;
  }

  if (!course) {
    return <div className="surface-card p-8 text-center text-sm text-slate-500">Kurs topilmadi.</div>;
  }

  return (
    <section className="admin-page">
      <div className="surface-card p-4 sm:p-5">
        <h2 className="text-xl font-semibold text-slate-900 sm:text-2xl">{course.title_uz}</h2>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <InfoCard icon={Video} title="Videolar soni" value={String(lessons.length)} />
        <InfoCard icon={Users} title="Sotib olgan foydalanuvchilar" value={String(buyers.length)} />
        <InfoCard icon={BarChart3} title="Ko'rishlar soni" value={String(course.views)} />
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="surface-card p-4">
          <div className="mb-3 flex items-center gap-2">
            <Star className="size-4 text-primary" />
            <h3 className="font-semibold text-slate-800">Reyting</h3>
          </div>
          <p className="text-lg font-semibold text-slate-900">{avgRating} ⭐</p>
          <p className="text-sm text-slate-500">{stats?.rating_count ?? 0} ta baho, {stats?.comments_count ?? 0} ta izoh</p>
        </div>

        <div className="surface-card p-4">
          <div className="mb-3 flex items-center gap-2">
            <Users className="size-4 text-primary" />
            <h3 className="font-semibold text-slate-800">Xaridorlar</h3>
          </div>
          <div className="space-y-2">
            {buyers.length > 0 ? (
              buyers.map((item, index) => (
                <div key={`${item.user_name}-${index}`} className="rounded-xl bg-slate-50 px-3 py-2">
                  <p className="text-sm text-slate-800">{item.user_name}</p>
                  <p className="text-xs text-slate-500">{item.purchased_at || "Qo'lda ochilgan"}</p>
                </div>
              ))
            ) : (
              <p className="text-sm text-slate-400">Hozircha xaridor yo&apos;q.</p>
            )}
          </div>
        </div>
      </div>

      <div className="surface-card p-4">
        <div className="mb-3 flex items-center gap-2">
          <Video className="size-4 text-primary" />
          <h3 className="font-semibold text-slate-800">Video ro&apos;yxati</h3>
        </div>
        <div className="space-y-2">
          {lessons.map((lesson) => (
            <div key={lesson.id} className="flex flex-wrap items-start justify-between gap-3 rounded-xl bg-slate-50 px-3 py-2">
              <div className="min-w-0">
                <p className="font-medium text-slate-800">
                  {lesson.order_no}. {lesson.title}
                </p>
                <p className="break-all text-xs text-slate-500">{lesson.video_url}</p>
              </div>
              <div className="flex w-full flex-wrap gap-2 sm:w-auto sm:justify-end">
                <Button variant="outline" className="h-8 rounded-lg border-slate-200 px-3 text-xs" onClick={() => void reorder(lesson.id, "up")}>
                  Yuqoriga
                </Button>
                <Button variant="outline" className="h-8 rounded-lg border-slate-200 px-3 text-xs" onClick={() => void reorder(lesson.id, "down")}>
                  Pastga
                </Button>
                <Button variant="outline" className="h-8 rounded-lg border-slate-200 px-3 text-xs" onClick={() => onEditLesson(lesson)}>
                  Tahrirlash
                </Button>
                <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteLessonId(lesson.id)}>
                  O&apos;chirish
                </Button>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="surface-card p-4">
        <div className="mb-3 flex items-center gap-2">
          <MessageSquare className="size-4 text-primary" />
          <h3 className="font-semibold text-slate-800">Izohlar</h3>
        </div>
        <div className="space-y-2">
          {comments.length > 0 ? (
            comments.map((comment) => (
              <div key={comment.id} className="flex flex-col gap-2 rounded-xl bg-slate-50 px-3 py-2 sm:flex-row sm:items-center sm:justify-between">
                <div className="min-w-0">
                  <p className="text-sm font-medium text-slate-800">{comment.user_name}</p>
                  <p className="text-sm text-slate-600">{comment.text}</p>
                </div>
                <Button variant="destructive" className="h-8 w-full rounded-lg px-3 text-xs sm:w-auto" onClick={() => setDeleteCommentId(comment.id)}>
                  O&apos;chirish
                </Button>
              </div>
            ))
          ) : (
            <p className="text-sm text-slate-400">Izohlar yo&apos;q.</p>
          )}
        </div>
      </div>

      <AppModal open={Boolean(editLesson)} onOpenChange={(open) => (!open ? setEditLesson(null) : undefined)} title="Videoni tahrirlash">
        <AppForm title="Video ma&apos;lumotlari" submitLabel="Saqlash" onSubmit={onSubmitEdit}>
          <div className="grid gap-2">
            <Label htmlFor="edit-title">Sarlavha</Label>
            <Input id="edit-title" value={editValues.title} onChange={(event) => setEditValues((prev) => ({ ...prev, title: event.target.value }))} className="h-11 rounded-xl border-slate-200" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="edit-videoid">Video URL yoki ID</Label>
            <Input id="edit-videoid" value={editValues.videoId} onChange={(event) => setEditValues((prev) => ({ ...prev, videoId: event.target.value }))} className="h-11 rounded-xl border-slate-200" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="edit-order">Order</Label>
            <Input id="edit-order" type="number" min={1} value={editValues.order} onChange={(event) => setEditValues((prev) => ({ ...prev, order: event.target.value }))} className="h-11 rounded-xl border-slate-200" />
          </div>
        </AppForm>
      </AppModal>

      <ConfirmDialog
        open={Boolean(deleteLessonId)}
        title="Videoni o&apos;chirish"
        description="Ushbu videoni o&apos;chirishni tasdiqlaysizmi?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteLessonId(null)}
        onConfirm={() => {
          const submitDelete = async () => {
            if (!deleteLessonId) return;
            try {
              await runStatus({
                loadingMessage: "Video o'chirilmoqda...",
                successMessage: "Video muvaffaqiyatli o'chirildi",
                errorMessage: "Videoni o'chirishda xatolik.",
                action: async () => removeLesson(deleteLessonId),
              });
              setLessons((prev) => prev.filter((item) => item.id !== deleteLessonId));
              notifySuccess("Video o'chirildi.");
              setDeleteLessonId(null);
            } catch (error) {
              notifyError(error instanceof Error ? error.message : "Videoni o'chirishda xatolik.");
            }
          };
          void submitDelete();
        }}
      />

      <ConfirmDialog
        open={Boolean(deleteCommentId)}
        title="Izohni o&apos;chirish"
        description="Ushbu izohni o&apos;chirishni tasdiqlaysizmi?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteCommentId(null)}
        onConfirm={() => {
          const submitDelete = async () => {
            if (!deleteCommentId) return;
            try {
              await runStatus({
                loadingMessage: "Izoh o'chirilmoqda...",
                successMessage: "Izoh muvaffaqiyatli o'chirildi",
                errorMessage: "Izohni o'chirishda xatolik.",
                action: async () => deleteAdminComment(deleteCommentId),
              });
              setComments((prev) => prev.filter((item) => item.id !== deleteCommentId));
              notifySuccess("Izoh o'chirildi.");
              setDeleteCommentId(null);
            } catch (error) {
              notifyError(error instanceof Error ? error.message : "Izohni o'chirishda xatolik.");
            }
          };
          void submitDelete();
        }}
      />
      <StatusModal open={statusModal.state.open} type={statusModal.state.type} message={statusModal.state.message} />
    </section>
  );
}

interface InfoCardProps {
  icon: ComponentType<{ className?: string }>;
  title: string;
  value: string;
}

function InfoCard({ icon: Icon, title, value }: InfoCardProps) {
  return (
    <div className="surface-card p-4">
      <div className="mb-2 flex items-center gap-2">
        <Icon className="size-4 text-primary" />
        <p className="text-sm text-slate-500">{title}</p>
      </div>
      <p className="text-2xl font-semibold text-slate-900">{value}</p>
    </div>
  );
}
