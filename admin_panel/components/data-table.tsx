"use client";

import { type ReactNode, useMemo, useState } from "react";
import { EmptyState } from "@/components/empty-state";
import {
  Table as UITable,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

export interface DataColumn<T> {
  key: keyof T | string;
  label: string;
  render?: (item: T) => ReactNode;
}

interface DataTableProps<T> {
  columns: DataColumn<T>[];
  data: T[];
  emptyTitle?: string;
  emptyDescription?: string;
  searchPlaceholder?: string;
  searchValue?: string;
  onSearchChange?: (value: string) => void;
  filter?: (item: T, query: string) => boolean;
  pageSize?: number;
}

export function DataTable<T extends object>({
  columns,
  data,
  emptyTitle,
  emptyDescription,
  searchPlaceholder = "Qidirish...",
  searchValue,
  onSearchChange,
  filter,
  pageSize = 10,
}: DataTableProps<T>) {
  const [internalSearch, setInternalSearch] = useState("");
  const [page, setPage] = useState(1);
  const query = searchValue ?? internalSearch;
  const setQuery = onSearchChange ?? setInternalSearch;

  const filteredData = useMemo(() => {
    if (!query.trim()) return data;
    if (filter) return data.filter((item) => filter(item, query));
    const q = query.toLowerCase();
    return data.filter((item) =>
      Object.values(item as Record<string, unknown>).some((value) => String(value ?? "").toLowerCase().includes(q)),
    );
  }, [data, filter, query]);

  const totalPages = Math.max(1, Math.ceil(filteredData.length / pageSize));
  const paginated = filteredData.slice((page - 1) * pageSize, page * pageSize);

  return (
    <div className="surface-card overflow-hidden border border-slate-100">
      <div className="border-b border-slate-100 p-3 sm:p-4">
        <input
          value={query}
          onChange={(event) => {
            setQuery(event.target.value);
            setPage(1);
          }}
          placeholder={searchPlaceholder}
          className="h-10 w-full rounded-xl border border-slate-200 px-3 text-sm outline-none transition-colors focus:border-primary"
        />
      </div>

      <div className="space-y-3 p-3 lg:hidden">
        {paginated.length > 0 ? (
          paginated.map((item, index) => (
            <article key={index} className="rounded-xl border border-slate-100 bg-white p-3">
              <div className="space-y-2">
                {columns.map((column) => (
                  <div key={String(column.key)} className="space-y-1">
                    <p className="text-[11px] font-semibold uppercase tracking-wide text-slate-400">{column.label}</p>
                    <div className="text-sm text-slate-700">
                      {column.render
                        ? column.render(item)
                        : String((item as Record<string, unknown>)[String(column.key)] ?? "")}
                    </div>
                  </div>
                ))}
              </div>
            </article>
          ))
        ) : (
          <EmptyState title={emptyTitle} description={emptyDescription} />
        )}
      </div>

      <div className="hidden w-full overflow-x-auto lg:block">
        <UITable className="min-w-[720px]">
          <TableHeader>
            <TableRow className="bg-slate-50/70">
              {columns.map((column) => (
                <TableHead key={String(column.key)} className="h-11 px-3 text-xs font-semibold uppercase tracking-wide text-slate-500 md:px-4">
                  {column.label}
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody>
            {paginated.length > 0 ? (
              paginated.map((item, index) => (
                <TableRow key={index} className="hover:bg-slate-50/80">
                  {columns.map((column) => (
                    <TableCell key={String(column.key)} className="px-3 py-2 text-xs text-slate-700 md:px-4 md:py-3 md:text-sm">
                      {column.render ? column.render(item) : String((item as Record<string, unknown>)[String(column.key)] ?? "")}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={columns.length}>
                  <EmptyState title={emptyTitle} description={emptyDescription} />
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </UITable>
      </div>

      <div className="flex items-center justify-between border-t border-slate-100 px-3 py-2 text-xs text-slate-500 sm:px-4">
        <p>
          Jami: {filteredData.length} | Sahifa: {page}/{totalPages}
        </p>
        <div className="flex gap-2">
          <button
            type="button"
            className="rounded-lg border border-slate-200 px-2 py-1 disabled:opacity-50"
            disabled={page <= 1}
            onClick={() => setPage((value) => value - 1)}
          >
            Oldingi
          </button>
          <button
            type="button"
            className="rounded-lg border border-slate-200 px-2 py-1 disabled:opacity-50"
            disabled={page >= totalPages}
            onClick={() => setPage((value) => value + 1)}
          >
            Keyingi
          </button>
        </div>
      </div>
    </div>
  );
}
