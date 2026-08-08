"use client";

import { type FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  ADMIN_PASSWORD,
  ADMIN_PHONE_FULL,
  ADMIN_PHONE_PREFIX,
  ADMIN_PHONE_SUFFIX,
  formatPhoneSuffix,
  getFullPhoneFromSuffix,
  isAdminAuthenticated,
  setAdminAuthenticated,
} from "@/lib/admin-auth";

export default function LoginPage() {
  const router = useRouter();
  const nextPath = "/dashboard";

  const [phoneSuffix, setPhoneSuffix] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    if (isAdminAuthenticated()) {
      router.replace(nextPath);
    }
  }, [nextPath, router]);

  const onSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    const fullPhone = getFullPhoneFromSuffix(phoneSuffix);
    const normalized = fullPhone.replace(/\D/g, "");

    if (normalized !== ADMIN_PHONE_FULL.replace(/\D/g, "") || password !== ADMIN_PASSWORD) {
      setError("Telefon yoki parol noto'g'ri.");
      return;
    }

    setAdminAuthenticated(true);
    router.replace(nextPath);
  };

  return (
    <main className="flex min-h-[100dvh] items-center justify-center px-4 py-10 safe-pad-x safe-pad-bottom safe-pad-top">
      <Card className="surface-card w-full max-w-md border-slate-100 shadow-lg">
        <CardHeader className="space-y-1">
          <CardTitle className="text-2xl">Admin kirish</CardTitle>
          <p className="text-sm text-slate-500">
            Telefon raqam va parol orqali tizimga kiring.
          </p>
        </CardHeader>
        <CardContent>
          <form className="space-y-4" onSubmit={onSubmit}>
            <div>
              <label className="mb-2 block text-sm font-medium text-slate-700">
                Telefon raqam
              </label>
              <div className="flex h-11 overflow-hidden rounded-xl border border-slate-200 bg-white">
                <div className="flex items-center bg-slate-50 px-3 text-sm font-semibold text-slate-600">
                  {ADMIN_PHONE_PREFIX}
                </div>
                <Input
                  value={phoneSuffix}
                  onChange={(event) => setPhoneSuffix(formatPhoneSuffix(event.target.value))}
                  placeholder={ADMIN_PHONE_SUFFIX}
                  className="h-full border-0 rounded-none shadow-none focus-visible:ring-0"
                />
              </div>
            </div>

            <div>
              <label className="mb-2 block text-sm font-medium text-slate-700">
                Parol
              </label>
              <Input
                type="password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                placeholder="Parolni kiriting"
                className="h-11 rounded-xl border-slate-200"
              />
            </div>

            {error ? (
              <p className="rounded-xl bg-red-50 px-3 py-2 text-sm text-red-600">{error}</p>
            ) : null}

            <Button type="submit" className="h-11 w-full rounded-xl bg-primary hover:bg-primary/90">
              Kirish
            </Button>
          </form>
        </CardContent>
      </Card>
    </main>
  );
}
