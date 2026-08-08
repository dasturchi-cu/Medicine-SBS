"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import { Heart, MessageCircle } from "lucide-react";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { PageSkeleton } from "@/components/page-skeleton";
import { StatusModal } from "@/components/status-modal";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { deleteAdminComment, fetchAdminComments, replyAdminComment, toggleAdminCommentHeart, type AdminCommentItem } from "@/lib/api/admin-comments";
import { fetchCourses } from "@/lib/api/courses";
import { notifyError, notifySuccess } from "@/lib/notify";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import { useStatusModal } from "@/lib/use-status-modal";

export default function CommentsPage() {
  const [comments, setComments] = useState<AdminCommentItem[]>([]);
  const [courses, setCourses] = useState<Array<{ id: string; title_uz: string }>>([]);
  const [loading, setLoading] = useState(true);
  const [deleteCommentId, setDeleteCommentId] = useState<string | null>(null);
  const [replyOpenId, setReplyOpenId] = useState<string | null>(null);
  const [replyValues, setReplyValues] = useState<Record<string, string>>({});
  const statusModal = useStatusModal();
  const reloadDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    let mounted = true;
    const load = async (silent = false) => {
      try {
        if (silent) {
          const commentItems = await fetchAdminComments();
          if (!mounted) return;
          setComments(commentItems);
          return;
        }
        const [commentItems, courseItems] = await Promise.all([fetchAdminComments(), fetchCourses()]);
        if (!mounted) return;
        setComments(commentItems);
        setCourses(courseItems.map((item) => ({ id: item.id, title_uz: item.title_uz })));
      } catch (error) {
        if (!mounted || silent) return;
        notifyError(error instanceof Error ? error.message : "Izohlarni olishda xatolik.");
      } finally {
        if (mounted) setLoading(false);
      }
    };

    const scheduleReload = (silent: boolean) => {
      if (reloadDebounceRef.current) clearTimeout(reloadDebounceRef.current);
      reloadDebounceRef.current = setTimeout(() => {
        reloadDebounceRef.current = null;
        void load(silent);
      }, 650);
    };

    void load();

    const supabase = getSupabaseBrowserClient();
    const channel = supabase
      ?.channel("admin-comments-live")
      .on("postgres_changes", { event: "*", schema: "public", table: "app_comments" }, () => {
        scheduleReload(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "app_comment_likes" }, () => {
        scheduleReload(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "comments" }, () => {
        scheduleReload(true);
      })
      .on("postgres_changes", { event: "*", schema: "public", table: "comment_reactions" }, () => {
        scheduleReload(true);
      })
      .subscribe();

    return () => {
      mounted = false;
      if (reloadDebounceRef.current) clearTimeout(reloadDebounceRef.current);
      if (channel) {
        void supabase?.removeChannel(channel);
      }
    };
  }, []);

  const commentThreads = useMemo(
    () =>
      comments
        .filter((item) => item.parent_id === null)
        .map((item) => ({
          root: item,
          replies: comments.filter((reply) => reply.parent_id === item.id),
        })),
    [comments],
  );

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <div className="surface-card space-y-2 p-5">
        <h3 className="text-lg font-semibold text-slate-900">Izohlar va javoblar</h3>
        <p className="text-sm text-slate-500">Real backenddan izohlar: yurakcha, javob yozish va o&apos;chirish shu yerda.</p>
      </div>

      <div className="surface-card space-y-4 p-4 sm:p-5">
        {commentThreads.length > 0 ? (
          commentThreads.map(({ root, replies }) => {
            const courseName =
              (root.course_title && root.course_title.trim()) ||
              courses.find((entry) => entry.id === root.course_id)?.title_uz ||
              root.course_id;
            const isReplyOpen = replyOpenId === root.id;
            const replyValue = replyValues[root.id] ?? "";
            return (
              <article key={root.id} className="rounded-2xl border border-slate-100 bg-white p-4">
                <CommentRow
                  username={root.user_name}
                  userId={root.user_id}
                  isAdmin={false}
                  courseName={courseName}
                  text={root.text}
                  date={root.created_at}
                  hearts={root.hearts}
                  hearted={root.hearted_by_admin}
                  onHeart={async () => {
                    try {
                      const updated = await statusModal.run({
                        loadingMessage: "Reaksiya yangilanmoqda...",
                        successMessage: "Muvaffaqiyatli yangilandi",
                        errorMessage: "Yurakcha bosishda xatolik.",
                        action: async () => toggleAdminCommentHeart(root.id),
                      });
                      setComments((prev) => prev.map((item) => (item.id === updated.id ? updated : item)));
                    } catch (error) {
                      notifyError(error instanceof Error ? error.message : "Yurakcha bosishda xatolik.");
                    }
                  }}
                  onReply={() => setReplyOpenId((prev) => (prev === root.id ? null : root.id))}
                  onDelete={() => setDeleteCommentId(root.id)}
                />

                {replies.length > 0 ? (
                  <div className="mt-3 space-y-3 border-l-2 border-slate-100 pl-4">
                    {replies.map((reply) => (
                      <CommentRow
                        key={reply.id}
                        username={reply.user_name}
                        userId={reply.user_id}
                        isAdmin={false}
                        courseName={courseName}
                        text={reply.text}
                        date={reply.created_at}
                        hearts={reply.hearts}
                        hearted={reply.hearted_by_admin}
                        onHeart={async () => {
                          try {
                            const updated = await statusModal.run({
                              loadingMessage: "Reaksiya yangilanmoqda...",
                              successMessage: "Muvaffaqiyatli yangilandi",
                              errorMessage: "Yurakcha bosishda xatolik.",
                              action: async () => toggleAdminCommentHeart(reply.id),
                            });
                            setComments((prev) => prev.map((item) => (item.id === updated.id ? updated : item)));
                          } catch (error) {
                            notifyError(error instanceof Error ? error.message : "Yurakcha bosishda xatolik.");
                          }
                        }}
                        onReply={() => setReplyOpenId(root.id)}
                        onDelete={() => setDeleteCommentId(reply.id)}
                      />
                    ))}
                  </div>
                ) : null}

                {isReplyOpen ? (
                  <div className="mt-3 flex flex-wrap items-center gap-2 border-l-2 border-slate-100 pl-4">
                    <Input
                      value={replyValue}
                      onChange={(event) => setReplyValues((prev) => ({ ...prev, [root.id]: event.target.value }))}
                      placeholder="Admin javobi..."
                      className="h-10 w-full flex-1 rounded-xl border-slate-200 sm:min-w-[240px]"
                    />
                    <Button
                      className="h-10 rounded-xl px-4"
                      onClick={async () => {
                        if (!replyValue.trim()) return;
                        try {
                          const inserted = await statusModal.run({
                            loadingMessage: "Javob saqlanmoqda...",
                            successMessage: "Javob muvaffaqiyatli yuborildi",
                            errorMessage: "Javob yuborishda xatolik.",
                            action: async () => replyAdminComment(root.id, replyValue),
                          });
                          setComments((prev) => [inserted, ...prev]);
                          setReplyValues((prev) => ({ ...prev, [root.id]: "" }));
                          setReplyOpenId(null);
                          notifySuccess("Javob yuborildi.");
                        } catch (error) {
                          notifyError(error instanceof Error ? error.message : "Javob yuborishda xatolik.");
                        }
                      }}
                    >
                      Javob yuborish
                    </Button>
                  </div>
                ) : null}
              </article>
            );
          })
        ) : (
          <p className="text-sm text-slate-400">Hali izohlar yozilmagan.</p>
        )}
      </div>

      <ConfirmDialog
        open={Boolean(deleteCommentId)}
        title="Izohni o&apos;chirish"
        description="Rostdan ham ushbu izohni o&apos;chirmoqchimisiz?"
        confirmText="Ha, o&apos;chirish"
        onCancel={() => setDeleteCommentId(null)}
        onConfirm={() => {
          const submitDelete = async () => {
            if (!deleteCommentId) return;
            try {
              await statusModal.run({
                loadingMessage: "Izoh o'chirilmoqda...",
                successMessage: "Muvaffaqiyatli o'chirildi",
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

interface CommentRowProps {
  username: string;
  userId: string;
  isAdmin: boolean;
  courseName: string;
  text: string;
  date: string;
  hearts: number;
  hearted: boolean;
  onHeart: () => void;
  onReply: () => void;
  onDelete: () => void;
}

function CommentRow({ username, userId, isAdmin, courseName, text, date, hearts, hearted, onHeart, onReply, onDelete }: CommentRowProps) {
  return (
    <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
      <div className="min-w-0 flex-1">
        <div className="mb-2 flex flex-wrap items-center gap-2">
          <div className="inline-flex size-9 items-center justify-center rounded-full bg-[#eff4ff] text-xs font-semibold text-primary">
            {username.slice(0, 1).toUpperCase()}
          </div>
          {isAdmin ? (
            <span className="text-sm font-semibold text-slate-800">Admin</span>
          ) : (
            <Link href={`/users/${userId}`} className="text-sm font-semibold text-slate-800 hover:text-primary">
              {username}
            </Link>
          )}
          <span className="rounded-lg bg-slate-50 px-2 py-1 text-xs text-slate-500">{courseName}</span>
          <span className="text-xs text-slate-400">{date.replace("T", " ").slice(0, 16)}</span>
        </div>
        <p className="text-sm leading-6 text-slate-700">{text}</p>
        <div className="mt-2 flex items-center gap-2">
          <Button variant={hearted ? "destructive" : "ghost"} size="sm" className="h-8 rounded-lg px-2 text-xs" onClick={onHeart}>
            <Heart className="size-3.5" />
            {hearts}
          </Button>
          <Button variant="ghost" size="sm" className="h-8 rounded-lg px-2 text-xs" onClick={onReply}>
            <MessageCircle className="size-3.5" />
            Javob yozish
          </Button>
        </div>
      </div>
      <Button variant="destructive" className="h-8 w-full rounded-lg px-3 text-xs sm:w-auto" onClick={onDelete}>
        O&apos;chirish
      </Button>
    </div>
  );
}
