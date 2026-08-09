"""Neon (toza Postgres) uchun Supabase-client mos keluvchi shim.

Supabase PostgREST query-builder API'sining loyihada ishlatilgan qismini
(`.table().select().eq()...execute()` va `.rpc()`) taqlid qiladi, lekin
so'rovlarni to'g'ridan-to'g'ri Neon Postgres'ga psycopg orqali yuboradi.

Maqsad: 234 ta mavjud chaqiruvni o'zgartirmasdan Supabase'dan Neon'ga o'tish.
Qo'llab-quvvatlanadigan operatorlar (kodda ishlatilganlari):
  table, select, insert, update, upsert(on_conflict), delete,
  eq, in_, gte, is_, not_.is_, order(desc), limit, execute, rpc.
"""

from __future__ import annotations

from datetime import date, datetime, time
from decimal import Decimal
from typing import Any
from uuid import UUID

from psycopg import sql
from psycopg.rows import dict_row
from psycopg.types.json import Json
from psycopg_pool import ConnectionPool


def _adapt_param(value: Any) -> Any:
    """dict qiymatlarni jsonb ustunlar uchun to'g'ri adaptatsiya qiladi.
    psycopg dict'ni o'zi qabul qilmaydi — Json() bilan o'raymiz (audit_logs.metadata kabi).
    list'ni o'ramaymiz — psycopg uni Postgres array'ga o'zi aylantiradi."""
    if isinstance(value, dict):
        return Json(value)
    return value


def _jsonify(value: Any) -> Any:
    """psycopg native turlarini Supabase(JSON) kabi turlarga aylantiradi.

    Kod Supabase JSON javobiga moslangan (uuid/sana — string). psycopg esa
    UUID/datetime/Decimal obyektlarini qaytaradi — ularni string/float qilamiz.
    """
    if isinstance(value, UUID):
        return str(value)
    if isinstance(value, (datetime, date, time)):
        return value.isoformat()
    if isinstance(value, Decimal):
        return float(value)
    return value


def _jsonify_row(row: dict[str, Any]) -> dict[str, Any]:
    return {k: _jsonify(v) for k, v in row.items()}


class _Result:
    """Supabase `.execute()` javobiga mos: `.data` (ro'yxat) va `.count`."""

    def __init__(self, data: list[dict[str, Any]], count: int | None = None):
        self.data = data
        self.count = count if count is not None else len(data)


class _NotProxy:
    """`.not_.is_(col, val)` uchun — keyingi filtrni inkor qiladi."""

    def __init__(self, qb: "QueryBuilder"):
        self._qb = qb

    def is_(self, column: str, value: Any) -> "QueryBuilder":
        return self._qb._add_is(column, value, negate=True)


