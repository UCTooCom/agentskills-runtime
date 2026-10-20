package uc_installer.services.seed

// ============================================================================
// 账号二元组与 RBAC 补种（任务 T047，design.md §4.10.5(2)、
// research-seed-identity.md §3.3 的 P0 / P3）。
//
// 对应 REQ-RNI-089 / 090；AC-210~216。
//
// 落库顺序（**不可颠倒**）：
//
//   A1 uctoo_user      超管（user_type='human'）              ← create-admin 真路径
//   A2 uctoo_user      主 agent 账号（user_type='agent'，password=不可登录随机串）
//   A3 user_has_roles  超管 → 超管角色（2338cf7b-…，持 '*'）
//   A4 user_has_roles  主 agent → agents 角色（a686ff1f-…）
//   A5 user_has_group  主 agent → user_group(code='agents')
//   A6 agents          MainAgent 实体（agent_type='MAIN'，status=1，user_id=A2.id）
//      + 回填 A2.agent_id = A6.id
//
// A6 需要 A2 的 id，A2.agent_id 需要 A6 的 id ⇒ **A2 → A6 → UPDATE A2.agent_id**。
//
// 红线：
//   - **超管不由本模块创建**：AC-198 要求以「超管已创建」为前提，缺失即判定失败并
//     给出修复建议，绝不自建替代账号蒙混过关；
//   - 主 agent 口令取**数据库侧随机值**再走 bcrypt（`$2a$` 归一），绝不硬编码常量
//     （AC-204 / AC-211），明文只在报告里一次性展示；
//   - 绑定与授权**只增不删**（AC-199）：不存在才 INSERT，绝不 UPDATE 既有行；
//   - 全流程仅两次 UPDATE（回填 `uctoo_user.agent_id`、必要时回填 `agents.user_id`），
//     且只作用于安装器自己生成的行——业务数据行的身份重绑定仍是字符串级替换（T046）。
// ============================================================================

import pgsql.{PgDatasource, registerDriver}
import std.database.sql.{Connection, Statement}
import std.collection.{ArrayList, HashMap}
import std.convert.Parsable
import uc_installer.services.{DbConn, hashPassword}

/// 超管角色 id（持有 `*` 通配权限）。与 identity.cj 的 SUPER_ADMIN_ROLE_ID 同值，
/// 这里另起名：**同包顶层 `let` 重名即重复声明**，且跨文件初始化顺序不可靠。
let RBAC_SUPER_ADMIN_ROLE_ID = "2338cf7b-82b7-4cf6-b1ae-6a3ca79d683d"
/// 智能体角色 id（runtime `AipIdentityService:20` AGENTS_ROLE_ID）。
let RBAC_AGENTS_ROLE_ID = "a686ff1f-7fb4-48df-8609-2b2d5267c682"
/// 智能体用户组 code（runtime `AipIdentityService:21` AGENTS_GROUP_CODE）。
let RBAC_AGENTS_GROUP_CODE = "agents"
/// 策略未声明主 agent 主体时的兜底登录名。
let RBAC_DEFAULT_AGENT_USERNAME = "mainagent"

// ===================== 数据模型 =====================

/// 单个建号 / 补种动作的结果（供报告逐条可见，**绝不静默**）。
public struct IdentityStep {
    /// A1~A6 / P3 / AC-214。
    public let code: String
    /// `created` / `reused` / `verified`。
    public let action: String
    public let detail: String

    public init(code!: String, action!: String, detail!: String) {
        this.code = code
        this.action = action
        this.detail = detail
    }
}

/// 身份建立结果。
public class IdentitySetup {
    /// 超管 id（A1，来自 create-admin 落库行）。
    public var superAdminId: String = ""
    /// 主 agent 账号 id（A2）。
    public var agentUserId: String = ""
    /// 主 agent 实体 id（A6，`agents.id`）。
    public var agentId: String = ""
    /// 主 agent 登录名。
    public var agentUsername: String = ""
    /// 主 agent 的**随机**初始口令明文。仅新建时非空，供报告一次性展示（AC-204）；
    /// 库里存的是它的 bcrypt 散列，且 agent 账号本来就不支持口令登录。
    public var agentPassword: String = ""
    public let steps: ArrayList<IdentityStep> = ArrayList<IdentityStep>()
    public let errors: ArrayList<String> = ArrayList<String>()

    /// 三个 id 齐备且无错误。
    public func ok(): Bool {
        return errors.isEmpty() && !superAdminId.isEmpty() && !agentUserId.isEmpty() && !agentId.isEmpty()
    }
}

