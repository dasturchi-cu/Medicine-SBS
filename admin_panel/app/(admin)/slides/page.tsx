"use client";

import { type FormEvent, useEffect, useMemo, useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppForm } from "@/components/form";
import { ImagePicker } from "@/components/image-picker";
import { StatusModal } from "@/components/status-modal";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { fetchCourses } from "@/lib/api/courses";
import { fetchLessonSlides, createLessonSlide, deleteLessonSlide, type LessonSlideItem } from "@/lib/api/lesson-slides";
import { fetchLessons, type LessonItem } from "@/lib/api/lessons";
import { notifyError, notifySuccess } from "@/lib/notify";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { useStatusModal } from "@/lib/use-status-modal";

export default function SlidesPage() {
  const [courses, setCourses] = useState<Array<{ id: string; title_uz: string }>>([]);
  const [lessons, setLessons] = useState<LessonItem[]>([]);
  const [slides, setSlides] = useState<LessonSlideItem[]>([]);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [selectedCourseId, setSelectedCourseId] = useState<string>("");
  const [selectedLessonId, setSelectedLessonId] = useState<string>("");
  const [values, setValues] = useState({ title: "", body: "", image_url: "", image_urls: [] as string[], order_no: "1" });
  const statusModal = useStatusModal();
  const runStatus = statusModal.run;

  const resolvedCourseId = selectedCourseId || courses[0]?.id || "";
  const filteredLessons = lessons.filter((item) => (resolvedCourseId ? item.course_id === resolvedCourseId : true));
  const resolvedLessonId = selectedLessonId || filteredLessons[0]?.id || "";

  useEffect(() => {
    let mounted = true;
    const load = async (silent = false) => {
      try {
        const [courseItems, lessonItems] = await Promise.all([fetchCourses(), fetchLessons()]);
        if (!mounted) return;
        setCourses(courseItems.map((item) => ({ id: item.id, title_uz: item.title_uz })));
        setLessons(lessonItems);
        setSelectedCourseId(courseItems[0]?.id ?? "");
        const firstLesson = lessonItems.find((item) => item.course_id === (courseItems[0]?.id ?? ""));
        setSelectedLessonId(firstLesson?.id ?? "");
      } catch (error) {
        if (!mounted || silent) return;
        notifyError(error instanceof Error ? error.message : "Slayd bo'limini ochishda xatolik.");
      }
    };
    void load();
    const supabase = getSupabaseBrowserClient();
    const channel = supabase
      ?.channel("admin-lesson-slides-live")
      .on("postgres_changes", { event: "*", schema: "public", table: "lesson_slides" }, () => {
        void load(true);
      })
      .subscribe();
    return () => {
      mounted = false;
      if (channel) {
        void supabase?.removeChannel(channel);
      }
    };
  }, []);

  useEffect(() => {
    const loadSlides = async () => {
      if (!resolvedLessonId) {
        setSlides([]);
        return;
      }
      try {
        const items = await fetchLessonSlides(resolvedLessonId);
        setSlides(items);
      } catch (error) {
        setSlides([]);
        notifyError(error instanceof Error ? error.message : "Slaydlarni olishda xatolik.");
      }
    };
    void loadSlides();
  }, [resolvedLessonId]);

  const columns = useMemo(
    () => [
      {
        key: "preview",
        label: "Rasm",
        render: (item: LessonSlideItem) =>
          item.image_url ? <div className="h-12 w-20 rounded-xl bg-cover bg-center" style={{ backgroundImage: `url(${item.image_url})` }} /> : "—",
      },
      { key: "title", label: "Sarlavha" },
      {
        key: "lesson_id",
        label: "Dars",
        render: (item: LessonSlideItem) => lessons.find((lesson) => lesson.id === item.lesson_id)?.title ?? "Noma'lum",
      },
      { key: "body", label: "Izoh" },
      { key: "order_no", label: "Tartib" },
      {
        key: "actions",
        label: "Amallar",
        render: (item: LessonSlideItem) => (
          <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteId(item.id)}>
            O&apos;chirish
          </Button>
        ),
      },
    ],
    [lessons],
  );

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!resolvedLessonId) {
      notifyError("Avval dars tanlang.");
      return;
    }
    const submit = async () => {
      const urls = [...values.image_urls];
      if (values.image_url.trim()) urls.push(values.image_url.trim());
      if (urls.length === 0) {
        notifyError("Kamida bitta rasm qo'shing.");
        return;
      }
      try {
        const baseOrder = Number(values.order_no) || 1;
        const created: LessonSlideItem[] = [];
        for (let idx = 0; idx < urls.length; idx += 1) {
          const url = urls[idx];
          const item = await runStatus({
            loadingMessage: "Slayd saqlanmoqda...",
            successMessage: "Slayd muvaffaqiyatli saqlandi",
            errorMessage: "Slayd qo'shishda xatolik.",
            action: async () => createLessonSlide({
              lesson_id: resolvedLessonId,
              title: values.title,
              body: values.body,
              image_url: url,
              order_no: baseOrder + idx,
            }),
          });
          created.push(item);
        }
        setSlides((prev) => [...prev, ...created].sort((a, b) => a.order_no - b.order_no));
        setValues({ title: "", body: "", image_url: "", image_urls: [], order_no: "1" });
        notifySuccess(`${created.length} ta slayd qo'shildi.`);
      } catch (error) {
        notifyError(error instanceof Error ? error.message : "Slayd qo'shishda xatolik.");
      }
    };
    void submit();
  };

  return (
    <section className="admin-page">
      <AppForm title="Darsga slayd qo'shish" description="Tanlangan dars ichiga slaydlar shu yerdan qo'shiladi." onSubmit={onSubmit} submitLabel="Slayd qo'shish">
        <div className="grid gap-2 sm:grid-cols-2">
          <div className="grid gap-2">
            <Label htmlFor="courseSelect">Kurs tanlash</Label>
            <select
              id="courseSelect"
              className="h-11 rounded-xl border border-slate-200 bg-white px-3 text-sm"
              value={resolvedCourseId}
              onChange={(event) => {
                const courseId = event.target.value;
                setSelectedCourseId(courseId);
                const nextLesson = lessons.find((item) => item.course_id === courseId)?.id ?? "";
                setSelectedLessonId(nextLesson);
              }}
            >
              {courses.map((course) => (
                <option key={course.id} value={course.id}>
                  {course.title_uz}
                </option>
              ))}
            </select>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="lessonSelect">Dars tanlash</Label>
            <select id="lessonSelect" className="h-11 rounded-xl border border-slate-200 bg-white px-3 text-sm" value={resolvedLessonId} onChange={(event) => setSelectedLessonId(event.target.value)}>
              {filteredLessons.map((lesson) => (
                <option key={lesson.id} value={lesson.id}>
                  {lesson.title}
                </option>
              ))}
            </select>
          </div>
        </div>
        <div className="grid gap-2">
          <Label htmlFor="title">Sarlavha</Label>
          <Input id="title" value={values.title} onChange={(e) => setValues((p) => ({ ...p, title: e.target.value }))} />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="body">Izoh</Label>
          <Input id="body" value={values.body} onChange={(e) => setValues((p) => ({ ...p, body: e.target.value }))} />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="order">Tartib raqami</Label>
          <Input id="order" value={values.order_no} onChange={(e) => setValues((p) => ({ ...p, order_no: e.target.value }))} />
        </div>
        <ImagePicker
          label="Slayd rasmi"
          value={values.image_url}
          helperText="Bitta rasm tanlang, keyin ro'yxatga qo'shing. 4-6+ rasm bo'lishi mumkin."
          onChange={(value) => setValues((p) => ({ ...p, image_url: value }))}
        />
        <div className="flex flex-wrap items-center gap-2">
          <Button
            type="button"
            variant="outline"
            className="h-9 rounded-lg border-slate-200 px-3 text-xs"
            onClick={() => {
              const url = values.image_url.trim();
              if (!url) {
                notifyError("Avval rasm tanlang.");
                return;
              }
              setValues((prev) => ({
                ...prev,
                image_url: "",
                image_urls: prev.image_urls.includes(url) ? prev.image_urls : [...prev.image_urls, url],
              }));
            }}
          >
            Rasmni ro&apos;yxatga qo&apos;shish
          </Button>
          <span className="text-xs text-slate-500">{values.image_urls.length} ta rasm tanlangan</span>
        </div>
        {values.image_urls.length > 0 ? (
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            {values.image_urls.map((url, index) => (
              <div key={`${url}-${index}`} className="group relative overflow-hidden rounded-lg border border-slate-200">
                <div className="h-16 w-full bg-cover bg-center" style={{ backgroundImage: `url(${url})` }} />
                <button
                  type="button"
                  className="absolute right-1 top-1 rounded bg-white/90 px-1.5 py-0.5 text-[10px] text-red-600"
                  onClick={() =>
                    setValues((prev) => ({
                      ...prev,
                      image_urls: prev.image_urls.filter((item) => item !== url),
                    }))
                  }
                >
                  O&apos;chirish
                </button>
              </div>
            ))}
          </div>
        ) : null}
      </AppForm>

      <AppTable columns={columns} data={slides} emptyText="Hali slayd qo'shilmagan." />

      <ConfirmDialog
        open={Boolean(deleteId)}
        title="Slaydni o'chirish"
        description="Ushbu slaydni o'chirmoqchimisiz?"
        confirmText="Ha, o'chirish"
        onCancel={() => setDeleteId(null)}
        onConfirm={() => {
          const submitDelete = async () => {
            if (!deleteId) return;
            try {
              await runStatus({
                loadingMessage: "Slayd o'chirilmoqda...",
                successMessage: "Slayd muvaffaqiyatli o'chirildi",
                errorMessage: "Slayd o'chirishda xatolik.",
                action: async () => deleteLessonSlide(deleteId),
              });
              setSlides((prev) => prev.filter((item) => item.id !== deleteId));
              notifySuccess("Slayd o'chirildi.");
              setDeleteId(null);
            } catch (error) {
              notifyError(error instanceof Error ? error.message : "Slayd o'chirishda xatolik.");
            }
          };
          void submitDelete();
        }}
      />
      <StatusModal open={statusModal.state.open} type={statusModal.state.type} message={statusModal.state.message} />
    </section>
  );
}
