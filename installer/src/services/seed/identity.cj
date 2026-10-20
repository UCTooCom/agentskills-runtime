package uc_installer.services.seed

// ============================================================================
// 身份匿名化与孤儿策略（任务 T043，design.md §4.10.5(3)/(5) E4）。
//
// 对应 REQ-RNI-078~087 / 091；AC-188~219、244。
//
// 双命名空间占位符：
//   {{principal:<ref>}} → uctoo_user.id（人类超管 / 主 agent 账号）
//   {{agent:<ref>}}     → agents.id（智能体实体）
//
// 红线：agent_id 列指向 agents.id，不是 uctoo_user.id（design §4.10.5(3)）。
//
// 判定必须双条件（列名属于声明集合 且 取值命中主体清单）——非身份 uuid 极多
// （permissions.parent_id 2190、db_info.id 2913），单条件会误伤。故：值既不在
// 已知主体集也不在孤儿覆盖集、且长得像 uuid 时才算"孤儿"，其余（NULL / 字面量如
// 'admin' / 普通业务值）一律按"非身份引用"原样保留。
// ============================================================================

import pgsql.{PgDatasource, registerDriver}
import std.database.sql.{Connection, Statement, QueryResult}
import std.collection.{ArrayList, HashMap}

/// 超管角色 id（持有 `*` 权限）。来自 RBAC 基线，与 T047 A3 同款常量。
/// 用于在源库里定位"作者环境"的超管账号 uuid（安装目标环境会另建一个超管）。
let SUPER_ADMIN_ROLE_ID = "2338cf7b-82b7-4cf6-b1ae-6a3ca79d683d"

/// 匿名化结果状态。
public enum AnonymizeStatus {
    /// 非身份引用或非身份列 → 原值保留。
    | Unchanged
    /// 命中主体/孤儿覆盖 → 已替换为占位符。
    | Replaced
    /// 孤儿且默认策略 fail → 导出应失败（caller 据此报错）。
    | OrphanFail
    /// 孤儿且默认策略 drop → 整行跳过。
    | DropRow
}

/// 单单元格匿名化结果。
public struct AnonymizeOutcome {
    public let value: String
    public let status: AnonymizeStatus

    public init(value: String, status: AnonymizeStatus) {
        this.value = value
        this.status = status
    }
}

/// 身份解析上下文：源库里"主体 uuid → 占位符"的映射 + 孤儿策略。
public struct IdentityContext {
    /// 源库主体 uuid → `{{principal:<ref>}}`。
    public let principalByUuid: HashMap<String, String>
    /// 源库主 agent uuid → `{{agent:main}}`。
    public let agentByUuid: HashMap<String, String>
    /// 孤儿覆盖：uuid → `{{principal:<to>}}`（design §4.10.5(5) entity.creator 的 test1）。
    public let orphanByUuid: HashMap<String, String>
    public let principalColumns: ArrayList<String>
    public let agentColumns: ArrayList<String>
    public let orphanDefault: OrphanPolicy

    // struct 字段是 let（不可变），三份策略数据必须经构造器注入，
    // 不能再走「先空构造再赋值」（仓颉报 cannot assign to immutable value）。
    public init(principalColumns!: ArrayList<String> = ArrayList<String>(),
                agentColumns!: ArrayList<String> = ArrayList<String>(),
                orphanDefault!: OrphanPolicy = OrphanPolicy.Fail) {
        this.principalByUuid = HashMap<String, String>()
        this.agentByUuid = HashMap<String, String>()
        this.orphanByUuid = HashMap<String, String>()
        this.principalColumns = principalColumns
        this.agentColumns = agentColumns
        this.orphanDefault = orphanDefault
    }
}

