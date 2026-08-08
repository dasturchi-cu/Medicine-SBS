"use client";

import Link from "next/link";
import { type Dispatch, type FormEvent, type SetStateAction, useEffect, useMemo, useState } from "react";
import { BlueBanner } from "@/components/blue-banner";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppForm } from "@/components/form";
import { ImagePicker } from "@/components/image-picker";
import { AppModal } from "@/components/modal";
import { PageSkeleton } from "@/components/page-skeleton";
import { StatusModal } from "@/components/status-modal";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { createCourse, fetchCourses, removeCourse, updateCourse } from "@/lib/api/courses";
import { notifyError, notifySuccess } from "@/lib/notify";
import { useStatusModal } from "@/lib/use-status-modal";

interface CourseFormValues {
  title: string;
  summary: string;
  price: string;
  admin_telegram: string;
  image: string;
}

interface CourseRow {
  id: string;
  title_uz: string;
  title_ru: string;
  title_en: string;
  price_uzs: number;
  admin_telegram: string;
  image_url: string;
  description_uz: string;
  views: number;
  sales: number;
}

const emptyCourseForm: CourseFormValues = {
  title: "",
  summary: "",
  price: "",
  admin_telegram: "Mr_Xusanboy",
  image: "",
};

export default function CoursesPage() {
  const [courseList, setCourseList] = useState<CourseRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [editCourse, setEditCourse] = useState<CourseRow | null>(null);
  const [deleteCourseId, setDeleteCourseId] = useState<string | null>(null);
  const [formValues, setFormValues] = useState<CourseFormValues>(emptyCourseForm);
  const [editValues, setEditValues] = useState<CourseFormValues>(emptyCourseForm);
  const statusModal = useStatusModal();

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      try {
        const items = await fetchCourses();
        if (!mounted) return;
        setCourseList(items);
      } catch (error) {
        if (!mounted) return;
        setCourseList([]);
        notifyError(error instanceof Error ? error.message : "Kurslarni olishda xatolik.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();
    return () => {
      mounted = false;
    };
  }, []);

  const analytics = useMemo(() => {
    const sold = [...courseList].sort((a, b) => b.sales - a.sales).slice(0, 3);
    const viewed = [...courseList].sort((a, b) => b.views - a.views).slice(0, 3);
    const unsold = courseList.filter((course) => course.sales === 0);
    return { sold, viewed, unsold };
  }, [courseList]);

  const columns = useMemo(
    () => [
      {
        key: "preview",
        label: "Rasm",
        render: (item: CourseRow) =>
          item.image_url ? (
            <div
              className="h-12 w-20 rounded-xl bg-cover bg-center"
              style={{ backgroundImage: `url(${item.image_url})` }}
            />
          ) : (
            <BlueBanner />
          ),
      },
      {
        key: "title",
        label: "Nomi",
        render: (item: CourseRow) => (
          <p className="font-medium text-slate-800">{item.title_uz}</p>
        ),
      },
      {
        key: "price",
        label: "Narx",
        render: (item: CourseRow) => formatPrice(item.price_uzs),
      },
      {
        key: "admin_telegram",
        label: "Admin",
        render: (item: CourseRow) => `@${item.admin_telegram}`,
      },
      {
        key: "actions",
        label: "Amallar",
        render: (item: CourseRow) => (
          <div className="flex flex-wrap items-center gap-2">
            <Link
              href={`/courses/${item.id}`}
              className="inline-flex h-8 items-center rounded-lg border border-slate-200 px-3 text-xs text-slate-700 transition-colors hover:border-primary hover:text-primary"
            >
              Ko&apos;rish
            </Link>
            <Button
              variant="outline"
              className="h-8 rounded-lg border-slate-200 px-3 text-xs hover:border-primary hover:text-primary"
              onClick={() => {
                setEditCourse(item);
                setEditValues({
                  title: item.title_uz,
                  summary: item.description_uz ?? "",
                  price: formatPrice(item.price_uzs),
                  admin_telegram: item.admin_telegram,
                  image: item.image_url,
                });
              }}
            >
              Tahrirlash
            </Button>
            <Button
              variant="destructive"
              className="h-8 rounded-lg px-3 text-xs"
              onClick={() => setDeleteCourseId(item.id)}
            >
              O&apos;chirish
            </Button>
          </div>
        ),
      },
    ],
    [],
  );

  const onSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    try {
      const title = formValues.title.trim();
      if (!title) {
        notifyError("Kurs nomini kiriting.");
        return;
      }
      const summary = formValues.summary.trim();
      const translated = autoTranslateTitle(title);
      const created = await statusModal.run({
        loadingMessage: "Kurs saqlanmoqda...",
        successMessage: "Kurs muvaffaqiyatli saqlandi",
        errorMessage: "Kurs qo'shilmadi.",
        action: async () =>
          createCourse({
            ...translated,
            price_uzs: parsePrice(formValues.price),
            admin_telegram: normalizeTelegram(formValues.admin_telegram),
            image_url: formValues.image.trim(),
            description_uz: summary,
          }),
      });
      setCourseList((prev) => [created, ...prev]);
      notifySuccess("Kurs muvaffaqiyatli qo'shildi.");
      setFormValues(emptyCourseForm);
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Kurs qo'shilmadi.");
    }
  };

  const onEditSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!editCourse) return;
    try {
      const title = editValues.title.trim();
      if (!title) {
        notifyError("Kurs nomini kiriting.");
        return;
      }
      const summary = editValues.summary.trim();
      const translated = autoTranslateTitle(title);
      const updated = await statusModal.run({
        loadingMessage: "Kurs yangilanmoqda...",
        successMessage: "Kurs muvaffaqiyatli yangilandi",
        errorMessage: "Kurs yangilanmadi.",
        action: async () =>
          updateCourse(editCourse.id, {
            ...translated,
            price_uzs: parsePrice(editValues.price),
            admin_telegram: normalizeTelegram(editValues.admin_telegram),
            image_url: editValues.image.trim(),
            description_uz: summary,
          }),
      });
      setCourseList((prev) => prev.map((item) => (item.id === updated.id ? updated : item)));
      notifySuccess("Kurs muvaffaqiyatli yangilandi.");
      setEditCourse(null);
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Kurs yangilanmadi.");
    }
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <AppForm
        title="Kurs yaratish"
        onSubmit={onSubmit}
        submitLabel="Kursni saqlash"
      >
        <LanguageFields values={formValues} onChange={setFormValues} />
        <ImagePicker
          label="Rasm (upload yoki link)"
          value={formValues.image}
          onChange={(value) => setFormValues((prev) => ({ ...prev, image: value }))}
        />
      </AppForm>

      <div className="grid gap-4 lg:grid-cols-3">
        <AnalyticsCard title="Eng ko&apos;p sotilgan kurslar" items={analytics.sold.map((course) => `${course.title_uz} (${course.sales})`)} />
        <AnalyticsCard title="Eng ko&apos;p ko&apos;rilgan kurslar" items={analytics.viewed.map((course) => `${course.title_uz} (${course.views})`)} />
        <AnalyticsCard title="Sotilmagan kurslar" items={analytics.unsold.map((course) => course.title_uz)} />
      </div>

      <AppTable columns={columns} data={courseList} emptyText="Hali kurslar qo&apos;shilmagan." />

      <AppModal
        open={Boolean(editCourse)}
        onOpenChange={(open) => (!open ? setEditCourse(null) : undefined)}
        title="Kursni tahrirlash"
        description="Sarlavhani yangilang, tizim tarjimalarni avtomatik hisoblaydi."
      >
        <AppForm title="Kursni yangilash" submitLabel="Saqlash" onSubmit={onEditSubmit}>
          <LanguageFields values={editValues} onChange={setEditValues} />
          <ImagePicker
            label="Rasm (upload yoki link)"
            value={editValues.image}
            onChange={(value) => setEditValues((prev) => ({ ...prev, image: value }))}
          />
        </AppForm>
      </AppModal>

      <ConfirmDialog
        open={Boolean(deleteCourseId)}
        title="Kursni o&apos;chirish"
        description="Rostdan ham ushbu kursni o&apos;chirmoqchimisiz? Kursga bog&apos;liq darslar ham o&apos;chadi."
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteCourseId(null)}
        onConfirm={async () => {
          if (!deleteCourseId) return;
          try {
            await statusModal.run({
              loadingMessage: "Kurs o'chirilmoqda...",
              successMessage: "Muvaffaqiyatli o'chirildi",
              errorMessage: "Kurs o'chirilmadi.",
              action: async () => removeCourse(deleteCourseId),
            });
            setCourseList((prev) => prev.filter((course) => course.id !== deleteCourseId));
            notifySuccess("Kurs muvaffaqiyatli o'chirildi.");
            setDeleteCourseId(null);
          } catch (error) {
            notifyError(error instanceof Error ? error.message : "Kurs o'chirilmadi.");
          }
        }}
      />
      <StatusModal open={statusModal.state.open} type={statusModal.state.type} message={statusModal.state.message} />
    </section>
  );
}

