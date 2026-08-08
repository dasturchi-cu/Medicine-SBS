"use client";

import { type FormEvent, useEffect, useMemo, useState } from "react";
import { BlueBanner } from "@/components/blue-banner";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppForm } from "@/components/form";
import { ImagePicker } from "@/components/image-picker";
import { AppModal } from "@/components/modal";
import { PageSkeleton } from "@/components/page-skeleton";
import { StatusModal } from "@/components/status-modal";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { fetchCourses, type CourseItem } from "@/lib/api/courses";
import { createSlide, deleteSlide, fetchSlides, type SlideItem, updateSlide } from "@/lib/api/slides";
import { notifyError, notifySuccess } from "@/lib/notify";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { useStatusModal } from "@/lib/use-status-modal";

export default function HomeBannersPage() {
  const [courses, setCourses] = useState<CourseItem[]>([]);
  const [homeBanners, setHomeBanners] = useState<SlideItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [editBanner, setEditBanner] = useState<SlideItem | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [formValues, setFormValues] = useState({
    title: "",
    button_text: "Boshlash",
    image: "",
    course_id: "",
  });
  const [editValues, setEditValues] = useState({
    title: "",
    button_text: "Boshlash",
    image: "",
    course_id: "",
  });
  const statusModal = useStatusModal();
  const runStatus = statusModal.run;

  useEffect(() => {
    let mounted = true;
    const load = async (silent = false) => {
      try {
        const [courseItems, slideItems] = await Promise.all([fetchCourses(), fetchSlides()]);
        if (!mounted) return;
        setCourses(courseItems);
        setHomeBanners(slideItems);
        setFormValues((prev) => ({ ...prev, course_id: prev.course_id || courseItems[0]?.id || "" }));
      } catch (error) {
        if (!mounted || silent) return;
        notifyError(error instanceof Error ? error.message : "Home reklamalarni olishda xatolik.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();
    const supabase = getSupabaseBrowserClient();
    const channel = supabase
      ?.channel("admin-home-slides-live")
      .on("postgres_changes", { event: "*", schema: "public", table: "home_slides" }, () => {
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

  const columns = useMemo(
    () => [
      {
        key: "preview",
        label: "Ko'rinish",
        render: (item: SlideItem) =>
          item.image_url ? (
            <div className="h-12 w-20 rounded-xl bg-cover bg-center" style={{ backgroundImage: `url(${item.image_url})` }} />
          ) : (
            <BlueBanner />
          ),
      },
      { key: "title", label: "Banner matni" },
      { key: "button_text", label: "Tugma" },
      {
        key: "courseId",
        label: "Kurs",
        render: (item: SlideItem) => courses.find((course) => course.id === item.course_id)?.title_uz ?? "—",
      },
      {
        key: "actions",
        label: "Amallar",
        render: (item: SlideItem) => (
          <div className="flex flex-wrap gap-2">
            <Button
              variant="outline"
              className="h-8 rounded-lg border-slate-200 px-3 text-xs"
              onClick={() => {
                setEditBanner(item);
                setEditValues({
                  title: item.title,
                  button_text: item.button_text,
                  image: item.image_url,
                  course_id: item.course_id ?? "",
                });
              }}
            >
              Tahrirlash
            </Button>
            <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteId(item.id)}>
              O&apos;chirish
            </Button>
          </div>
        ),
      },
    ],
    [courses],
  );

  const onSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!formValues.title.trim()) {
      notifyError("Banner matnini kiriting.");
      return;
    }
    if (!formValues.course_id) {
      notifyError("Qaysi kursga o'tishini tanlang.");
      return;
    }
    try {
      const created = await runStatus({
        loadingMessage: "Home reklama saqlanmoqda...",
        successMessage: "Home reklama muvaffaqiyatli saqlandi",
        errorMessage: "Home reklama qo'shilmadi.",
        action: async () => createSlide({
          title: formValues.title.trim(),
          subtitle: "",
          image_url: formValues.image.trim(),
          button_text: formValues.button_text.trim() || "Boshlash",
          course_id: formValues.course_id || null,
          order_no: homeBanners.length + 1,
        }),
      });
      setHomeBanners((prev) => [...prev, created]);
      notifySuccess("Home reklama muvaffaqiyatli qo'shildi.");
      setFormValues({
        title: "",
        button_text: "Boshlash",
        image: "",
        course_id: formValues.course_id,
      });
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Home reklama qo'shilmadi.");
    }
  };

  const onEditSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!editBanner) return;
    if (!editValues.title.trim()) {
      notifyError("Banner matnini kiriting.");
      return;
    }
    if (!editValues.course_id) {
      notifyError("Qaysi kursga o'tishini tanlang.");
      return;
    }
    try {
      const updated = await runStatus({
        loadingMessage: "Home reklama yangilanmoqda...",
        successMessage: "Home reklama muvaffaqiyatli yangilandi",
        errorMessage: "Home reklama yangilanmadi.",
        action: async () => updateSlide(editBanner.id, {
          title: editValues.title.trim(),
          image_url: editValues.image.trim(),
          button_text: editValues.button_text.trim() || "Boshlash",
          course_id: editValues.course_id || null,
        }),
      });
      setHomeBanners((prev) => prev.map((item) => (item.id === updated.id ? updated : item)));
      notifySuccess("Home reklama muvaffaqiyatli yangilandi.");
      setEditBanner(null);
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Home reklama yangilanmadi.");
    }
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <AppForm
        title="Home reklama yaratish"
        description="Ilovaning eng yuqorisidagi «Boshlash» slaydi shu yerda. Kurs tanlash majburiy. Rasm ixtiyoriy — bo‘lmasa ilovada oddiy ko‘k kartochka chiqadi."
        onSubmit={onSubmit}
      >
        <div className="grid gap-2">
          <Label htmlFor="title">Banner matni</Label>
          <Input
            id="title"
            value={formValues.title}
            onChange={(event) => setFormValues((prev) => ({ ...prev, title: event.target.value }))}
            placeholder="Masalan: Nevron tarmoqlari"
            className="h-11 rounded-xl border-slate-200"
          />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="button_text">Tugma matni</Label>
          <Input
            id="button_text"
            value={formValues.button_text}
            onChange={(event) => setFormValues((prev) => ({ ...prev, button_text: event.target.value }))}
            placeholder="Boshlash"
            className="h-11 rounded-xl border-slate-200"
          />
        </div>
        <ImagePicker
          label="Rasm (ixtiyoriy)"
          value={formValues.image}
          helperText="Rasm yuklamasangiz yoki URL qoldirsangiz, ilovada banner oddiy ko‘k fon bilan chiqadi."
          onChange={(value) => setFormValues((prev) => ({ ...prev, image: value }))}
        />
        <div className="grid gap-2">
          <Label htmlFor="home_course_id">Boshlash bosilganda qaysi kursga o&apos;tsin?</Label>
          <Select value={formValues.course_id} onValueChange={(value) => setFormValues((prev) => ({ ...prev, course_id: value ?? "" }))}>
            <SelectTrigger id="home_course_id" className="h-11 rounded-xl border-slate-200">
              <SelectValue placeholder="Kursni tanlang">
                {courses.find((course) => course.id === formValues.course_id)?.title_uz ?? "Kursni tanlang"}
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
      </AppForm>

      <AppTable columns={columns} data={homeBanners} emptyText="Hali home reklamalar qo&apos;shilmagan." />

      <AppModal
        open={Boolean(editBanner)}
        onOpenChange={(open) => (!open ? setEditBanner(null) : undefined)}
        title="Home reklamani tahrirlash"
        description="Reklama ma&apos;lumotlarini yangilang."
      >
        <AppForm title="Home reklamani yangilash" submitLabel="Saqlash" onSubmit={onEditSubmit}>
          <div className="grid gap-2">
            <Label htmlFor="edit_title">Banner matni</Label>
            <Input
              id="edit_title"
              value={editValues.title}
              onChange={(event) => setEditValues((prev) => ({ ...prev, title: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="edit_button_text">Tugma matni</Label>
            <Input
              id="edit_button_text"
              value={editValues.button_text}
              onChange={(event) => setEditValues((prev) => ({ ...prev, button_text: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <ImagePicker
            label="Rasm (ixtiyoriy)"
            value={editValues.image}
            helperText="Rasm yuklamasangiz yoki URL qoldirsangiz, ilovada banner oddiy ko‘k fon bilan chiqadi."
            onChange={(value) => setEditValues((prev) => ({ ...prev, image: value }))}
          />
          <div className="grid gap-2">
            <Label htmlFor="edit_home_course_id">Boshlash bosilganda qaysi kursga o&apos;tsin?</Label>
            <Select value={editValues.course_id} onValueChange={(value) => setEditValues  ((prev) => ({ ...prev, course_id: value ?? "" }))}>
              <SelectTrigger id="edit_home_course_id" className="h-11 rounded-xl border-slate-200">
                <SelectValue placeholder="Kursni tanlang">
                  {courses.find((course) => course.id === editValues.course_id)?.title_uz ?? "Kursni tanlang"}
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
        </AppForm>
      </AppModal>

      <ConfirmDialog
        open={Boolean(deleteId)}
        title="Home reklamani o&apos;chirish"
        description="Rostdan ham ushbu reklamani o&apos;chirmoqchimisiz?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteId(null)}
        onConfirm={async () => {
          if (!deleteId) return;
          try {
            await runStatus({
              loadingMessage: "Home reklama o'chirilmoqda...",
              successMessage: "Home reklama muvaffaqiyatli o'chirildi",
              errorMessage: "Home reklama o'chirilmadi.",
              action: async () => deleteSlide(deleteId),
            });
            setHomeBanners((prev) => prev.filter((item) => item.id !== deleteId));
            notifySuccess("Home reklama muvaffaqiyatli o'chirildi.");
            setDeleteId(null);
          } catch (error) {
            notifyError(error instanceof Error ? error.message : "Home reklama o'chirilmadi.");
          }
        }}
      />
      <StatusModal open={statusModal.state.open} type={statusModal.state.type} message={statusModal.state.message} />
    </section>
  );
}