/// 连接源库，把策略里声明的主体解析成"源 uuid → 占位符"映射。
///
/// 解析口径（与 design §4.10.5(2)/(3) 一致）：
///   - 主体 source=username → 按其 username 在主体表查 id；
///   - 主体 kind=super_admin → 按其持有的超管角色查 id（源环境作者自己的超管）；
///   - agent 主实体 → agents 表里 agent_type='MAIN' 的 id。
public func resolveIdentities(conn: Connection, policy: ExportPolicy): IdentityContext {
    let ctx = IdentityContext(principalColumns: policy.principalColumns,
        agentColumns: policy.agentColumns, orphanDefault: policy.orphanDefault)

    for (p in policy.principals) {
        var uuid = ""
        if (p.source == "username" && !p.username.isEmpty()) {
            uuid = queryCell(conn,
                "SELECT id FROM \"${policy.principalTable}\" WHERE username = ? LIMIT 1", param: p.username)
        } else if (p.kind == "super_admin") {
            uuid = queryCell(conn,
                "SELECT u.id FROM \"${policy.principalTable}\" u " +
                "JOIN user_has_roles r ON r.user_id = u.id " +
                "WHERE r.role_id = ? LIMIT 1", param: SUPER_ADMIN_ROLE_ID)
        }
        if (!uuid.isEmpty()) {
            ctx.principalByUuid.add(uuid, "{{principal:${p.ref}}}")
        }
    }

    let agentUuid = queryCell(conn,
        "SELECT id FROM \"${policy.agentTable}\" WHERE agent_type = 'MAIN' LIMIT 1")
    if (!agentUuid.isEmpty()) {
        ctx.agentByUuid.add(agentUuid, "{{agent:main}}")
    }

    for (ov in policy.orphanOverrides) {
        ctx.orphanByUuid.add(ov.uuid, "{{principal:${ov.to}}}")
    }
    return ctx
}

/// 对单个单元格做身份匿名化。
///
/// 约定：调用方已把 NULL 处理为"不进入本函数"（NULL 不是身份引用）。
/// `value` 为数据库原始文本。
public func anonymizeCell(ctx: IdentityContext, column: String, value: String): AnonymizeOutcome {
    let isPrincipalCol = ctx.principalColumns.contains(column)
    let isAgentCol = ctx.agentColumns.contains(column)
    if (!isPrincipalCol && !isAgentCol) {
        return AnonymizeOutcome(value, AnonymizeStatus.Unchanged)
    }
    if (value.isEmpty()) {
        return AnonymizeOutcome(value, AnonymizeStatus.Unchanged)
    }

    match (ctx.principalByUuid.get(value)) {
        case Some(ph) => return AnonymizeOutcome(ph, AnonymizeStatus.Replaced)
        case None => ()
    }
    match (ctx.agentByUuid.get(value)) {
        case Some(ph) => return AnonymizeOutcome(ph, AnonymizeStatus.Replaced)
        case None => ()
    }
    match (ctx.orphanByUuid.get(value)) {
        case Some(ph) => return AnonymizeOutcome(ph, AnonymizeStatus.Replaced)
        case None => ()
    }

    // 不在已知主体集，且长得像 uuid → 孤儿。
    if (looksLikeUuid(value)) {
        match (ctx.orphanDefault) {
            case OrphanPolicy.Fail => return AnonymizeOutcome(value, AnonymizeStatus.OrphanFail)
            case OrphanPolicy.Drop => return AnonymizeOutcome(value, AnonymizeStatus.DropRow)
            case OrphanPolicy.MapTo =>
                // 默认 map-to：归位到超管（与导出侧孤儿覆盖的惯用目标一致）。
                return AnonymizeOutcome("{{principal:super_admin}}", AnonymizeStatus.Replaced)
        }
    }
    // 非 uuid（如字面量 'admin' / 'system'）→ 不是身份引用，原样保留。
    return AnonymizeOutcome(value, AnonymizeStatus.Unchanged)
}

/// 形如 `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` 的 uuid（8-4-4-4-12）。
public func looksLikeUuid(s: String): Bool {
    let r = s.toRuneArray()
    if (r.size != 36) {
        return false
    }
    let expectDash = [8, 13, 18, 23]
    for (i in 0..36) {
        if (contains(expectDash, i)) {
            if (r[i] != r'-') { return false }
        } else {
            if (!isHex(r[i])) { return false }
        }
    }
    return true
}

private func isHex(r: Rune): Bool {
    return (r >= r'0' && r <= r'9') || (r >= r'a' && r <= r'f') || (r >= r'A' && r <= r'F')
}

private func contains(arr: Array<Int64>, v: Int64): Bool {
    for (x in arr) {
        if (x == v) { return true }
    }
    return false
}

/// 跑一条返回单值（首行首列）的查询；无结果返回空串。
/// `param` 为命名参数（带默认空串）：带 `?` 占位符的语句传参，否则省略。
private func queryCell(conn: Connection, sql: String, param!: String = ""): String {
    try {
        let stmt = conn.prepareStatement(sql)
        if (!param.isEmpty()) {
            stmt.set<String>(0, param)
        }
        let rs = stmt.query()
        if (rs.next()) {
            return match (rs.getOrNull<String>(0)) { case Some(v) => v; case None => "" }
        }
        return ""
    } catch (_: Exception) {
        return ""
    }
}
