import { DataTable, type DataColumn } from "@/components/data-table";

type Column<T> = DataColumn<T>;

interface AppTableProps<T> {
  columns: Column<T>[];
  data: T[];
  emptyText?: string;
  searchPlaceholder?: string;
  pageSize?: number;
}

export function AppTable<T extends object>({
  columns,
  data,
  emptyText = "Ma'lumot mavjud emas.",
  searchPlaceholder,
  pageSize,
}: AppTableProps<T>) {
  return (
    <DataTable
      columns={columns}
      data={data}
      emptyTitle={emptyText}
      searchPlaceholder={searchPlaceholder}
      pageSize={pageSize ?? 10}
    />
  );
}
