package uc_installer.services.seed

// ============================================================================
// 导入后校验（任务 T048，design.md §4.10.5(5) E7、research-seed-identity.md §3.3 P4）。
//
// 对应 REQ-RNI-085~087；AC-208~209。
//
// 三条判据（**缺一即判定导入未完成**）：
//   ① 表总数与 `sql/seed/seed-manifest.json` 声明一致；
//   ② 身份列悬空引用 == 0（每个身份列逐个统计，不是"看着差不多"）；
//   ③ 超管菜单树非空——这一条最关键：裸 `psql -f` 会一路报成功但菜单是空的，
//      系统"能建表却不能用"。
//
// 菜单判据复刻 runtime `PermissionsService.getUserMenuTree`（:990~1050）的口径：
//   用户 → 角色 → role_has_permission（'*' / 'menu:*' 通配 或 精确 permission_name）
//   → permissions(type=1)。**不另立一套判定**（R-42 同族红线）。
// ============================================================================

import std.fs.{Path, exists}
import std.collection.ArrayList
import std.database.sql.Connection
import stdx.encoding.json.JsonObject
import uc_installer.services.{DbConn, readFileText}
import uc_installer.util.{jsonParse, asObject, jsonInt}

/// 校验结果。
public class VerifyReport {
    /// public schema 下的基表数。
    public var tableCount: Int64 = 0
    /// manifest 声明的表数；manifest 缺失或未声明时为 -1（此时跳过对账并记 note）。
    public var expectedTableCount: Int64 = -1
    /// 悬空身份引用总数（principal + agent 两个命名空间合计）。
    public var danglingRefs: Int64 = 0
    /// 逐「表.列」的悬空明细（非空即列出）。
    public var danglingDetails: ArrayList<String> = ArrayList<String>()
    /// 超管可见菜单项数（type=1 的 permissions）。
    public var menuCount: Int64 = 0
    /// 参与校验的超管 id（找不到则为空串）。
    public var superAdminId: String = ""
    public var notes: ArrayList<String> = ArrayList<String>()
    public var errors: ArrayList<String> = ArrayList<String>()

    public func ok(): Bool {
        return errors.isEmpty()
    }
}

/// 跑三条判据。
public func verifySeed(conn: DbConn, policy: ExportPolicy, manifestPath: Path): VerifyReport {
    let rep = VerifyReport()
    let dbOpt = try {
        Some(openSeedConn(conn))
    } catch (e: Exception) {
        rep.errors.add("无法连接数据库 ${conn.database}：${e.message}")
        None<Connection>
    }
    let db = match (dbOpt) {
        case Some(c) => c
        case None => return rep
    }
    try {
        runVerify(db, policy, manifestPath, rep)
    } finally {
        try {
            db.close()
        } catch (_: Exception) {
            ()
        }
    }
    return rep
}

func runVerify(db: Connection, policy: ExportPolicy, manifestPath: Path, rep: VerifyReport): Unit {
    // ---- ① 表总数 ----
    rep.tableCount = seedQueryInt(db,
        "SELECT count(*) FROM information_schema.tables " +
        "WHERE table_schema = 'public' AND table_type = 'BASE TABLE'")
    rep.expectedTableCount = declaredTableCount(manifestPath, rep)
    if (rep.expectedTableCount >= 0 && rep.tableCount != rep.expectedTableCount) {
        rep.errors.add("表总数 ${rep.tableCount} 与 seed-manifest 声明的 ${rep.expectedTableCount} 不一致（AC-208）")
    }

    // ---- ③ 超管菜单树（先定位超管，② 也用它）----
    rep.superAdminId = findSuperAdminId(db)
    if (rep.superAdminId.isEmpty()) {
        rep.errors.add("未找到超级管理员账号（uctoo_user 中无 user_type='human' 的有效行），" +
            "无法验证菜单树；请先完成 create-admin 再 seed apply")
    } else {
        rep.menuCount = seedQueryInt(db,
            "SELECT count(*) FROM \"public\".\"permissions\" p " +
            "WHERE p.deleted_at IS NULL AND p.type = 1 AND EXISTS (" +
            "  SELECT 1 FROM \"public\".\"user_has_roles\" ur " +
            "  JOIN \"public\".\"role_has_permission\" rp ON rp.role_id = ur.role_id " +
            "  WHERE ur.user_id = ?::uuid AND ur.deleted_at IS NULL " +
            "    AND (rp.permission_name = '*' OR rp.permission_name = 'menu:*' " +
            "         OR rp.permission_name = p.permission_name))",
            p1: rep.superAdminId)
        if (rep.menuCount == 0) {
            rep.errors.add("超管菜单树为空（AC-200/209）：表数达标但系统不可用，" +
                "检查 role_has_permission(超管角色,'*') 与 permissions 是否导入")
        }
    }

    // ---- ② 身份列悬空引用 ----
    scanDangling(db, policy, rep, policy.principalColumns, policy.principalTable, "principal")
    scanDangling(db, policy, rep, policy.agentColumns, policy.agentTable, "agent")
    if (rep.danglingRefs > 0) {
        rep.errors.add("悬空身份引用共 ${rep.danglingRefs} 处（判据要求 == 0）：" +
            "见 danglingDetails 逐条（AC-209）")
    }
}