interface LanguageFieldsProps {
  values: CourseFormValues;
  onChange: Dispatch<SetStateAction<CourseFormValues>>;
}

function LanguageFields({ values, onChange }: LanguageFieldsProps) {
  return (
    <div className="space-y-3">
      <div className="grid gap-2">
        <Label htmlFor="title">Kurs sarlavhasi</Label>
        <input
          id="title"
          value={values.title}
          onChange={(event) => onChange((prev) => ({ ...prev, title: event.target.value }))}
          placeholder="Masalan: Kardiologiya asoslari"
          className="h-11 rounded-xl border border-slate-200 px-3 text-sm outline-none focus:border-primary"
        />
      </div>
      <div className="grid gap-2">
        <Label htmlFor="summary">Qisqacha tavsif</Label>
        <textarea
          id="summary"
          value={values.summary}
          onChange={(event) => onChange((prev) => ({ ...prev, summary: event.target.value }))}
          placeholder="Kurs haqida qisqacha yozing..."
          className="min-h-[96px] rounded-xl border border-slate-200 px-3 py-2 text-sm outline-none focus:border-primary"
        />
      </div>
      <div className="grid gap-2">
        <Label htmlFor="price">Kurs narxi</Label>
        <input
          id="price"
          value={values.price}
          onChange={(event) => onChange((prev) => ({ ...prev, price: event.target.value }))}
          placeholder="Masalan: 299 000 so'm"
          className="h-11 rounded-xl border border-slate-200 px-3 text-sm outline-none focus:border-primary"
        />
      </div>
      <div className="grid gap-2">
        <Label htmlFor="admin_telegram">Kurs admini (Telegram)</Label>
        <input
          id="admin_telegram"
          value={values.admin_telegram}
          onChange={(event) => onChange((prev) => ({ ...prev, admin_telegram: event.target.value }))}
          placeholder="Mr_Xusanboy"
          className="h-11 rounded-xl border border-slate-200 px-3 text-sm outline-none focus:border-primary"
        />
      </div>
    </div>
  );
}

