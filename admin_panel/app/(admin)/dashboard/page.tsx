"use client";

import { useEffect, useMemo, useState } from "react";
import { PageSkeleton } from "@/components/page-skeleton";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { fetchAds } from "@/lib/api/ads";
import { fetchCourses, type CourseItem } from "@/lib/api/courses";
import { fetchLessons, type LessonItem } from "@/lib/api/lessons";
import { fetchUsers } from "@/lib/api/users";
import { notifyError } from "@/lib/notify";

export default function DashboardPage() {
  const [courses, setCourses] = useState<CourseItem[]>([]);
  const [lessons, setLessons] = useState<LessonItem[]>([]);
  const [adsCount, setAdsCount] = useState(0);
  const [usersCount, setUsersCount] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    const load = async () => {
      try {
        const [courseItems, lessonItems, adsItems, users] = await Promise.all([
          fetchCourses(),
          fetchLessons(),
          fetchAds(),
          fetchUsers(),
        ]);
        if (!mounted) return;
        setCourses(courseItems);
        setLessons(lessonItems);
        setAdsCount(adsItems.length);
        setUsersCount(users.length);
      } catch (error) {
        if (!mounted) return;
        notifyError(error instanceof Error ? error.message : "Boshqaruv paneli ma'lumotlarini olishda xatolik.");
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
    const mostViewed = [...courses].sort((a, b) => b.views - a.views)[0];
    const mostSold = [...courses].sort((a, b) => b.sales - a.sales)[0];
    const unsold = courses.filter((course) => course.sales === 0);
    const totalViews = courses.reduce((sum, course) => sum + course.views, 0);
    const totalSales = courses.reduce((sum, course) => sum + course.sales, 0);
    const conversion = totalViews > 0 ? (totalSales / totalViews) * 100 : 0;
    return { mostViewed, mostSold, unsold, conversion };
  }, [courses]);

  const stats = [
    { label: "Jami kurslar", value: courses.length },
    { label: "Jami darslar", value: lessons.length },
    { label: "Kanal reklamalari", value: adsCount },
    { label: "Faol foydalanuvchilar", value: usersCount },
  ];

  if (loading) return <PageSkeleton />;

  return (
    <section className="admin-page">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {stats.map((stat) => (
          <Card key={stat.label} className="surface-card">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-slate-500">{stat.label}</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-semibold text-slate-900 sm:text-3xl">{stat.value}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card className="surface-card">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Eng ko&apos;p ko&apos;rilgan kurs</CardTitle>
          </CardHeader>
          <CardContent className="text-sm">
            <p className="font-semibold text-slate-900">{analytics.mostViewed?.title_uz ?? "Ma'lumot yo'q"}</p>
            <p className="mt-1 text-slate-500">{analytics.mostViewed?.views ?? 0} marta ko&apos;rilgan</p>
          </CardContent>
        </Card>

        <Card className="surface-card">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Eng ko&apos;p sotilgan kurs</CardTitle>
          </CardHeader>
          <CardContent className="text-sm">
            <p className="font-semibold text-slate-900">{analytics.mostSold?.title_uz ?? "Ma'lumot yo'q"}</p>
            <p className="mt-1 text-slate-500">{analytics.mostSold?.sales ?? 0} ta sotuv</p>
          </CardContent>
        </Card>

        <Card className="surface-card">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Umuman sotilmagan kurslar</CardTitle>
          </CardHeader>
          <CardContent className="text-sm">
            {analytics.unsold.length > 0 ? (
              <ul className="space-y-1">
                {analytics.unsold.map((course) => (
                  <li key={course.id} className="text-slate-700">
                    {course.title_uz}
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-slate-500">Barcha kurslarda sotuv mavjud.</p>
            )}
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <Card className="surface-card">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Conversion</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-slate-900">{analytics.conversion.toFixed(2)}%</p>
            <p className="mt-1 text-xs text-slate-500">
              Kurs ko&apos;rganlardan nechtasi sotib olganini foizda ko&apos;rsatadi. Past bo&apos;lsa, sotuv past degani.
            </p>
          </CardContent>
        </Card>
        <Card className="surface-card">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Top kurs</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-base font-semibold text-slate-900">{analytics.mostSold?.title_uz ?? "Ma'lumot yo'q"}</p>
            <p className="text-sm text-slate-500">{analytics.mostSold?.sales ?? 0} ta sotuv</p>
          </CardContent>
        </Card>
        <Card className="surface-card">
          <CardHeader>
            <CardTitle className="text-sm text-slate-500">Jami sotuv</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-2xl font-semibold text-slate-900">{courses.reduce((sum, c) => sum + c.sales, 0)}</p>
          </CardContent>
        </Card>
      </div>

      <Card className="surface-card">
        <CardHeader>
          <CardTitle>Backend holati</CardTitle>
        </CardHeader>
        <CardContent className="text-sm text-slate-600">
          Boshqaruv paneli endi real APIdan o&apos;qiydi. Agar qiymatlar 0 bo&apos;lsa, Supabase jadvalida hali ma&apos;lumot yo&apos;qligini bildiradi.
        </CardContent>
      </Card>
    </section>
  );
}
