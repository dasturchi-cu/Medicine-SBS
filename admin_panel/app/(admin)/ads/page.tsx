"use client";

import { type ChangeEvent, type FormEvent, useEffect, useMemo, useRef, useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppModal } from "@/components/modal";
import { StatusModal } from "@/components/status-modal";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { createAd, fetchAds, removeAd, type AdItem, updateAd } from "@/lib/api/ads";
import { notifyError, notifySuccess } from "@/lib/notify";
import { uploadFileToSupabase } from "@/lib/supabase/storage";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { useStatusModal } from "@/lib/use-status-modal";

export default function AdsPage() {
  const [ads, setAds] = useState<AdItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [editAd, setEditAd] = useState<AdItem | null>(null);
  const [deleteAdId, setDeleteAdId] = useState<string | null>(null);
  const [uploading, setUploading] = useState<"none" | "create" | "edit">("none");
  const imageInputCreateRef = useRef<HTMLInputElement | null>(null);
  const imageInputEditRef = useRef<HTMLInputElement | null>(null);
  const [formValues, setFormValues] = useState({
    title: "",
    message: "",
    price: "",
    image: "",
    telegram: "Mr_Xusanboy",
    isActive: false,
  });
  const [editValues, setEditValues] = useState({
    title: "",
    message: "",
    price: "",
    image: "",
    telegram: "Mr_Xusanboy",
    isActive: false,
  });
  const statusModal = useStatusModal();

  useEffect(() => {
    let mounted = true;
    const load = async (silent = false) => {
      try {
        const adItems = await fetchAds();
        if (!mounted) return;
        setAds(adItems);
      } catch (error) {
        if (!mounted || silent) return;
        notifyError(error instanceof Error ? error.message : "Reklamalar yuklanmadi.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();
    const supabase = getSupabaseBrowserClient();
    const channel = supabase
      ?.channel("admin-ads-live")
      .on("postgres_changes", { event: "*", schema: "public", table: "course_banners" }, () => {
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

  const uploadAdImage = async (file: File, slot: "create" | "edit") => {
    setUploading(slot);
    try {
      const uploaded = await uploadFileToSupabase({
        bucket: "content-assets",
        folder: "ads/images",
        file,
      });
      if (slot === "create") {
        setFormValues((prev) => ({ ...prev, image: uploaded.publicUrl }));
      } else {
        setEditValues((prev) => ({ ...prev, image: uploaded.publicUrl }));
      }
      notifySuccess(uploaded.storageBacked ? "Rasm yuklandi." : "Rasm vaqtincha saqlandi (data URL).");
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Rasm yuklanmadi.");
    } finally {
      setUploading("none");
    }
  };

  const columns = useMemo(
    () => [
      { key: "title", label: "Sarlavha" },
      {
        key: "telegram",
        label: "Telegram",
        render: (item: AdItem) => <span className="text-xs text-slate-600">@{item.telegram.replace(/^@/, "")}</span>,
      },
      { key: "message", label: "Matn" },
      { key: "price_label", label: "Narx" },
      {
        key: "is_active",
        label: "Ilovada",
        render: (item: AdItem) => (
          <span className="text-xs font-medium text-slate-600">{item.is_active ? "Ko‘rsatiladi" : "Yashirin"}</span>
        ),
      },
      {
        key: "actions",
        label: "Amallar",
        render: (item: AdItem) => (
          <div className="flex gap-2">
            <Button
              variant="outline"
              className="h-8 rounded-lg border-slate-200 px-3 text-xs"
              onClick={() => {
                setEditAd(item);
                setEditValues({
                  title: item.title,
                  message: item.message,
                  price: item.price_label,
                  image: item.image_url,
                  telegram: item.telegram?.replace(/^@/, "") || "Mr_Xusanboy",
                  isActive: item.is_active,
                });
              }}
            >
              Tahrirlash
            </Button>
            <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteAdId(item.id)}>
              O&apos;chirish
            </Button>
          </div>
        ),
      },
    ],
    [],
  );

  const onPickImageCreate = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    void uploadAdImage(file, "create");
    event.target.value = "";
  };

  const onPickImageEdit = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    void uploadAdImage(file, "edit");
    event.target.value = "";
  };

  const onSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!formValues.title.trim()) return notifyError("Sarlavhani kiriting.");
    try {
      const created = await statusModal.run({
        loadingMessage: "Reklama saqlanmoqda...",
        successMessage: "Reklama muvaffaqiyatli saqlandi",
        errorMessage: "Ad qo'shilmadi.",
        action: async () =>
          createAd({
            title: formValues.title.trim(),
            message: formValues.message.trim(),
            price_label: formValues.price.trim(),
            image_url: formValues.image.replace(/\s+/g, "").trim(),
            telegram: formValues.telegram.trim().replace(/^@/, "") || "Mr_Xusanboy",
            is_active: formValues.isActive,
          }),
      });
      setAds((prev) => [created, ...prev]);
      notifySuccess("Ad qo'shildi.");
      setFormValues({
        title: "",
        message: "",
        price: "",
        image: "",
        telegram: "Mr_Xusanboy",
        isActive: false,
      });
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Ad qo'shilmadi.");
    }
  };

  return (
    <section className="admin-page space-y-4">
      <p className="rounded-xl border border-blue-100 bg-blue-50/80 px-4 py-3 text-sm text-slate-700">
        Bu yerda <strong>Telegramdagi tashqi kurslar</strong> (maxfiy kanal va hokazo) uchun reklama joylanadi — ilovadagi onlayn kurslar ro‘yxati bilan bog‘lanmaydi. Yangi yozuvlar{" "}
        <strong>yashirin</strong>; ilovada chiqishi uchun pastdagi «Ilovada ko‘rsatish»ni yoqing.
      </p>
      <form onSubmit={onSubmit} className="surface-card grid gap-3 p-4 lg:grid-cols-6">
        <Field label="Sarlavha" value={formValues.title} onChange={(value) => setFormValues((prev) => ({ ...prev, title: value }))} className="lg:col-span-2" />
        <Field label="Matn" value={formValues.message} onChange={(value) => setFormValues((prev) => ({ ...prev, message: value }))} className="lg:col-span-2" />
        <Field label="Narx" value={formValues.price} onChange={(value) => setFormValues((prev) => ({ ...prev, price: value }))} className="lg:col-span-2" />
        <div className="grid gap-2 lg:col-span-3">
          <Label>Rasm (URL yoki galereya)</Label>
          <Input
            value={formValues.image}
            onChange={(event) => setFormValues((prev) => ({ ...prev, image: event.target.value }))}
            placeholder="https://... yoki yuklang"
            className="h-11 rounded-xl border-slate-200"
          />
          <input ref={imageInputCreateRef} type="file" accept="image/*" className="hidden" onChange={onPickImageCreate} />
          <Button
            type="button"
            variant="outline"
            className="h-10 rounded-xl"
            disabled={uploading === "create"}
            onClick={() => imageInputCreateRef.current?.click()}
          >
            {uploading === "create" ? "Yuklanmoqda..." : "Galereyadan rasm yuklash"}
          </Button>
        </div>
        <div className="grid gap-2 lg:col-span-3">
          <Label htmlFor="tg-create">Telegram (username)</Label>
          <Input
            id="tg-create"
            value={formValues.telegram}
            onChange={(event) => setFormValues((prev) => ({ ...prev, telegram: event.target.value }))}
            placeholder="masalan: Mr_Xusanboy"
            className="h-11 rounded-xl border-slate-200"
          />
          <p className="text-xs text-slate-500">
            «Sotib olish» bosilganda foydalanuvchi aynan shu akkauntga yozish uchun Telegram ochiladi (platforma kursiga ulanmaydi).
          </p>
        </div>
        <div className="flex items-center justify-between gap-3 rounded-xl border border-slate-200 px-4 py-3 lg:col-span-6">
          <div>
            <Label htmlFor="ad-active-create" className="text-sm font-medium">
              Ilovada ko‘rsatish
            </Label>
            <p className="text-xs text-slate-500">O‘chiq bo‘lsa, «Kanal yangiliklari»da chiqmaydi.</p>
          </div>
          <Switch
            id="ad-active-create"
            checked={formValues.isActive}
            onCheckedChange={(v) => setFormValues((prev) => ({ ...prev, isActive: Boolean(v) }))}
          />
        </div>
        <Button type="submit" className="h-10 rounded-xl px-4 lg:col-span-6">
          Reklamani saqlash
        </Button>
      </form>
      {loading ? <p className="text-sm text-slate-500">Yuklanmoqda...</p> : <AppTable columns={columns} data={ads} emptyText="Reklamalar topilmadi." />}
      <AppModal open={Boolean(editAd)} onOpenChange={(open) => (!open ? setEditAd(null) : undefined)} title="Ad tahrirlash">
        <form
          className="space-y-3"
          onSubmit={async (event) => {
            event.preventDefault();
            if (!editAd) return;
            try {
              const updated = await statusModal.run({
                loadingMessage: "Reklama yangilanmoqda...",
                successMessage: "Reklama muvaffaqiyatli yangilandi",
                errorMessage: "Ad yangilanmadi.",
                action: async () =>
                  updateAd(editAd.id, {
                    title: editValues.title,
                    message: editValues.message,
                    price_label: editValues.price,
                    image_url: editValues.image,
                    telegram: editValues.telegram.trim().replace(/^@/, "") || "Mr_Xusanboy",
                    is_active: editValues.isActive,
                  }),
              });
              setAds((prev) => prev.map((item) => (item.id === updated.id ? updated : item)));
              setEditAd(null);
              notifySuccess("Ad yangilandi.");
            } catch (error) {
              notifyError(error instanceof Error ? error.message : "Ad yangilanmadi.");
            }
          }}
        >
          <Field label="Sarlavha" value={editValues.title} onChange={(value) => setEditValues((prev) => ({ ...prev, title: value }))} />
          <Field label="Matn" value={editValues.message} onChange={(value) => setEditValues((prev) => ({ ...prev, message: value }))} />
          <Field label="Narx" value={editValues.price} onChange={(value) => setEditValues((prev) => ({ ...prev, price: value }))} />
          <div className="grid gap-2">
            <Label>Rasm (URL yoki galereya)</Label>
            <Input
              value={editValues.image}
              onChange={(event) => setEditValues((prev) => ({ ...prev, image: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
            <input ref={imageInputEditRef} type="file" accept="image/*" className="hidden" onChange={onPickImageEdit} />
            <Button
              type="button"
              variant="outline"
              className="h-10 rounded-xl"
              disabled={uploading === "edit"}
              onClick={() => imageInputEditRef.current?.click()}
            >
              {uploading === "edit" ? "Yuklanmoqda..." : "Galereyadan rasm yuklash"}
            </Button>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="tg-edit">Telegram (username)</Label>
            <Input
              id="tg-edit"
              value={editValues.telegram}
              onChange={(event) => setEditValues((prev) => ({ ...prev, telegram: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <div className="flex items-center justify-between gap-3 rounded-xl border border-slate-200 px-4 py-3">
            <Label htmlFor="ad-active-edit" className="text-sm font-medium">
              Ilovada ko‘rsatish
            </Label>
            <Switch
              id="ad-active-edit"
              checked={editValues.isActive}
              onCheckedChange={(v) => setEditValues((prev) => ({ ...prev, isActive: Boolean(v) }))}
            />
          </div>
          <Button type="submit" className="h-10 rounded-xl px-4">
            Yangilash
          </Button>
        </form>
      </AppModal>
      <ConfirmDialog
        open={Boolean(deleteAdId)}
        title="Adni o'chirish"
        description="Rostdan ham adni o'chirasizmi?"
        confirmText="Ha, o'chirish"
        onCancel={() => setDeleteAdId(null)}
        onConfirm={async () => {
          if (!deleteAdId) return;
          try {
            await statusModal.run({
              loadingMessage: "Reklama o'chirilmoqda...",
              successMessage: "Muvaffaqiyatli o'chirildi",
              errorMessage: "Adni o'chirishda xatolik.",
              action: async () => removeAd(deleteAdId),
            });
            setAds((prev) => prev.filter((item) => item.id !== deleteAdId));
            notifySuccess("Ad o'chirildi.");
            setDeleteAdId(null);
          } catch (error) {
            notifyError(error instanceof Error ? error.message : "Adni o'chirishda xatolik.");
          }
        }}
      />
      <StatusModal open={statusModal.state.open} type={statusModal.state.type} message={statusModal.state.message} />
    </section>
  );
}

function Field({
  label,
  value,
  onChange,
  className,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  className?: string;
}) {
  return (
    <div className={`grid gap-2 ${className ?? ""}`}>
      <Label>{label}</Label>
      <Input value={value} onChange={(event) => onChange(event.target.value)} className="h-11 rounded-xl border-slate-200" />
    </div>
  );
}