class QueryBuilder:
    def __init__(self, pool: ConnectionPool, table: str, schema: str = "public"):
        self._pool = pool
        self._schema = schema
        self._table = table
        self._op = "select"
        self._select_cols = "*"
        self._count: str | None = None
        self._payload: Any = None
        self._on_conflict: str | None = None
        self._filters: list[tuple[str, str, Any]] = []  # (column, op, value)
        self._order: list[tuple[str, bool]] = []  # (column, desc)
        self._limit: int | None = None

    # --- operatsiya turlari -------------------------------------------------
    def select(self, columns: str = "*", count: str | None = None) -> "QueryBuilder":
        self._op = "select"
        self._select_cols = columns or "*"
        self._count = count
        return self

    def insert(self, data: Any) -> "QueryBuilder":
        self._op = "insert"
        self._payload = data
        return self

    def update(self, data: dict[str, Any]) -> "QueryBuilder":
        self._op = "update"
        self._payload = data
        return self

    def upsert(self, data: Any, on_conflict: str | None = None) -> "QueryBuilder":
        self._op = "upsert"
        self._payload = data
        self._on_conflict = on_conflict
        return self

    def delete(self) -> "QueryBuilder":
        self._op = "delete"
        return self

    # --- filtrlar -----------------------------------------------------------
    def eq(self, column: str, value: Any) -> "QueryBuilder":
        self._filters.append((column, "eq", value))
        return self

    def in_(self, column: str, values: Any) -> "QueryBuilder":
        self._filters.append((column, "in", list(values)))
        return self

    def gte(self, column: str, value: Any) -> "QueryBuilder":
        self._filters.append((column, "gte", value))
        return self

    def is_(self, column: str, value: Any) -> "QueryBuilder":
        return self._add_is(column, value, negate=False)

    def _add_is(self, column: str, value: Any, *, negate: bool) -> "QueryBuilder":
        self._filters.append((column, "is_not" if negate else "is", value))
        return self

    @property
    def not_(self) -> _NotProxy:
        return _NotProxy(self)

    # --- tartib / limit -----------------------------------------------------
    def order(self, column: str, desc: bool = False) -> "QueryBuilder":
        self._order.append((column, desc))
        return self

    def limit(self, count: int) -> "QueryBuilder":
        self._limit = int(count)
        return self

    # --- SQL yasash ---------------------------------------------------------
    def _table_sql(self) -> sql.Composed:
        return sql.SQL("{}.{}").format(
            sql.Identifier(self._schema), sql.Identifier(self._table)
        )

    def _where_sql(self) -> tuple[sql.Composable, list[Any]]:
        if not self._filters:
            return sql.SQL(""), []
        clauses: list[sql.Composable] = []
        params: list[Any] = []
        for column, op, value in self._filters:
            col = sql.Identifier(column)
            if op == "eq":
                clauses.append(sql.SQL("{} = %s").format(col))
                params.append(value)
            elif op == "gte":
                clauses.append(sql.SQL("{} >= %s").format(col))
                params.append(value)
            elif op == "in":
                if not value:
                    clauses.append(sql.SQL("false"))
                else:
                    placeholders = sql.SQL(", ").join(sql.Placeholder() * len(value))
                    clauses.append(sql.SQL("{} IN ({})").format(col, placeholders))
                    params.extend(value)
            elif op in ("is", "is_not"):
                not_kw = sql.SQL(" NOT") if op == "is_not" else sql.SQL("")
                if value is None:
                    clauses.append(sql.SQL("{} IS{} NULL").format(col, not_kw))
                elif isinstance(value, bool):
                    truth = sql.SQL("TRUE") if value else sql.SQL("FALSE")
                    clauses.append(sql.SQL("{} IS{} {}").format(col, not_kw, truth))
                else:
                    clauses.append(sql.SQL("{} IS{} %s").format(col, not_kw))
                    params.append(value)
        where = sql.SQL(" WHERE ") + sql.SQL(" AND ").join(clauses)
        return where, params

    def _select_cols_sql(self) -> sql.Composable:
        cols = self._select_cols.strip()
        if cols == "*" or cols == "":
            return sql.SQL("*")
        parts = [c.strip() for c in cols.split(",") if c.strip()]
        out: list[sql.Composable] = []
        for p in parts:
            if p == "*":
                out.append(sql.SQL("*"))
            elif "(" in p or "!" in p:
                # PostgREST "embed" (masalan book_categories(name), notifications!inner(...))
                # — bu SQL emas; o'tkazib yuboramiz (servis kerakli ma'lumotni alohida oladi).
                continue
            else:
                out.append(sql.Identifier(p))
        return sql.SQL(", ").join(out) if out else sql.SQL("*")

    def _order_limit_sql(self) -> sql.Composable:
        out = sql.SQL("")
        if self._order:
            items = [
                sql.SQL("{} {}").format(
                    sql.Identifier(c), sql.SQL("DESC") if d else sql.SQL("ASC")
                )
                for c, d in self._order
            ]
            out += sql.SQL(" ORDER BY ") + sql.SQL(", ").join(items)
        if self._limit is not None:
            out += sql.SQL(" LIMIT {}").format(sql.Literal(self._limit))
        return out

    def _rows(self, payload: Any) -> list[dict[str, Any]]:
        if payload is None:
            return []
        return payload if isinstance(payload, list) else [payload]

    def _build(self) -> tuple[sql.Composable, list[Any]]:
        table = self._table_sql()
        if self._op == "select":
            where, params = self._where_sql()
            query = (
                sql.SQL("SELECT ")
                + self._select_cols_sql()
                + sql.SQL(" FROM ")
                + table
                + where
                + self._order_limit_sql()
            )
            return query, params

        if self._op == "delete":
            where, params = self._where_sql()
            query = sql.SQL("DELETE FROM ") + table + where + sql.SQL(" RETURNING *")
            return query, params

        if self._op == "update":
            assert isinstance(self._payload, dict)
            set_items = [
                sql.SQL("{} = %s").format(sql.Identifier(k)) for k in self._payload
            ]
            set_params = [_adapt_param(v) for v in self._payload.values()]
            where, where_params = self._where_sql()
            query = (
                sql.SQL("UPDATE ")
                + table
                + sql.SQL(" SET ")
                + sql.SQL(", ").join(set_items)
                + where
                + sql.SQL(" RETURNING *")
            )
            return query, set_params + where_params

        if self._op in ("insert", "upsert"):
            rows = self._rows(self._payload)
            if not rows:
                return sql.SQL("SELECT 1 WHERE false"), []
            columns = list(rows[0].keys())
            col_sql = sql.SQL(", ").join(sql.Identifier(c) for c in columns)
            values_sql: list[sql.Composable] = []
            params: list[Any] = []
            for row in rows:
                placeholders = sql.SQL(", ").join(sql.Placeholder() * len(columns))
                values_sql.append(sql.SQL("({})").format(placeholders))
                params.extend(_adapt_param(row.get(c)) for c in columns)
            query = (
                sql.SQL("INSERT INTO ")
                + table
                + sql.SQL(" ({}) VALUES ").format(col_sql)
                + sql.SQL(", ").join(values_sql)
            )
            if self._op == "upsert":
                conflict_cols = [
                    c.strip()
                    for c in (self._on_conflict or "").split(",")
                    if c.strip()
                ]
                if conflict_cols:
                    target = sql.SQL(", ").join(
                        sql.Identifier(c) for c in conflict_cols
                    )
                    update_cols = [c for c in columns if c not in conflict_cols]
                    if update_cols:
                        set_sql = sql.SQL(", ").join(
                            sql.SQL("{} = EXCLUDED.{}").format(
                                sql.Identifier(c), sql.Identifier(c)
                            )
                            for c in update_cols
                        )
                        query += sql.SQL(" ON CONFLICT ({}) DO UPDATE SET ").format(
                            target
                        ) + set_sql
                    else:
                        query += sql.SQL(" ON CONFLICT ({}) DO NOTHING").format(target)
            query += sql.SQL(" RETURNING *")
            return query, params

        raise ValueError(f"Unsupported op: {self._op}")

    def _build_count(self) -> tuple[sql.Composable, list[Any]]:
        where, params = self._where_sql()
        query = (
            sql.SQL("SELECT count(*) AS n FROM ") + self._table_sql() + where
        )
        return query, params

    def execute(self) -> _Result:
        # count="exact" — PostgREST kabi jami mos qatorlar sonini qaytaramiz.
        if self._op == "select" and self._count:
            query, params = self._build_count()
            with self._pool.connection() as conn:
                with conn.cursor(row_factory=dict_row) as cur:
                    cur.execute(query, params)
                    row = cur.fetchone()
            return _Result([], count=int(row["n"]) if row else 0)

        query, params = self._build()
        with self._pool.connection() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(query, params)
                try:
                    rows = cur.fetchall()
                except Exception:
                    rows = []
        return _Result([_jsonify_row(r) for r in rows])


