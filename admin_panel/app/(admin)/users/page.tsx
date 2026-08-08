"use client";

import Link from "next/link";
import { type FormEvent, useEffect, useMemo, useState } from "react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { AppModal } from "@/components/modal";
import { PageSkeleton } from "@/components/page-skeleton";
import { StatusModal } from "@/components/status-modal";
import { AppTable } from "@/components/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { fetchUsers, removeUser, type AdminUserItem, updateUser } from "@/lib/api/users";
import { notifyError, notifySuccess } from "@/lib/notify";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { useStatusModal } from "@/lib/use-status-modal";

export default function UsersPage() {
  const [users, setUsers] = useState<AdminUserItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [editUser, setEditUser] = useState<AdminUserItem | null>(null);
  const [deleteUserId, setDeleteUserId] = useState<string | null>(null);
  const [editValues, setEditValues] = useState({ name: "", email: "" });
  const statusModal = useStatusModal();
  const runStatus = statusModal.run;

  useEffect(() => {
    let mounted = true;
    const load = async (silent = false) => {
      try {
        const usersItems = await fetchUsers();
        if (!mounted) return;
        setUsers(usersItems);
      } catch (error) {
        if (!mounted || silent) return;
        notifyError(error instanceof Error ? error.message : "Foydalanuvchilarni olishda xatolik.");
      } finally {
        if (mounted) setLoading(false);
      }
    };
    void load();
    const supabase = getSupabaseBrowserClient();
    const channel = supabase
      ?.channel("admin-users-live")
      .on("postgres_changes", { event: "*", schema: "public", table: "users" }, () => {
        void load(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "user_entitlements" }, () => {
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
        key: "name",
        label: "Foydalanuvchi",
        render: (user: AdminUserItem) => (
          <Link href={`/users/${user.id}`} className="text-primary hover:underline">
            {user.name}
          </Link>
        ),
      },
      { key: "id", label: "Foydalanuvchi ID" },
      { key: "email", label: "Telefon raqam" },
      { key: "login_count", label: "Login soni" },
      { key: "app_open_count", label: "App open soni" },
      {
        key: "is_blocked",
        label: "Holat",
        render: (user: AdminUserItem) =>
          user.is_blocked ? (
            <span className="rounded-lg bg-red-50 px-2 py-1 text-xs text-red-600">Bloklangan</span>
          ) : (
            <span className="rounded-lg bg-emerald-50 px-2 py-1 text-xs text-emerald-600">Faol</span>
          ),
      },
      {
        key: "actions",
        label: "Amallar",
        render: (user: AdminUserItem) => (
          <div className="flex flex-wrap gap-2">
            <Button
              variant="outline"
              className="h-8 rounded-lg border-slate-200 px-3 text-xs"
              onClick={() => {
                setEditUser(user);
                setEditValues({ name: user.name, email: user.email });
              }}
            >
              Tahrirlash
            </Button>
            <Button variant="destructive" className="h-8 rounded-lg px-3 text-xs" onClick={() => setDeleteUserId(user.id)}>
              O&apos;chirish
            </Button>
          </div>
        ),
      },
    ],
    [runStatus],
  );

  const onEditSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!editUser) return;
    try {
      const updated = await runStatus({
        loadingMessage: "Foydalanuvchi saqlanmoqda...",
        successMessage: "Foydalanuvchi muvaffaqiyatli yangilandi",
        errorMessage: "Foydalanuvchini yangilab bo'lmadi.",
        action: async () =>
          updateUser(editUser.id, {
            name: editValues.name.trim(),
            email: editValues.email.trim(),
          }),
      });
      setUsers((prev) => prev.map((item) => (item.id === updated.id ? updated : item)));
      notifySuccess("Foydalanuvchi muvaffaqiyatli yangilandi.");
      setEditUser(null);
    } catch (error) {
      notifyError(error instanceof Error ? error.message : "Foydalanuvchini yangilab bo'lmadi.");
    }
  };

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <AppTable
        columns={columns}
        data={users}
        emptyText="Foydalanuvchi topilmadi."
        searchPlaceholder="ID, ism yoki telefon raqam bo'yicha qidiring"
        pageSize={8}
      />

      <AppModal open={Boolean(editUser)} onOpenChange={(open) => (!open ? setEditUser(null) : undefined)} title="Foydalanuvchini tahrirlash">
        <form className="space-y-3" onSubmit={onEditSubmit}>
          <div className="grid gap-2">
            <Label htmlFor="edit_name">Ism</Label>
            <Input
              id="edit_name"
              value={editValues.name}
              onChange={(event) => setEditValues((prev) => ({ ...prev, name: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="edit_email">Telefon raqam</Label>
            <Input
              id="edit_email"
              value={editValues.email}
              onChange={(event) => setEditValues((prev) => ({ ...prev, email: event.target.value }))}
              className="h-11 rounded-xl border-slate-200"
            />
          </div>
          <Button type="submit" className="h-10 rounded-xl px-4">
            Saqlash
          </Button>
        </form>
      </AppModal>
      <ConfirmDialog
        open={Boolean(deleteUserId)}
        title="Foydalanuvchini o'chirish"
        description="Bu amal ortga qaytarilmaydi. Davom etasizmi?"
        confirmText="Ha, o'chirish"
        onCancel={() => setDeleteUserId(null)}
        onConfirm={async () => {
          if (!deleteUserId) return;
          try {
            await runStatus({
              loadingMessage: "Foydalanuvchi o'chirilmoqda...",
              successMessage: "Muvaffaqiyatli o'chirildi",
              errorMessage: "Foydalanuvchini o'chirishda xatolik.",
              action: async () => removeUser(deleteUserId),
            });
            setUsers((prev) => prev.filter((item) => item.id !== deleteUserId));
            notifySuccess("Foydalanuvchi o'chirildi.");
            setDeleteUserId(null);
          } catch (error) {
            notifyError(error instanceof Error ? error.message : "Foydalanuvchini o'chirishda xatolik.");
          }
        }}
      />
      <StatusModal open={statusModal.state.open} type={statusModal.state.type} message={statusModal.state.message} />
    </section>
  );
}
