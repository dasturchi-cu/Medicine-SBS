"use client";

import { type ChangeEvent, type FormEvent, useEffect, useMemo, useRef, useState } from "react";
import Image from "next/image";
import { AppForm } from "@/components/form";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { PageSkeleton } from "@/components/page-skeleton";
import { StatusModal } from "@/components/status-modal";
import { createBook, createBookCategory, deleteBook, fetchBookCategories, fetchBooks, type BookCategory, type BookItem } from "@/lib/api/content-assets";
import { notifyError, notifySuccess } from "@/lib/notify";
import { uploadFileToSupabase } from "@/lib/supabase/storage";
import { useStatusModal } from "@/lib/use-status-modal";

export default function BooksPage() {
  const [items, setItems] = useState<BookItem[]>([]);
  const [categories, setCategories] = useState<BookCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [form, setForm] = useState({
    title: "",
    description: "",
    thumbnail: "",
    fileUrl: "",
    fileMime: "application/pdf",
    category: "",
    author: "",
  });
  const [uploading, setUploading] = useState<"none" | "cover" | "pdf">("none");
  const [selectedCoverName, setSelectedCoverName] = useState("");
  const [selectedFileName, setSelectedFileName] = useState("");
  const coverInputRef = useRef<HTMLInputElement | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const statusModal = useStatusModal();

  useEffect(() => {
    let mounted = true;
    const load = async (silent = false) => {
      try {
        const [result, categoryItems] = await Promise.all([
          fetchBooks(),
          fetchBookCategories(),
        ]);
        if (mounted) setItems(result);
        if (mounted) setCategories(categoryItems);
      } catch (error) {
        if (!silent && mounted) {
          notifyError(error instanceof Error ? error.message : "Server bilan aloqa yo'q.");
          setItems([]);
        }
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
      { key: "author", label: "Muallif" },
      { key: "category_name", label: "Kategoriya" },
      {
        key: "file_url",
        label: "PDF",
        render: (item: BookItem) => (
          <a className="text-blue-600 underline" href={item.file_url} target="_blank" rel="noreferrer">
            Ochish
          </a>
        ),
      },
      {
        key: "actions",
        label: "Amallar",
        render: (item: BookItem) => (
          <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteId(item.id)}>
            O&apos;chirish
          </Button>
        ),
      },
    ],
    [],
  );

  const onUpload = async (file: File, type: "cover" | "pdf") => {
    setUploading(type);
    try {
      console.log("[books.upload]", { type, name: file.name, size: file.size, mime: file.type });
      const uploaded = await uploadFileToSupabase({
        bucket: "content-assets",
        folder: type === "cover" ? "books/covers" : "books/pdf",
        file,
      });
      if (type === "cover") {
        setForm((prev) => ({ ...prev, thumbnail: uploaded.publicUrl }));
        setSelectedCoverName(file.name);
      } else {
        setForm((prev) => ({
          ...prev,
          fileUrl: uploaded.publicUrl,
          fileMime: file.type.includes("presentation") || file.name.toLowerCase().endsWith(".ppt") || file.name.toLowerCase().endsWith(".pptx")
            ? "application/vnd.openxmlformats-officedocument.presentationml.presentation"
            : "application/pdf",
        }));
        setSelectedFileName(file.name);
      }
      notifySuccess(uploaded.storageBacked ? "Fayl muvaffaqiyatli yuklandi." : "Fayl vaqtincha local (data URL) saqlandi.");
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Upload xatosi.");
    } finally {
      setUploading("none");
    }
  };

  const onSelectCover = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    void onUpload(file, "cover");
  };

  const onSelectContent = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    void onUpload(file, "pdf");
  };

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const submit = async () => {
      try {
        if (!form.fileUrl.trim()) {
          notifyError("Avval fayl tanlang yoki URL kiriting.");
          return;
        }
        if (!form.title.trim()) {
          notifyError("Kitob nomini kiriting.");
          return;
        }
        console.log("[books.submit.start]", form);
        const categoryValue = form.category.trim();
        let categoryId: string | null = null;
        if (categoryValue) {
          const existing = categories.find((item) => item.name.toLowerCase() === categoryValue.toLowerCase());
          if (existing) {
            categoryId = existing.id;
          } else {
            const slug = categoryValue
              .toLowerCase()
              .replace(/[^a-z0-9\s-]/g, "")
              .trim()
              .replace(/\s+/g, "-");
            try {
              const createdCategory = await createBookCategory({ name: categoryValue, slug: slug || `cat-${Date.now()}` });
              categoryId = createdCategory.id;
              setCategories((prev) => [createdCategory, ...prev]);
            } catch (categoryError) {
              // If category module is not migrated yet, continue creating book without category.
              console.warn("[books.category.create.fallback]", categoryError);
              categoryId = null;
            }
          }
        }
        const created = await statusModal.run({
          loadingMessage: "Kitob saqlanmoqda...",
          successMessage: "Kitob muvaffaqiyatli qo'shildi",
          errorMessage: "Kitob qo'shilmadi.",
          action: async () =>
            createBook({
              title: form.title.trim(),
              description: form.description.trim(),
              cover_image_url: form.thumbnail.replace(/\s+/g, "").trim(),
              file_url: form.fileUrl.replace(/\s+/g, "").trim(),
              file_mime: form.fileMime,
              author: form.author.trim(),
              category_id: categoryId,
            }),
        });
        setItems((prev) => [created, ...prev]);
        console.log("[books.submit.success]", created);
        setForm({
          title: "",
          description: "",
          thumbnail: "",
          fileUrl: "",
          fileMime: "application/pdf",
          category: "",
          author: "",
        });
        setSelectedCoverName("");
        setSelectedFileName("");
        notifySuccess("Kitob qo'shildi.");
      } catch (error) {
        console.error("[books.submit.error]", error);
        notifyError(error instanceof Error ? error.message : "Kitob qo'shilmadi.");
      }
    };
    void submit();
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page space-y-6">
      <AppForm title="Kitob qo'shish" description="PDF kitob yuklang va foydalanuvchilarga taqdim eting." onSubmit={onSubmit} submitLabel="Saqlash">
        <div className="grid gap-2">
          <Label htmlFor="title">Nomi</Label>
          <Input id="title" value={form.title} onChange={(e) => setForm((p) => ({ ...p, title: e.target.value }))} />
        </div>
        <div className="grid gap-2">
          <div className="grid gap-2">
            <Label htmlFor="bookType">Turi</Label>
            <select
              id="bookType"
              className="h-11 rounded-xl border border-slate-200 bg-white px-3 text-sm"
              value={form.fileMime}
              onChange={(e) => setForm((p) => ({ ...p, fileMime: e.target.value }))}
            >
              <option value="application/pdf">PDF</option>
              <option value="application/vnd.openxmlformats-officedocument.presentationml.presentation">PPT/PPTX</option>
            </select>
          </div>
        </div>
        <div className="grid gap-2 sm:grid-cols-2">
          <div className="grid gap-2">
            <Label htmlFor="author">Muallif</Label>
            <Input id="author" value={form.author} onChange={(e) => setForm((p) => ({ ...p, author: e.target.value }))} />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="category">Kategoriya</Label>
            <Input id="category" value={form.category} onChange={(e) => setForm((p) => ({ ...p, category: e.target.value }))} />
          </div>
        </div>
        <div className="grid gap-2">
          <Label htmlFor="description">Tavsif</Label>
          <Input id="description" value={form.description} onChange={(e) => setForm((p) => ({ ...p, description: e.target.value }))} />
        </div>
        <div className="grid gap-2">
          <Label>Cover rasm</Label>
          <input ref={coverInputRef} type="file" accept="image/*" className="hidden" onChange={onSelectCover} />
          <Button type="button" variant="outline" className="justify-start" onClick={() => coverInputRef.current?.click()}>
            Rasm tanlash
          </Button>
          <p className="text-xs text-slate-500">{selectedCoverName || "Rasm tanlanmagan"}</p>
          <Input value={form.thumbnail} placeholder="Yoki rasm URL kiriting" onChange={(e) => setForm((p) => ({ ...p, thumbnail: e.target.value }))} />
          {form.thumbnail.trim() ? (
            <div className="overflow-hidden rounded-xl border border-slate-200">
              <Image src={form.thumbnail} alt="Cover preview" width={640} height={320} className="h-40 w-full object-cover" />
            </div>
          ) : null}
        </div>
        <div className="grid gap-2">
          <Label>Fayl (PDF/PPT)</Label>
          <input
            ref={fileInputRef}
            type="file"
            accept=".pdf,.ppt,.pptx,application/pdf,application/vnd.ms-powerpoint,application/vnd.openxmlformats-officedocument.presentationml.presentation"
            className="hidden"
            onChange={onSelectContent}
          />
          <Button type="button" variant="outline" className="justify-start" onClick={() => fileInputRef.current?.click()}>
            Fayl tanlash
          </Button>
          <p className="text-xs text-slate-500">{selectedFileName || "Fayl tanlanmagan"}</p>
          <Input value={form.fileUrl} placeholder="Yoki fayl URL kiriting" onChange={(e) => setForm((p) => ({ ...p, fileUrl: e.target.value }))} />
        </div>
        {uploading !== "none" ? <p className="text-sm text-slate-500">Fayl yuklanmoqda...</p> : null}
      </AppForm>

      <AppTable columns={columns} data={items} emptyText="Kitoblar hali yo'q." />

      <ConfirmDialog
        open={Boolean(deleteId)}
        title="Kitobni o'chirish"
        description="Ushbu kitobni o'chirishni tasdiqlaysizmi?"
        confirmText="Ha, o'chirish"
        onCancel={() => setDeleteId(null)}
        onConfirm={() => {
          const submitDelete = async () => {
            if (!deleteId) return;
            try {
              await deleteBook(deleteId);
              setItems((prev) => prev.filter((item) => item.id !== deleteId));
              setDeleteId(null);
              notifySuccess("Kitob o'chirildi.");
            } catch (error) {
              notifyError(error instanceof Error ? error.message : "Kitobni o'chirib bo'lmadi.");
            }
          };
          void submitDelete();
        }}
      />
      <StatusModal open={statusModal.state.open} type={statusModal.state.type} message={statusModal.state.message} />
    </section>
  );
}