class RPCBuilder:
    def __init__(self, pool: ConnectionPool, fn: str, params: dict[str, Any] | None):
        self._pool = pool
        self._fn = fn
        self._params = params or {}

    def execute(self) -> _Result:
        keys = list(self._params.keys())
        named = sql.SQL(", ").join(
            sql.SQL("{} => %s").format(sql.Identifier(k)) for k in keys
        )
        query = sql.SQL("SELECT * FROM {}.{}({})").format(
            sql.Identifier("public"), sql.Identifier(self._fn), named
        )
        values = [self._params[k] for k in keys]
        with self._pool.connection() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(query, values)
                rows = cur.fetchall()
        return _Result([_jsonify_row(r) for r in rows])


class NeonClient:
    """Supabase `Client`'ga o'rnini bosuvchi minimal API."""

    def __init__(self, pool: ConnectionPool):
        self._pool = pool

    def table(self, name: str) -> QueryBuilder:
        return QueryBuilder(self._pool, name)

    def rpc(self, fn: str, params: dict[str, Any] | None = None) -> RPCBuilder:
        return RPCBuilder(self._pool, fn, params)

    def execute_sql(self, query: str, params: list[Any] | None = None) -> list[dict[str, Any]]:
        """Xom SQL bajaradi (DDL yoki maxsus so'rovlar uchun). SELECT bo'lsa qatorlarni,
        aks holda bo'sh ro'yxat qaytaradi. Shim query-builder yetmagan joyda ishlatiladi."""
        with self._pool.connection() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(query, params or [])
                try:
                    rows = cur.fetchall()
                except Exception:
                    rows = []
        return [_jsonify_row(r) for r in rows]


# Mavjud servislar `from supabase import Client` o'rniga shu tur bilan ishlaydi
# (type-hint mos-kelishi uchun).
Client = NeonClient


def create_neon_client(database_url: str) -> NeonClient:
    pool = ConnectionPool(
        conninfo=database_url,
        min_size=1,
        max_size=10,
        kwargs={"autocommit": True},
        open=True,
    )
    return NeonClient(pool)
