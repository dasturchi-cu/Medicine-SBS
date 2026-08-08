"use client";

import { type FormEvent, useEffect, useMemo, useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppForm } from "@/components/form";
import { ImagePicker } from "@/components/image-picker";
import { PageSkeleton } from "@/components/page-skeleton";
import { StatusModal } from "@/components/status-modal";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { createNotification, fetchNotifications, removeNotification, type NotificationCampaign } from "@/lib/api/notifications";
import { fetchUsers } from "@/lib/api/users";
import { notifyError, notifySuccess } from "@/lib/notify";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { useStatusModal } from "@/lib/use-status-modal";

export default function NotificationsPage() {
  const [notifications, setNotifications] = useState<NotificationCampaign[]>([]);
  const [totalUsers, setTotalUsers] = useState(0);
  const [loading, setLoading] = useState(true);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [formValues, setFormValues] = useState({
    title: "",
    message: "",
    image: "",
  });
  const statusModal = useStatusModal();
  const runStatus = statusModal.run;

  useEffect(() => {
    let mounted = true;
    const load = async (silent = false) => {
      try {
        const [items, users] = await Promise.all([fetchNotifications(), fetchUsers()]);
        if (mounted) {
          setNotifications(items);
          setTotalUsers(users.length);
        }
      } catch (error) {
        if (mounted && !silent) setNotifications([]);
        if (!silent) notifyError(error instanceof Error ? error.message : "Notificationlarni olishda xatolik.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();
    const supabase = getSupabaseBrowserClient();
    const channel = supabase
      ?.channel("admin-notifications-live")
      .on("postgres_changes", { event: "*", schema: "public", table: "notifications" }, () => {
        void load(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "notification_deliveries" }, () => {
        void load(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "notification_click_events" }, () => {
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

  const stats = useMemo(() => {
    const totalSent = notifications.reduce((sum, item) => sum + item.recipients_count, 0);
    const totalViewed = notifications.reduce((sum, item) => sum + item.viewed_count, 0);
    const totalClicked = notifications.reduce((sum, item) => sum + item.clicked_count, 0);
    const avgViewRate = totalSent > 0 ? (totalViewed / totalSent) * 100 : 0;
    const avgClickRate = totalSent > 0 ? (totalClicked / totalSent) * 100 : 0;
    return {
      totalUsers,
      sentCampaigns: notifications.length,
      totalSent,
      avgViewRate,
      avgClickRate,
    };
  }, [notifications, totalUsers]);

  const columns = useMemo(
    () => [
      { key: "title", label: "Sarlavha" },
      {
        key: "message",
        label: "Matn",
        render: (item: NotificationCampaign) => <span className="line-clamp-2 max-w-[300px]">{item.message}</span>,
      },
      { key: "recipients_count", label: "Yuborildi" },
      { key: "viewed_count", label: "Ko'rganlar" },
      { key: "clicked_count", label: "Bosganlar" },
      {
        key: "viewRate",
        label: "Ko'rish foizi",
        render: (item: NotificationCampaign) => {
          const rate = item.recipients_count > 0 ? (item.viewed_count / item.recipients_count) * 100 : 0;
          return `${rate.toFixed(1)}%`;
        },
      },
      { key: "sent_at", label: "Vaqt" },
      {
        key: "actions",
        label: "Amallar",
        render: (item: NotificationCampaign) => (
          <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteId(item.id)}>
            O&apos;chirish
          </Button>
        ),
      },
    ],
    [],
  );

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const submit = async () => {
      try {
        const item = await runStatus({
          loadingMessage: "Bildirishnoma yuborilmoqda...",
          successMessage: "Bildirishnoma muvaffaqiyatli yuborildi",
          errorMessage: "Notification yuborilmadi.",
          action: async () => createNotification({
            title: formValues.title,
            message: formValues.message,
            image: formValues.image,
          }),
        });
        setNotifications((prev) => [item, ...prev]);
        notifySuccess("Notification muvaffaqiyatli yuborildi.");
        setFormValues({ title: "", message: "", image: "" });
      } catch (error) {
        notifyError(error instanceof Error ? error.message : "Notification yuborilmadi.");
      }
    };
    void submit();
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard label="Jami foydalanuvchi" value={String(stats.totalUsers)} />
        <StatCard label="Yuborilgan va bor notificationlar" value={String(stats.sentCampaigns)} />
        <StatCard label="Jami yuborilgan notification" value={String(stats.totalSent)} />
        <StatCard label="O'rtacha ko'rish foizi" value={`${stats.avgViewRate.toFixed(1)}%`} />
        <StatCard label="O'rtacha click foizi" value={`${stats.avgClickRate.toFixed(1)}%`} />
      </div>

      <AppForm
        title="Notification yuborish"
        description="Barcha foydalanuvchilarga xabar yuboring. Rasm ham qo&apos;shishingiz mumkin."
        onSubmit={onSubmit}
        submitLabel="Yuborish"
      >
        <div className="grid gap-2">
          <Label htmlFor="title">Sarlavha</Label>
          <Input
            id="title"
            value={formValues.title}
            onChange={(event) => setFormValues((prev) => ({ ...prev, title: event.target.value }))}
            placeholder="Masalan: Yangi darslar chiqdi"
            className="h-11 rounded-xl border-slate-200"
          />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="message">Xabar matni</Label>
          <Input
            id="message"
            value={formValues.message}
            onChange={(event) => setFormValues((prev) => ({ ...prev, message: event.target.value }))}
            placeholder="Masalan: Ilovaga kirib yangi darslarni ko'ring"
            className="h-11 rounded-xl border-slate-200"
          />
        </div>
        <ImagePicker
          label="Notification rasmi (ixtiyoriy)"
          value={formValues.image}
          helperText="Rasm tanlansa, notification bilan birga yuboriladi."
          onChange={(value) => setFormValues((prev) => ({ ...prev, image: value }))}
        />
      </AppForm>

      <AppTable columns={columns} data={notifications} emptyText="Hali notification yuborilmagan." />

      <ConfirmDialog
        open={Boolean(deleteId)}
        title="Notificationni o&apos;chirish"
        description="Rostdan ham ushbu notification tarixini o&apos;chirmoqchimisiz?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteId(null)}
        onConfirm={() => {
          const submitDelete = async () => {
            if (!deleteId) return;
            try {
              await runStatus({
                loadingMessage: "Bildirishnoma o'chirilmoqda...",
                successMessage: "Bildirishnoma muvaffaqiyatli o'chirildi",
                errorMessage: "Notification o'chirilmadi.",
                action: async () => removeNotification(deleteId),
              });
              setNotifications((prev) => prev.filter((item) => item.id !== deleteId));
              notifySuccess("Notification tarixi o'chirildi.");
              setDeleteId(null);
            } catch (error) {
              notifyError(error instanceof Error ? error.message : "Notification o'chirilmadi.");
            }
          };
          void submitDelete();
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