interface AnalyticsCardProps {
  title: string;
  items: string[];
}

function AnalyticsCard({ title, items }: AnalyticsCardProps) {
  return (
    <div className="surface-card p-4">
      <h4 className="mb-2 text-sm font-semibold text-slate-700">{title}</h4>
      {items.length > 0 ? (
        <ul className="space-y-1">
          {items.map((item, index) => (
            <li key={`${item}-${index}`} className="text-sm text-slate-600">
              {item}
            </li>
          ))}
        </ul>
      ) : (
        <p className="text-sm text-slate-400">Ma&apos;lumot yo&apos;q.</p>
      )}
    </div>
  );
}

function autoTranslateTitle(title: string) {
  const trimmed = title.trim();
  return {
    title_uz: trimmed,
    title_ru: `${trimmed} (RU)`,
    title_en: `${trimmed} (EN)`,
  };
}

function parsePrice(value: string) {
  const normalized = value.replace(/[^\d.]/g, "");
  const parsed = Number.parseFloat(normalized);
  if (!Number.isFinite(parsed) || parsed < 0) return 0;
  return parsed;
}

function formatPrice(value: number) {
  return `${Math.round(value).toLocaleString("ru-RU")} so'm`;
}

function normalizeTelegram(value: string) {
  return value.replace(/^@/, "").trim() || "Mr_Xusanboy";
}

