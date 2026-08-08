"use client";

import { type FormEvent, useEffect, useMemo, useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppForm } from "@/components/form";
import { AppModal } from "@/components/modal";
import { PageSkeleton } from "@/components/page-skeleton";
import { StatusModal } from "@/components/status-modal";
import { AppTable } from "@/components/table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { fetchCourses, type CourseItem } from "@/lib/api/courses";
import { createLesson, fetchLessons, removeLesson, updateLesson, type LessonItem } from "@/lib/api/lessons";
import { notifyError, notifySuccess } from "@/lib/notify";
import { useStatusModal } from "@/lib/use-status-modal";

export default function LessonsPage() {
  const [courses, setCourses] = useState<CourseItem[]>([]);
  const [lessons, setLessons] = useState<LessonItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedCourse, setSelectedCourse] = useState("");
  const [editLesson, setEditLesson] = useState<LessonItem | null>(null);
  const [deleteLessonId, setDeleteLessonId] = useState<string | null>(null);
  const [formValues, setFormValues] = useState({
    title: "",
    videoId: "",
    order: "1",
    isFree: false,
  });
  const [editValues, setEditValues] = useState({
    title: "",
    videoId: "",
    order: "1",
    isFree: false,
  });
  const statusModal = useStatusModal();

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      try {
        const [courseItems, lessonItems] = await Promise.all([fetchCourses(), fetchLessons()]);
        if (!mounted) return;
        setCourses(courseItems);
        setLessons(lessonItems);
        setSelectedCourse((prev) => prev || courseItems[0]?.id || "");
      } catch (error) {
        if (!mounted) return;
        notifyError(error instanceof Error ? error.message : "Darslarni olishda xatolik.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();
    return () => {
      mounted = false;
    };
  }, []);

  const selectedCourseData = courses.find((course) => course.id === selectedCourse);

  const columns = useMemo(
    () => [
      { key: "title", label: "Nomi" },
      { key: "videoId", label: "YouTube link yoki video ID" },
      { key: "order", label: "Tartib" },
      {
        key: "isFree",
        label: "Kirish turi",
        render: (item: LessonRow) => (
          <Badge variant="secondary" className="rounded-lg bg-slate-100 text-slate-700">
            {item.isFree ? "Bepul" : "Pullik"}
          </Badge>
        ),
      },
      {
        key: "actions",
        label: "Amallar",
        render: (item: LessonRow) => (
          <div className="flex flex-wrap gap-2">
            <Button
              variant="outline"
              className="h-8 rounded-lg border-slate-200 px-3 text-xs"
              onClick={() => {
                const source = lessons.find((lesson) => lesson.id === item.id);
                if (!source) return;
                setEditLesson(source);
                setEditValues({
                  title: item.title,
                  videoId: item.videoId,
                  order: String(item.order),
                  isFree: item.isFree,
                });
              }}
            >
              Tahrirlash
            </Button>
            <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteLessonId(item.id)}>
              O&apos;chirish
            </Button>
          </div>
        ),
      },
    ],
    [lessons],
    );

  const filteredLessons: LessonRow[] = lessons
    .filter((lesson) => lesson.course_id === selectedCourse)
    .sort((a, b) => a.order_no - b.order_no)
    .map((item) => ({
      id: item.id,
      title: item.title,
      videoId: item.video_url,
      order: item.order_no,
      isFree: item.is_free,
    }));

  const onSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!selectedCourse) {
      notifyError("Avval kursni tanlang.");
      return;
    }
    const lessonOrder = Number(formValues.order);
    if (!formValues.title.trim()) {
      notifyError("Dars nomini kiriting.");
      return;
    }
    if (!Number.isFinite(lessonOrder) || lessonOrder < 1) {
      notifyError("Dars tartibi 1 yoki undan katta bo'lishi kerak.");
      return;
    }
    try {
      const created = await statusModal.run({
        loadingMessage: "Dars saqlanmoqda...",
        successMessage: "Dars muvaffaqiyatli saqlandi",
        errorMessage: "Dars qo'shilmadi.",
        action: async () => createLesson({
          course_id: selectedCourse,
          title: formValues.title.trim(),
          video_url: formValues.videoId.trim(),
          order_no: lessonOrder,
          is_free: formValues.isFree,
        }),
      });
      setLessons((prev) => [...prev, created]);
      notifySuccess(`${lessonOrder}-chi video muvaffaqiyatli qo'shildi.`);
      setFormValues((prev) => ({ ...prev, title: "", videoId: "", order: "1", isFree: false }));
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Dars qo'shilmadi.");
    }
  };

  const onEditSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!editLesson) return;
    const lessonOrder = Number(editValues.order);
    if (!editValues.title.trim()) {
      notifyError("Dars nomini kiriting.");
      return;
    }
    if (!Number.isFinite(lessonOrder) || lessonOrder < 1) {
      notifyError("Dars tartibi 1 yoki undan katta bo'lishi kerak.");
      return;
    }
    try {
      const updated = await statusModal.run({
        loadingMessage: "Dars yangilanmoqda...",
        successMessage: "Dars muvaffaqiyatli yangilandi",
        errorMessage: "Dars yangilanmadi.",
        action: async () => updateLesson(editLesson.id, {
          course_id: selectedCourse || editLesson.course_id,
          title: editValues.title.trim(),
          video_url: editValues.videoId.trim(),
          order_no: lessonOrder,
          is_free: editValues.isFree,
        }),
      });
      setLessons((prev) => prev.map((item) => (item.id === updated.id ? updated : item)));
      notifySuccess("Dars muvaffaqiyatli yangilandi.");
      setEditLesson(null);
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Dars yangilanmadi.");
    }
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page xl:grid xl:grid-cols-[1fr_390px] xl:items-start">
      <div className="space-y-4">
        <div className="surface-card space-y-4 p-4 sm:p-6">
          <div>
            <h3 className="text-base font-semibold text-slate-900">Filtrlar</h3>
            <p className="text-sm text-slate-500">Kursni tanlab, kerakli darslarni boshqaring.</p>
          </div>
          <Label className="mb-2 block text-sm text-slate-600">Kursni tanlang</Label>
          <Select value={selectedCourse} onValueChange={(value) => setSelectedCourse(value ?? "")}>
            <SelectTrigger className="h-11 w-full rounded-xl border-slate-200">
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
        </div>

        <AppTable columns={columns} data={filteredLessons} emptyText="Bu kurs uchun hali darslar yo&apos;q." />
      </div>

      <AppForm title="Dars qo&apos;shish" description="Tanlangan kurs uchun yangi dars yarating." onSubmit={onSubmit}>
          <div className="grid gap-2">
            <Label htmlFor="title">Dars nomi - title</Label>
            <Input
              id="title"
              value={formValues.title}
              onChange={(event) => setFormValues((prev) => ({ ...prev, title: event.target.value }))}
              placeholder="Dars nomi"
              className="h-11 rounded-xl border-slate-200"
            />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="videoId">YouTube link yoki video ID</Label>
            <Input
              id="videoId"
              value={formValues.videoId}
              onChange={(event) => setFormValues((prev) => ({ ...prev, videoId: event.target.value }))}
              placeholder="Masalan: https://youtu.be/PmRgKMhP_ic yoki PmRgKMhP_ic"
              className="h-11 rounded-xl border-slate-200"
            />
          </div>

          <div className="grid gap-2">
            <Label htmlFor="order">Bu nechanchi dars (order)</Label>
            <Input
              id="order"
              type="number"
              min={1}
              value={formValues.order}
              onChange={(event) => setFormValues((prev) => ({ ...prev, order: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>

          <div className="flex items-center justify-between rounded-xl border border-slate-100 px-4 py-3">
            <Label htmlFor="isFree" className="text-sm text-slate-700">
              Bepul dars
            </Label>
            <Switch
              id="isFree"
              checked={formValues.isFree}
              onCheckedChange={(value) => setFormValues((prev) => ({ ...prev, isFree: value }))}
            />
          </div>
      </AppForm>

      <AppModal
        open={Boolean(editLesson)}
        onOpenChange={(open) => (!open ? setEditLesson(null) : undefined)}
        title="Darsni tahrirlash"
        description="Dars ma&apos;lumotlarini yangilang."
      >
        <AppForm title="Darsni yangilash" submitLabel="Saqlash" onSubmit={onEditSubmit}>
          <div className="grid gap-2">
            <Label htmlFor="edit_title">Dars nomi</Label>
            <Input
              id="edit_title"
              value={editValues.title}
              onChange={(event) => setEditValues((prev) => ({ ...prev, title: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="edit_video">YouTube link yoki video ID</Label>
            <Input
              id="edit_video"
              value={editValues.videoId}
              onChange={(event) => setEditValues((prev) => ({ ...prev, videoId: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="edit_order">Bu nechanchi dars (order)</Label>
            <Input
              id="edit_order"
              type="number"
              min={1}
              value={editValues.order}
              onChange={(event) => setEditValues((prev) => ({ ...prev, order: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <div className="flex items-center justify-between rounded-xl border border-slate-100 px-4 py-3">
            <Label htmlFor="edit_is_free" className="text-sm text-slate-700">
              Bepul dars
            </Label>
            <Switch
              id="edit_is_free"
              checked={editValues.isFree}
              onCheckedChange={(value) => setEditValues((prev) => ({ ...prev, isFree: value }))}
            />
          </div>
        </AppForm>
      </AppModal>

      <ConfirmDialog
        open={Boolean(deleteLessonId)}
        title="Darsni o&apos;chirish"
        description="Rostdan ham ushbu darsni o&apos;chirmoqchimisiz?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteLessonId(null)}
        onConfirm={async () => {
          if (!deleteLessonId) return;
          try {
            await statusModal.run({
              loadingMessage: "Dars o'chirilmoqda...",
              successMessage: "Muvaffaqiyatli o'chirildi",
              errorMessage: "Dars o'chirilmadi.",
              action: async () => removeLesson(deleteLessonId),
            });
            setLessons((prev) => prev.filter((item) => item.id !== deleteLessonId));
            notifySuccess("Dars muvaffaqiyatli o'chirildi.");
            setDeleteLessonId(null);
          } catch (error) {
            notifyError(error instanceof Error ? error.message : "Dars o'chirilmadi.");
          }
        }}
      />
      <StatusModal open={statusModal.state.open} type={statusModal.state.type} message={statusModal.state.message} />
    </section>
  );
}

interface LessonRow {
  id: string;
  title: string;
  videoId: string;
  order: number;
  isFree: boolean;
}