// ===================== 对外入口 =====================

/// 建立（或复用）初始身份二元组并完成 RBAC 补种。
///
/// 幂等：重复执行只产生 `reused` 步骤，不会产生第二个超管、第二个主 agent
/// 或重复绑定行（AC-197）。
public func ensureSeedIdentities(conn: DbConn, policy: ExportPolicy): IdentitySetup {
    let out = IdentitySetup()
    let dbOpt = try {
        Some(openSeedConn(conn))
    } catch (e: Exception) {
        out.errors.add("无法连接数据库 ${conn.database}：${e.message}")
        None<Connection>
    }
    let db = match (dbOpt) {
        case Some(c) => c
        case None => return out
    }
    try {
        runIdentitySteps(db, policy, out)
    } finally {
        try {
            db.close()
        } catch (_: Exception) {
            ()
        }
    }
    return out
}

// ===================== 步骤编排 =====================

func runIdentitySteps(db: Connection, policy: ExportPolicy, out: IdentitySetup): Unit {
    // ---- A1 超管：复用，绝不自建（AC-198）----
    let superId = findSuperAdmin(db, out)
    if (superId.isEmpty()) {
        return
    }
    out.superAdminId = superId

    // ---- P3 超管角色持 '*' 通配授权（AC-199，只增不删）----
    ensureWildcardPermission(db, out)

    // ---- A3 超管 → 超管角色 ----
    ensureUserRole(db, out, superId, RBAC_SUPER_ADMIN_ROLE_ID, superId, "A3", "超管 → 超管角色")

    // ---- A2 主 agent 账号 ----
    let username = agentUsernameOf(policy)
    out.agentUsername = username
    if (!ensureAgentUser(db, out, username)) {
        return
    }

    // ---- A6 主 agent 实体 + 回填 A2.agent_id ----
    if (!ensureMainAgent(db, out)) {
        return
    }

    // ---- A4 / A5 ----
    ensureUserRole(db, out, out.agentUserId, RBAC_AGENTS_ROLE_ID, superId, "A4", "主 agent → agents 角色")
    ensureGroupBinding(db, out)

    // ---- AC-214 双向指针复核 ----
    checkDualBinding(db, out)
}

/// A1：定位超管。优先取「已绑定超管角色」的行；否则当且仅当 human 账号唯一时取它。
func findSuperAdmin(db: Connection, out: IdentitySetup): String {
    let bound = seedQuery(db,
        "SELECT u.id::text FROM uctoo_user u " +
        "JOIN user_has_roles r ON r.user_id = u.id AND r.deleted_at IS NULL " +
        "WHERE r.role_id = ?::uuid AND u.user_type = 'human' AND u.deleted_at IS NULL LIMIT 1",
        p1: RBAC_SUPER_ADMIN_ROLE_ID)
    if (!bound.isEmpty()) {
        out.steps.add(IdentityStep(code: "A1", action: "reused",
            detail: "超管 ${bound}（已绑定超管角色）"))
        return bound
    }
    let n = seedQueryInt(db,
        "SELECT count(*) FROM uctoo_user WHERE user_type = 'human' AND deleted_at IS NULL")
    if (n == 0) {
        out.errors.add("未找到超级管理员账号：uctoo_user 中没有 user_type='human' 的有效账号")
        out.errors.add("修复建议：先完成安装流程的 create-admin（引导页建号）再执行 seed apply；" +
            "导入环节不得自行创建替代账号（AC-198）")
        return ""
    }
    if (n > 1) {
        out.errors.add("uctoo_user 中存在 ${n} 个 user_type='human' 账号且均未绑定超管角色，无法确定超管（AC-198）")
        out.errors.add("修复建议：为超管账号补一条 user_has_roles(role_id=${RBAC_SUPER_ADMIN_ROLE_ID}) 后重跑")
        return ""
    }
    let only = seedQuery(db,
        "SELECT id::text FROM uctoo_user WHERE user_type = 'human' AND deleted_at IS NULL LIMIT 1")
    out.steps.add(IdentityStep(code: "A1", action: "reused",
        detail: "超管 ${only}（create-admin 落库行，尚未绑定超管角色；A3 将补种）"))
    return only
}

/// 主 agent 账号的登录名：取策略里第一条非 super_admin 且声明了 username 的主体。
func agentUsernameOf(policy: ExportPolicy): String {
    for (p in policy.principals) {
        if (p.ref == "super_admin") {
            continue
        }
        if (!p.username.isEmpty()) {
            return p.username
        }
    }
    return RBAC_DEFAULT_AGENT_USERNAME
}

