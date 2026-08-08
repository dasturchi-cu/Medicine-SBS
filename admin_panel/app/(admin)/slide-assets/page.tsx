"use client";

import { type ChangeEvent, type FormEvent, useEffect, useMemo, useRef, useState } from "react";
import { AppForm } from "@/components/form";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { PageSkeleton } from "@/components/page-skeleton";
import { StatusModal } from "@/components/status-modal";
import { createLessonAsset, deleteLessonAsset, fetchLessonAssets, type LessonAssetItem } from "@/lib/api/content-assets";
import { fetchCourses } from "@/lib/api/courses";
import { fetchLessons, type LessonItem } from "@/lib/api/lessons";
import { notifyError, notifySuccess } from "@/lib/notify";
import { uploadFileToSupabase } from "@/lib/supabase/storage";
import { useStatusModal } from "@/lib/use-status-modal";

export default function SlideAssetsPage() {
  const [items, setItems] = useState<LessonAssetItem[]>([]);
  const [courses, setCourses] = useState<Array<{ id: string; title_uz: string }>>([]);
  const [lessons, setLessons] = useState<LessonItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [form, setForm] = useState({
    title: "",
    description: "",
    file_url: "",
    preview_image_url: "",
    course_id: "",
    lesson_id: "",
    type: "pdf" as "pdf" | "ppt",
    order_no: "1",
  });
  const [selectedFileName, setSelectedFileName] = useState("");
  const [selectedPreviewName, setSelectedPreviewName] = useState("");
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const previewInputRef = useRef<HTMLInputElement | null>(null);
  const statusModal = useStatusModal();
  const filteredLessons = lessons.filter((item) => (form.course_id ? item.course_id === form.course_id : true));

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      try {
        const [result, courseItems, lessonItems] = await Promise.all([
          fetchLessonAssets(),
          fetchCourses(),
          fetchLessons(),
        ]);
        if (mounted) setItems(result);
        if (mounted) setCourses(courseItems.map((item) => ({ id: item.id, title_uz: item.title_uz })));
        if (mounted) setLessons(lessonItems);
        if (mounted) {
          setForm((prev) => (prev.course_id ? prev : { ...prev, course_id: courseItems[0]?.id ?? "" }));
        }
      } catch (error) {
        if (mounted) notifyError(error instanceof Error ? error.message : "Server bilan aloqa yo'q.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();
    return () => {
      mounted = false;
    };
  }, []);

  const columns = useMemo(
    () => [
      { key: "title", label: "Nomi" },
      { key: "file_type", label: "Turi" },
      {
        key: "course_id",
        label: "Kurs",
        render: (item: LessonAssetItem) => courses.find((course) => course.id === item.course_id)?.title_uz ?? "—",
      },
      {
        key: "lesson_id",
        label: "Dars",
        render: (item: LessonAssetItem) => lessons.find((lesson) => lesson.id === item.lesson_id)?.title ?? "—",
      },
      {
        key: "file_url",
        label: "Fayl",
        render: (item: LessonAssetItem) => (
          <a className="text-blue-600 underline" href={item.file_url} target="_blank" rel="noreferrer">
            Ochish
          </a>
        ),
      },
      {
        key: "actions",
        label: "Amallar",
        render: (item: LessonAssetItem) => (
          <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteId(item.id)}>
            O&apos;chirish
          </Button>
        ),
      },
    ],
    [courses, lessons],
  );

  const uploadAsset = async (file: File, kind: "file" | "preview") => {
    try {
      console.log("[slide-assets.upload]", { kind, name: file.name, size: file.size, mime: file.type });
      const uploaded = await uploadFileToSupabase({
        bucket: "content-assets",
        folder: kind === "file" ? "slides/files" : "slides/previews",
        file,
      });
      if (kind === "file") {
        setForm((prev) => ({ ...prev, file_url: uploaded.publicUrl }));
        setSelectedFileName(file.name);
      } else {
        setForm((prev) => ({ ...prev, preview_image_url: uploaded.publicUrl }));
        setSelectedPreviewName(file.name);
      }
      notifySuccess(uploaded.storageBacked ? "Fayl yuklandi." : "Fayl vaqtincha local (data URL) saqlandi.");
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Upload xatolik.");
    }
  };

  const onSelectFile = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    void uploadAsset(file, "file");
  };

  const onSelectPreview = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    void uploadAsset(file, "preview");
  };

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const submit = async () => {
      try {
        if (!form.course_id.trim() || !form.lesson_id.trim()) {
          notifyError("Kurs va darsni tanlang.");
          return;
        }
        if (!form.file_url.trim()) {
          notifyError("Avval fayl tanlang yoki URL kiriting.");
          return;
        }
        console.log("[slide-assets.submit.start]", form);
        const created = await statusModal.run({
          loadingMessage: "Slayd saqlanmoqda...",
          successMessage: "Slayd muvaffaqiyatli saqlandi",
          errorMessage: "Slayd qo'shib bo'lmadi.",
          action: async () =>
            createLessonAsset({
              title: form.title.trim(),
              description: form.description.trim(),
              file_url: form.file_url.replace(/\s+/g, "").trim(),
              file_type: form.type,
              preview_image_url: form.preview_image_url.replace(/\s+/g, "").trim(),
              course_id: form.course_id.trim() || null,
              lesson_id: form.lesson_id.trim() || null,
              order_no: Number(form.order_no) || 1,
            }),
        });
        setItems((prev) => [created, ...prev].sort((a, b) => a.order_no - b.order_no));
        console.log("[slide-assets.submit.success]", created);
        setForm((prev) => ({
          title: "",
          description: "",
          file_url: "",
          preview_image_url: "",
          course_id: prev.course_id,
          lesson_id: "",
          type: "pdf",
          order_no: "1",
        }));
        setSelectedFileName("");
        setSelectedPreviewName("");
        notifySuccess("Slayd qo'shildi.");
      } catch (error) {
        console.error("[slide-assets.submit.error]", error);
        notifyError(error instanceof Error ? error.message : "Slayd qo'shilmadi.");
      }
    };
    void submit();
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page space-y-6">
      <AppForm title="PDF/PPT slayd qo'shish" description="Kurs yoki darsga bog'langan kontent fayllarini yuklang." onSubmit={onSubmit} submitLabel="Saqlash">
        <div className="grid gap-2 sm:grid-cols-2">
          <div className="grid gap-2">
            <Label htmlFor="title">Nomi</Label>
            <Input id="title" value={form.title} onChange={(e) => setForm((p) => ({ ...p, title: e.target.value }))} />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="type">Turi</Label>
            <select id="type" className="h-11 rounded-xl border border-slate-200 bg-white px-3 text-sm" value={form.type} onChange={(e) => setForm((p) => ({ ...p, type: e.target.value as "pdf" | "ppt" }))}>
              <option value="pdf">PDF</option>
              <option value="ppt">PPT</option>
            </select>
          </div>
        </div>
        <div className="grid gap-2">
          <Label htmlFor="description">Tavsif</Label>
          <Input id="description" value={form.description} onChange={(e) => setForm((p) => ({ ...p, description: e.target.value }))} />
        </div>
        <div className="grid gap-2 sm:grid-cols-2">
          <div className="grid gap-2">
            <Label htmlFor="course">Kurs</Label>
            <select
              id="course"
              className="h-11 rounded-xl border border-slate-200 bg-white px-3 text-sm"
              value={form.course_id}
              onChange={(e) =>
                setForm((p) => ({
                  ...p,
                  course_id: e.target.value,
                  lesson_id: "",
                }))
              }
            >
              <option value="">Kurs tanlang</option>
              {courses.map((course) => (
                <option key={course.id} value={course.id}>
                  {course.title_uz}
                </option>
              ))}
            </select>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="lesson">Dars</Label>
            <select
              id="lesson"
              className="h-11 rounded-xl border border-slate-200 bg-white px-3 text-sm"
              value={form.lesson_id}
              onChange={(e) => setForm((p) => ({ ...p, lesson_id: e.target.value }))}
            >
              <option value="">Dars tanlang</option>
              {filteredLessons.map((lesson) => (
                <option key={lesson.id} value={lesson.id}>
                  {lesson.title}
                </option>
              ))}
            </select>
          </div>
        </div>
        <div className="grid gap-2">
          <Label>Fayl</Label>
          <input
            ref={fileInputRef}
            type="file"
            accept=".pdf,.ppt,.pptx,application/pdf,application/vnd.ms-powerpoint,application/vnd.openxmlformats-officedocument.presentationml.presentation"
            className="hidden"
            onChange={onSelectFile}
          />
          <Button type="button" variant="outline" className="justify-start" onClick={() => fileInputRef.current?.click()}>
            Fayl tanlash
          </Button>
          <p className="text-xs text-slate-500">{selectedFileName || "Fayl tanlanmagan"}</p>
          <Input value={form.file_url} placeholder="Yoki fayl URL kiriting" onChange={(e) => setForm((p) => ({ ...p, file_url: e.target.value }))} />
        </div>
        <div className="grid gap-2">
          <Label>Preview rasm</Label>
          <input ref={previewInputRef} type="file" accept="image/*" className="hidden" onChange={onSelectPreview} />
          <Button type="button" variant="outline" className="justify-start" onClick={() => previewInputRef.current?.click()}>
            Preview rasm tanlash
          </Button>
          <p className="text-xs text-slate-500">{selectedPreviewName || "Preview rasm tanlanmagan"}</p>
          <Input value={form.preview_image_url} placeholder="Preview image URL" onChange={(e) => setForm((p) => ({ ...p, preview_image_url: e.target.value }))} />
          {form.preview_image_url.trim() ? (
            <div className="overflow-hidden rounded-xl border border-slate-200">
              <img src={form.preview_image_url} alt="Preview" className="h-40 w-full object-cover" />
            </div>
          ) : null}
        </div>
      </AppForm>

      <AppTable columns={columns} data={items} emptyText="Slayd fayllar hali yo'q." />

      <ConfirmDialog
        open={Boolean(deleteId)}
        title="Slaydni o'chirish"
        description="Ushbu kontent faylini o'chirasizmi?"
        confirmText="Ha, o'chirish"
        onCancel={() => setDeleteId(null)}
        onConfirm={() => {
          const submitDelete = async () => {
            if (!deleteId) return;
            try {
              await deleteLessonAsset(deleteId);
              setItems((prev) => prev.filter((item) => item.id !== deleteId));
              setDeleteId(null);
              notifySuccess("Slayd o'chirildi.");
            } catch (error) {
              notifyError(error instanceof Error ? error.message : "Slayd o'chirilmadi.");
            }
          };
          void submitDelete();
        }}
      />
      <StatusModal open={statusModal.state.open} type={statusModal.state.type} message={statusModal.state.message} />
    </section>
  );
}