/// 逐列扫描悬空引用：该列非空且取值不在目标主体表的主键集合里。
func scanDangling(db: Connection, policy: ExportPolicy, rep: VerifyReport,
                  cols: ArrayList<String>, refTable: String, ns: String): Unit {
    for (col in cols) {
        let tables = seedQueryList(db,
            "SELECT table_name FROM information_schema.columns " +
            "WHERE table_schema = 'public' AND column_name = ? ORDER BY table_name",
            p1: col)
        for (t in tables) {
            if (policy.syncDerived.contains(t)) {
                continue
            }
            // 只统计"长得像 uuid 却找不到主体"的行：身份列的取值形态必须与主体主键一致，
            // 否则同名的业务列（如存用户名的 user_id）会被误判成悬空。
            let n = seedQueryInt(db,
                "SELECT count(*) FROM \"public\".\"${t}\" " +
                "WHERE \"${col}\" IS NOT NULL " +
                "  AND \"${col}\"::text ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-" +
                "[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' " +
                "  AND \"${col}\"::text NOT IN (SELECT id::text FROM \"public\".\"${refTable}\")")
            if (n > 0) {
                rep.danglingRefs += n
                rep.danglingDetails.add("${t}.${col} = ${n}（${ns} 命名空间，参照 ${refTable}.id）")
            }
        }
    }
}

/// 定位超管：优先取已绑定超管角色的行；否则当且仅当 human 账号唯一时取它。
func findSuperAdminId(db: Connection): String {
    // 超管角色 id（持 '*'）：与 rbac.cj 的 RBAC_SUPER_ADMIN_ROLE_ID 同值，
    // 这里写成字面量——同包跨文件的顶层 let 初始化顺序不可靠，不跨文件引用。
    let bound = seedQuery(db,
        "SELECT u.id::text FROM uctoo_user u " +
        "JOIN user_has_roles r ON r.user_id = u.id AND r.deleted_at IS NULL " +
        "WHERE r.role_id = '2338cf7b-82b7-4cf6-b1ae-6a3ca79d683d'::uuid " +
        "  AND u.user_type = 'human' AND u.deleted_at IS NULL LIMIT 1")
    if (!bound.isEmpty()) {
        return bound
    }
    let n = seedQueryInt(db,
        "SELECT count(*) FROM uctoo_user WHERE user_type = 'human' AND deleted_at IS NULL")
    if (n != 1) {
        return ""
    }
    return seedQuery(db,
        "SELECT id::text FROM uctoo_user WHERE user_type = 'human' AND deleted_at IS NULL LIMIT 1")
}

/// 读 seed-manifest.json 里声明的表数；缺失/不可解析返回 -1 并记 note（不静默当 0）。
func declaredTableCount(manifestPath: Path, rep: VerifyReport): Int64 {
    if (!exists(manifestPath)) {
        rep.notes.add("未找到 ${manifestPath.toString()}：跳过表总数对账（先跑 db export 生成 manifest）")
        return -1
    }
    let text = readFileText(manifestPath)
    let rootOpt = match (jsonParse(text)) {
        case Some(v) => asObject(v)
        case None => None<JsonObject>
    }
    var n: Int64 = -1
    match (rootOpt) {
        case Some(o) => n = jsonInt(o, "structureTables", -1)
        case None => rep.notes.add("seed-manifest.json 不是合法 JSON 对象：跳过表总数对账")
    }
    if (n < 0) {
        rep.notes.add("seed-manifest.json 未声明 structureTables：跳过表总数对账（不静默按 0 处理）")
    }
    return n
}