/// A2：建立（或复用）主 agent 账号。
func ensureAgentUser(db: Connection, out: IdentitySetup, username: String): Bool {
    let existing = seedQuery(db,
        "SELECT id::text FROM uctoo_user WHERE username = ? AND deleted_at IS NULL LIMIT 1",
        p1: username)
    if (!existing.isEmpty()) {
        let ut = seedQuery(db,
            "SELECT user_type FROM uctoo_user WHERE id = ?::uuid", p1: existing)
        if (ut != "agent") {
            out.errors.add("A2 复用失败：账号 ${username} 的 user_type='${ut}'（期望 'agent'），" +
                "agent 自动登录的账号类型前置不成立（AC-211/213）")
            return false
        }
        out.agentUserId = existing
        out.steps.add(IdentityStep(code: "A2", action: "reused",
            detail: "主 agent 账号 ${username}（id=${existing}）"))
        return true
    }
    let pwd = randomToken(db)
    if (pwd.isEmpty()) {
        out.errors.add("A2 失败：无法生成随机口令（数据库侧随机源不可用）")
        return false
    }
    let hashed = hashPassword(pwd)
    let newId = seedQuery(db,
        "INSERT INTO uctoo_user (name, username, email, password, user_type, status, auth_provider, " +
        "created_at, updated_at, last_login_time) " +
        "VALUES (?, ?, ?, ?, 'agent', 1, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) " +
        "RETURNING id::text",
        p1: username, p2: username, p3: "${username}@agents.internal", p4: hashed)
    if (newId.isEmpty()) {
        out.errors.add("A2 失败：主 agent 账号写入 uctoo_user 未返回 id")
        return false
    }
    out.agentUserId = newId
    out.agentPassword = pwd
    out.steps.add(IdentityStep(code: "A2", action: "created",
        detail: "主 agent 账号 ${username}（id=${newId}，user_type='agent'，随机不可登录口令）"))
    return true
}

/// A6：建立（或复用）MAIN 实体，随后回填 A2.agent_id。
func ensureMainAgent(db: Connection, out: IdentitySetup): Bool {
    let existing = seedQuery(db,
        "SELECT id::text FROM agents WHERE agent_type = 'MAIN' AND deleted_at IS NULL ORDER BY created_at LIMIT 1")
    if (!existing.isEmpty()) {
        let uid = seedQuery(db,
            "SELECT user_id::text FROM agents WHERE id = ?::uuid", p1: existing)
        if (uid.isEmpty()) {
            let err = seedExec(db,
                "UPDATE agents SET user_id = ?::uuid, updated_at = CURRENT_TIMESTAMP WHERE id = ?::uuid",
                p1: out.agentUserId, p2: existing)
            if (!err.isEmpty()) {
                out.errors.add("A6 回填 agents.user_id 失败：${err}")
                return false
            }
            out.steps.add(IdentityStep(code: "A6", action: "reused",
                detail: "主 agent 实体 ${existing}（已回填 user_id=${out.agentUserId}）"))
        } else if (uid != out.agentUserId) {
            out.errors.add("A6 复用冲突：MAIN 实体 ${existing} 的 user_id=${uid} " +
                "与主 agent 账号 ${out.agentUserId} 不一致（AC-214）")
            return false
        } else {
            out.steps.add(IdentityStep(code: "A6", action: "reused",
                detail: "主 agent 实体 ${existing}（user_id 已一致）"))
        }
        out.agentId = existing
        return bindUserToAgent(db, out)
    }
    let newId = seedQuery(db,
        "INSERT INTO agents (name, agent_type, description, status, user_id, identity_status, " +
        "discoverable, creator, created_at, updated_at) " +
        "VALUES (?, 'MAIN', ?, 1, ?::uuid, 'none', true, ?::uuid, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) " +
        "RETURNING id::text",
        p1: "MainAgent",
        p2: "安装器建立的主智能体实体（agent_type=MAIN，status=1）",
        p3: out.agentUserId,
        p4: out.superAdminId)
    if (newId.isEmpty()) {
        out.errors.add("A6 失败：主 agent 实体写入 agents 未返回 id")
        return false
    }
    out.agentId = newId
    out.steps.add(IdentityStep(code: "A6", action: "created",
        detail: "主 agent 实体 ${newId}（agent_type='MAIN'，status=1）"))
    return bindUserToAgent(db, out)
}

