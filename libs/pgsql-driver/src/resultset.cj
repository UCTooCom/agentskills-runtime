/*
 * resultset.cj —— 查询结果（QueryResult）与更新结果（UpdateResult）实现。
 *
 * 行数据以「每列可空文本」的二维结构缓存在内存中：None 表示 SQL NULL，
 * Some(text) 表示该列的 PostgreSQL 文本值，由 value.cj 按请求类型解码。
 */

package pgsql

import std.collection.*
import std.database.sql.*

/**
 * Select/查询语句的结果集。
 *
 * 游标初始位于首行之前，须先调用一次 [next] 才能读取第一行。
 */
public class PgQueryResult <: QueryResult {
    private let cols: Array<ColumnInfo>
    private let oids: Array<Int32>
    private let rows: ArrayList<Array<?String>>
    private var cursor: Int64 = -1
    private var closed: Bool = false

    public init(cols: Array<ColumnInfo>, oids: Array<Int32>, rows: ArrayList<Array<?String>>) {
        this.cols = cols
        this.oids = oids
        this.rows = rows
    }

    /** 结果集的列信息。 */
    public prop columnInfos: Array<ColumnInfo> {
        get() {
            cols
        }
    }

    /**
     * 向后移动一行。首次调用移动到第一行，返回是否存在该行。
     */
    public func next(): Bool {
        if (closed) {
            return false
        }
        if (cursor + 1 >= rows.size) {
            cursor = rows.size
            return false
        }
        cursor += 1
        return true
    }

    // std.database.sql 接口仍声明了基于已废弃 SqlDbType 的逐行读取（无默认实现，必须提供）。
    // 本驱动不支持该已废弃形态，请改用 next() 配合 get<T>/getOrNull<T>。
    @Deprecated["not supported; use next() with get<T>/getOrNull<T>"]
    public func next(_: Array<SqlDbType>): Bool {
        throw SqlException("SqlDbType-based next() is not supported; use next() with get<T>()")
    }

    /**
     * 读取当前行第 index 列并解码为类型 T。
     *
     * @throws SqlException 当索引越界、行未就绪或列值为 NULL 时。
     */
    public func get<T>(index: Int64): T {
        let raw = rawAt(index)
        match (raw) {
            case Some(text) => return decodeColumn<T>(text, oids[index])
            case None => throw SqlException("column ${index} is SQL NULL; use getOrNull<T> instead")
        }
    }

    /**
     * 读取当前行第 index 列并解码为类型 T，列值为 NULL 时返回 None。
     */
    public func getOrNull<T>(index: Int64): ?T {
        let raw = rawAt(index)
        match (raw) {
            case Some(text) => return Some(decodeColumn<T>(text, oids[index]))
            case None => return None
        }
    }

    // 取出当前行指定列的原始文本，并做就绪/越界校验。
    private func rawAt(index: Int64): ?String {
        if (closed) {
            throw SqlException("result set is closed")
        }
        if (cursor < 0 || cursor >= rows.size) {
            throw SqlException("no current row; call next() first")
        }
        if (index < 0 || index >= cols.size) {
            throw SqlException("column index ${index} out of range [0, ${cols.size})")
        }
        return rows[cursor][index]
    }

    /** 释放结果集（仅清理内存状态，连接本身不在此关闭）。 */
    public func close(): Unit {
        closed = true
    }

    /** 结果集是否已关闭。 */
    public func isClosed(): Bool {
        return closed
    }
}

/**
 * Insert/Update/Delete 语句的执行结果。
 */
public class PgUpdateResult <: UpdateResult {
    private let affected: Int64
    private let insertId: Int64

    public init(affected: Int64, insertId: Int64) {
        this.affected = affected
        this.insertId = insertId
    }

    /**
     * 自动生成的最后一个 row id。PostgreSQL 现已不再返回 OID，故恒为 0；
     * 若需取得自增主键，请使用 `INSERT ... RETURNING id` 并以 query() 读取。
     */
    public prop lastInsertId: Int64 {
        get() {
            insertId
        }
    }

    /** 受影响的行数。 */
    public prop rowCount: Int64 {
        get() {
            affected
        }
    }
}