/// 回填 `uctoo_user.agent_id = agents.id`（design §4.10.5(2) 明文要求的那次 UPDATE）。
func bindUserToAgent(db: Connection, out: IdentitySetup): Bool {
    let cur = seedQuery(db,
        "SELECT agent_id::text FROM uctoo_user WHERE id = ?::uuid", p1: out.agentUserId)
    if (cur != out.agentId) {
        let err = seedExec(db,
            "UPDATE uctoo_user SET agent_id = ?::uuid, updated_at = CURRENT_TIMESTAMP WHERE id = ?::uuid",
            p1: out.agentId, p2: out.agentUserId)
        if (!err.isEmpty()) {
            out.errors.add("A6→A2 回填 uctoo_user.agent_id 失败：${err}")
            return false
        }
        out.steps.add(IdentityStep(code: "A6b", action: "created",
            detail: "回填 uctoo_user.agent_id = ${out.agentId}"))
    } else {
        out.steps.add(IdentityStep(code: "A6b", action: "reused",
            detail: "uctoo_user.agent_id 已一致"))
    }
    return true
}

/// A3 / A4：账号 → 角色绑定（只增不删）。
func ensureUserRole(db: Connection, out: IdentitySetup, userId: String, roleId: String,
                    creatorId: String, code: String, label: String): Unit {
    let has = seedQuery(db,
        "SELECT id::text FROM user_has_roles WHERE user_id = ?::uuid AND role_id = ?::uuid " +
        "AND deleted_at IS NULL LIMIT 1",
        p1: userId, p2: roleId)
    if (!has.isEmpty()) {
        out.steps.add(IdentityStep(code: code, action: "reused", detail: "${label} 绑定已存在"))
        return
    }
    let err = seedExec(db,
        "INSERT INTO user_has_roles (user_id, role_id, status, creator, created_at, updated_at) " +
        "VALUES (?::uuid, ?::uuid, 0, ?::uuid, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
        p1: userId, p2: roleId, p3: creatorId)
    if (err.isEmpty()) {
        out.steps.add(IdentityStep(code: code, action: "created", detail: "${label} 绑定已补种"))
    } else {
        out.errors.add("${code} 补种「${label}」失败：${err}")
    }
}

/// A5：账号 → 用户组（code='agents'）绑定。
func ensureGroupBinding(db: Connection, out: IdentitySetup): Unit {
    let gid = seedQuery(db,
        "SELECT id::text FROM user_group WHERE code = ? AND deleted_at IS NULL LIMIT 1",
        p1: RBAC_AGENTS_GROUP_CODE)
    if (gid.isEmpty()) {
        out.errors.add("A5 失败：user_group(code='${RBAC_AGENTS_GROUP_CODE}') 不存在（seed 未导入或该行缺失）；" +
            "智能体自动登录的用户组前置不成立（AC-213）")
        return
    }
    let has = seedQuery(db,
        "SELECT id::text FROM user_has_group WHERE groupable_id = ?::uuid AND group_id = ?::uuid " +
        "AND deleted_at IS NULL LIMIT 1",
        p1: out.agentUserId, p2: gid)
    if (!has.isEmpty()) {
        out.steps.add(IdentityStep(code: "A5", action: "reused",
            detail: "主 agent → 用户组 ${RBAC_AGENTS_GROUP_CODE} 绑定已存在"))
        return
    }
    let err = seedExec(db,
        "INSERT INTO user_has_group (groupable_type, group_id, groupable_id, status, creator, " +
        "created_at, updated_at) " +
        "VALUES ('uctoo_user', ?::uuid, ?::uuid, 0, ?::uuid, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
        p1: gid, p2: out.agentUserId, p3: out.superAdminId)
    if (err.isEmpty()) {
        out.steps.add(IdentityStep(code: "A5", action: "created",
            detail: "主 agent → 用户组 ${RBAC_AGENTS_GROUP_CODE} 绑定已补种"))
    } else {
        out.errors.add("A5 补种用户组绑定失败：${err}")
    }
}

/// P3：超管角色持 `*` 通配授权行（AC-199）。缺失时补种，存在即复用，**不删除既有授权**。
func ensureWildcardPermission(db: Connection, out: IdentitySetup): Unit {
    let has = seedQuery(db,
        "SELECT permission_name FROM role_has_permission WHERE role_id = ?::uuid " +
        "AND permission_name = '*' AND deleted_at IS NULL LIMIT 1",
        p1: RBAC_SUPER_ADMIN_ROLE_ID)
    if (!has.isEmpty()) {
        out.steps.add(IdentityStep(code: "P3", action: "reused",
            detail: "超管角色已持有通配权限 '*'"))
        return
    }
    let err = seedExec(db,
        "INSERT INTO role_has_permission (role_id, permission_name, status, creator, created_at, updated_at) " +
        "VALUES (?::uuid, '*', 0, ?::uuid, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
        p1: RBAC_SUPER_ADMIN_ROLE_ID, p2: out.superAdminId)
    if (err.isEmpty()) {
        out.steps.add(IdentityStep(code: "P3", action: "created",
            detail: "补种 role_has_permission(超管角色, '*')"))
    } else {
        out.errors.add("P3 补种超管通配权限失败：${err}")
    }
}

/// AC-214：账号 → 实体 与 实体 → 账号 两个方向必须**双向非空且一致**。
func checkDualBinding(db: Connection, out: IdentitySetup): Unit {
    let a = seedQuery(db,
        "SELECT agent_id::text FROM uctoo_user WHERE id = ?::uuid", p1: out.agentUserId)
    let b = seedQuery(db,
        "SELECT user_id::text FROM agents WHERE id = ?::uuid", p1: out.agentId)
    if (a.isEmpty() || b.isEmpty() || a != b) {
        out.errors.add("AC-214 双向指针不一致：uctoo_user.agent_id='${a}' / agents.user_id='${b}'" +
            "（两者须非空且相等）")
        return
    }
    out.steps.add(IdentityStep(code: "AC-214", action: "verified",
        detail: "双向指针一致：${a}"))
}

// ===================== 数据库小工具（本包共用） =====================

/// 打开一条数据库连接（调用方负责关闭）。
func openSeedConn(conn: DbConn): Connection {
    registerDriver()
    let ds = PgDatasource(conn.host, conn.port, conn.user, conn.password,
        conn.database, HashMap<String, String>())
    return ds.connect()
}

/// 按序绑定非空参数：约定调用方从左到右给值，不跳空。
func seedBindParams(stmt: Statement, p1: String, p2: String, p3: String, p4: String): Unit {
    if (!p1.isEmpty()) {
        stmt.set<String>(0, p1)
    }
    if (!p2.isEmpty()) {
        stmt.set<String>(1, p2)
    }
    if (!p3.isEmpty()) {
        stmt.set<String>(2, p3)
    }
    if (!p4.isEmpty()) {
        stmt.set<String>(3, p4)
    }
}

/// 单值查询（首行首列）。无结果或异常均返回空串（与 identity.cj 的 queryCell 同口径）。
func seedQuery(db: Connection, sql: String, p1!: String = "", p2!: String = "",
               p3!: String = "", p4!: String = ""): String {
    try {
        let stmt = db.prepareStatement(sql)
        seedBindParams(stmt, p1, p2, p3, p4)
        let rs = stmt.query()
        if (rs.next()) {
            return match (rs.getOrNull<String>(0)) {
                case Some(v) => v
                case None => ""
            }
        }
        return ""
    } catch (_: Exception) {
        return ""
    }
}

/// 执行非查询语句。成功返回空串，失败返回错误信息（不抛异常）。
func seedExec(db: Connection, sql: String, p1!: String = "", p2!: String = "",
              p3!: String = "", p4!: String = ""): String {
    try {
        let stmt = db.prepareStatement(sql)
        seedBindParams(stmt, p1, p2, p3, p4)
        stmt.update()
        return ""
    } catch (e: Exception) {
        return e.message
    }
}

/// 单值整数查询。
func seedQueryInt(db: Connection, sql: String, p1!: String = "", p2!: String = ""): Int64 {
    let s = seedQuery(db, sql, p1: p1, p2: p2)
    try {
        return Int64.parse(s)
    } catch (_: Exception) {
        return 0
    }
}

/// 单列多行查询。
func seedQueryList(db: Connection, sql: String, p1!: String = "", p2!: String = ""): ArrayList<String> {
    let out = ArrayList<String>()
    try {
        let stmt = db.prepareStatement(sql)
        seedBindParams(stmt, p1, p2, "", "")
        let rs = stmt.query()
        while (rs.next()) {
            match (rs.getOrNull<String>(0)) {
                case Some(v) => out.add(v)
                case None => ()
            }
        }
    } catch (_: Exception) {
        ()
    }
    return out
}

/// 不可登录的随机串：随机性取自**数据库侧**，避免安装器自带弱随机源（AC-204/211）。
func randomToken(db: Connection): String {
    let t = seedQuery(db, "SELECT md5(random()::text || clock_timestamp()::text || random()::text)")
    if (!t.isEmpty()) {
        return t
    }
    return seedQuery(db, "SELECT replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')")
}
