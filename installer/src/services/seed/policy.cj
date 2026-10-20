package uc_installer.services.seed

import std.fs.Path
import std.collection.{ArrayList, HashMap, HashSet}
import std.core.StringBuilder
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonKind}
import uc_installer.services.readFileText
import uc_installer.util.{jsonParse, asObject, jsonStr, jsonInt, jsonBool, jsonOptObj,
    jsonOptArr, jsonStrList}

// ============================================================================
// Seed 导出/脱敏策略文件与加载器（任务 T039）。
//
// 对应 REQ-RNI-092~097 / 101 / 105；AC-220~223、248~252、260~261。
// 策略文件：sql/seed/export-policy.json + sql/seed/sanitize-policy.json
//
// ===================== 三条必须守住的边界 =====================
//
// **① `defaultTier: "structure-only"` 是白名单而非黑名单（R-32）**：
// 未被显式批准进 `bootstrap`/`sample` 的表**只导结构**。新业务表上线后若无人
// 加入白名单，自动只导结构——不可能意外泄漏业务数据。
// 加载器对 `defaultTier` 做**硬校验**：缺失或取值不同即判策略不合法，
// 不给"填错了也能跑"留后门（把"默认拒绝"翻成"默认全导"是灾难级方向错误）。
//
// **② `keepVerbatim` 三要素必填（AC-261）**：
// 每条必须同时有 `table` / `key` / `reason`，缺任一即判不合法——
// 没有理由的原样保留条目等于一个随时会被误当成"已审核"的敏感数据出口。
//
// **③ 保留清单只对 R2 生效，R1 不豁免**：
// 不允许以"这是历史配置项"为由把真实凭据/密钥/令牌保留下来。
// 用 `keepVerbatimAppliesToR1()` 显式返回 false，让调用点在代码里
// 看得见这个判断，避免后人一厢情愿给 R1 开口子。
//
// ============================================================================

// ============================================================================

/// 导出策略文件相对路径（相对仓库根）。
public let EXPORT_POLICY_REL = "sql/seed/export-policy.json"

/// 脱敏策略文件相对路径。
public let SANITIZE_POLICY_REL = "sql/seed/sanitize-policy.json"

public let EXPORT_POLICY_SCHEMA = "uctoo/seed-export/v1"
public let SANITIZE_POLICY_SCHEMA = "uctoo/seed-sanitize/v1"

// ===================== 导出策略数据模型 =====================

/// 档位（design.md §4.10.5(4)）。
///
/// 除 `StructureOnly` 外四档都是"额外允许导数据"的档，区别只在**谁来生成**
/// （安装器 / 运行时 / 示例 / 无人生成而是同步再造）。
public enum ExportTier {
    /// T-A：仅结构（`CREATE TABLE` + COMMENT + 约束/索引）。默认档。
    | StructureOnly
    /// T-B：引导数据（控制面常量）。
    | Bootstrap
    /// T-C：示例数据。
    | Sample
    /// T-D：安装器生成（不进 seed）。
    | InstallerGenerated
    /// T-D′：运行时生成（不进 seed）。
    | RuntimeGenerated
    /// T-F：同步/派生（不进 seed）。
    | SyncDerived
}

public func exportTierCode(t: ExportTier): String {
    match (t) {
        case ExportTier.StructureOnly => return "structure-only"
        case ExportTier.Bootstrap => return "bootstrap"
        case ExportTier.Sample => return "sample"
        case ExportTier.InstallerGenerated => return "installer-generated"
        case ExportTier.RuntimeGenerated => return "runtime-generated"
        case ExportTier.SyncDerived => return "sync-derived"
    }
}

/// 身份未命中时的处置策略。
public enum OrphanPolicy {
    /// 默认：导出失败（防泄漏）。
    | Fail
    /// 归位到指定 ref。
    | MapTo
    /// 丢弃该行。
    | Drop
}

public func orphanPolicyCode(p: OrphanPolicy): String {
    match (p) {
        case OrphanPolicy.Fail => return "fail"
        case OrphanPolicy.MapTo => return "map-to"
        case OrphanPolicy.Drop => return "drop"
    }
}

/// 身份命名空间（design.md §4.10.5(3)：双身份不可混）。
///
/// `Principal` → `uctoo_user.id`（人类超管）；
/// `Agent`     → `agents.id`（智能体实体）。
///
/// **红线**：`agent_id` 列指向 `agents.id`，**不是** `uctoo_user.id`。
/// 搞反会静默写入错的 uuid——导入期不报错、运行期才炸。
public enum IdentityNamespace {
    | Principal
    | Agent
}

public func identityNamespaceCode(n: IdentityNamespace): String {
    match (n) {
        case IdentityNamespace.Principal => return "principal"
        case IdentityNamespace.Agent => return "agent"
    }
}

/// 身份主体声明。
public struct IdentityPrincipal {
    /// 引用名，也是占位符 `{{principal:<ref>}}` 的 `<ref>`。
    public let ref: String
    /// `super_admin` / `service` / ...
    public let kind: String
    /// `runtime-created`（安装器建）/ `username`（既有账号）。
    public let source: String
    /// `source == "username"` 时的账号名，否则空串。
    public let username: String

    public init(ref: String, kind: String, source: String, username: String) {
        this.ref = ref
        this.kind = kind
        this.source = source
        this.username = username
    }
}

/// 孤儿覆盖项（单个 uuid 的定向处置）。
public struct OrphanOverride {
    public let uuid: String
    /// 目标 ref（须在 `principals` 中声明过）。
    public let to: String
    /// 限定列，格式 `表.列`（如 `entity.creator`）；空串表示不限。
    public let scope: String
    public let reason: String

    public init(uuid: String, to: String, scope: String, reason: String) {
        this.uuid = uuid
        this.to = to
        this.scope = scope
        this.reason = reason
    }
}

/// 示例数据（表级）策略。
public struct SamplePolicy {
    public let table: String
    public let maxRows: Int64
    /// 确定性排序键（§4.10.5 七条性质之三：两次导出 diff 为空）。
    public let orderBy: String

    public init(table: String, maxRows: Int64, orderBy: String) {
        this.table = table
        this.maxRows = maxRows
        this.orderBy = orderBy
    }
}

/// 门禁配置（design.md §4.10.5(5) E5）。
public struct ExportGuards {
    public let maxFileBytes: Int64
    public let maxRowsPerTable: Int64
    public let forbidStatements: ArrayList<String>
    public let secretScan: ArrayList<String>
    public let sanitizePolicy: String
    public let forbidSyncDerivedRows: Bool
    public let failOnUnsanitizedSensitiveColumn: Bool

    public init(maxFileBytes: Int64, maxRowsPerTable: Int64,
                forbidStatements: ArrayList<String>, secretScan: ArrayList<String>,
                sanitizePolicy: String, forbidSyncDerivedRows: Bool,
                failOnUnsanitizedSensitiveColumn: Bool) {
        this.maxFileBytes = maxFileBytes
        this.maxRowsPerTable = maxRowsPerTable
        this.forbidStatements = forbidStatements
        this.secretScan = secretScan
        this.sanitizePolicy = sanitizePolicy
        this.forbidSyncDerivedRows = forbidSyncDerivedRows
        this.failOnUnsanitizedSensitiveColumn = failOnUnsanitizedSensitiveColumn
    }
}

/// 导出策略（`sql/seed/export-policy.json` 的内存形态）。
public struct ExportPolicy {
    public let schema: String
    public let defaultDatabase: String
    /// 恒为 `"structure-only"`；加载器已硬校验（R-32）。
    public let defaultTier: String
    /// T-B 白名单表。
    public let bootstrapTables: ArrayList<String>
    /// T-B 行级谓词：表 → SQL 条件（`config` → `env_key IS NULL`）。
    public let bootstrapRowPredicates: HashMap<String, String>
    /// T-C 示例数据。
    public let samples: ArrayList<SamplePolicy>
    /// T-D 安装器生成（导出侧恒不导，此处供门禁与报告对照）。
    public let installerGenerated: ArrayList<String>
    /// T-D′ 运行时生成：表 → SQL 条件（`config` → `env_key IS NOT NULL`）。
    public let runtimeGenerated: HashMap<String, String>
    /// T-F 同步/派生。
    public let syncDerived: ArrayList<String>
    public let principalTable: String
    public let principalColumns: ArrayList<String>
    public let agentTable: String
    public let agentColumns: ArrayList<String>
    public let principals: ArrayList<IdentityPrincipal>
    public let orphanDefault: OrphanPolicy
    public let orphanOverrides: ArrayList<OrphanOverride>
    public let guards: ExportGuards

    public init(schema: String, defaultDatabase: String, defaultTier: String,
                bootstrapTables: ArrayList<String>,
                bootstrapRowPredicates: HashMap<String, String>,
                samples: ArrayList<SamplePolicy>,
                installerGenerated: ArrayList<String>,
                runtimeGenerated: HashMap<String, String>,
                syncDerived: ArrayList<String>,
                principalTable: String, principalColumns: ArrayList<String>,
                agentTable: String, agentColumns: ArrayList<String>,
                principals: ArrayList<IdentityPrincipal>,
                orphanDefault: OrphanPolicy,
                orphanOverrides: ArrayList<OrphanOverride>,
                guards: ExportGuards) {
        this.schema = schema
        this.defaultDatabase = defaultDatabase
        this.defaultTier = defaultTier
        this.bootstrapTables = bootstrapTables
        this.bootstrapRowPredicates = bootstrapRowPredicates
        this.samples = samples
        this.installerGenerated = installerGenerated
        this.runtimeGenerated = runtimeGenerated
        this.syncDerived = syncDerived
        this.principalTable = principalTable
        this.principalColumns = principalColumns
        this.agentTable = agentTable
        this.agentColumns = agentColumns
        this.principals = principals
        this.orphanDefault = orphanDefault
        this.orphanOverrides = orphanOverrides
        this.guards = guards
    }

    /// 查某表所属档位。**未在白名单中即 `StructureOnly`**（默认拒绝）。
    public func tierOf(table: String): ExportTier {
        if (bootstrapTables.contains(table)) {
            return ExportTier.Bootstrap
        }
        for (s in samples) {
            if (s.table == table) {
                return ExportTier.Sample
            }
        }
        if (syncDerived.contains(table)) {
            return ExportTier.SyncDerived
        }
        if (runtimeGenerated.contains(table)) {
            return ExportTier.RuntimeGenerated
        }
        if (installerGenerated.contains(table)) {
            return ExportTier.InstallerGenerated
        }
        return ExportTier.StructureOnly
    }

    /// 该表是否允许导数据行（只有 `bootstrap` / `sample` 两档导行）。
    ///
    /// ⚠️ 仓颉 enum **不实现 `operator ==`**（写了报 `invalid binary operator '=='`），
    /// 所以这里必须用 `match` 逐臂判断，不能写 `t == ExportTier.Bootstrap || ...`。
    public func allowsRows(table: String): Bool {
        return match (tierOf(table)) {
            case ExportTier.Bootstrap => true
            case ExportTier.Sample => true
            case _ => false
        }
    }
}

// ===================== 脱敏策略数据模型 =====================

/// `keepVerbatim` 条目（OQ-C1 拍板落地，design §4.10.6(4.1)）。
///
/// 三要素（表 / 键 / 理由）缺一即策略不合法（AC-261）。
public struct KeepVerbatim {
    public let table: String
    public let key: String
    public let reason: String

    public init(table: String, key: String, reason: String) {
        this.table = table
        this.key = key
        this.reason = reason
    }
}

/// R1：凭据/口令/密钥/令牌 → `{{secret:<kind>}}`。
public struct R1SecretRule {
    /// 列通配清单（`*.password` / `config.value`）。
    public let columns: ArrayList<String>
    /// `config` 表专用的行级判定式。
    public let configValuePredicate: String
    public let placeholder: String

    public init(columns: ArrayList<String>, configValuePredicate: String, placeholder: String) {
        this.columns = columns
        this.configValuePredicate = configValuePredicate
        this.placeholder = placeholder
    }
}

/// R2：环境标识/时间戳 → `{{env:<kind>}}` / `{{ts:epoch}}`。
public struct R2EnvRule {
    public let columns: ArrayList<String>
    public let patterns: ArrayList<String>
    public let placeholder: String

    public init(columns: ArrayList<String>, patterns: ArrayList<String>, placeholder: String) {
        this.columns = columns
        this.patterns = patterns
        this.placeholder = placeholder
    }
}

/// R3：值本身已是占位形态 → 原样保留。
public struct R3KeepRule {
    public let patterns: ArrayList<String>

    public init(patterns: ArrayList<String>) {
        this.patterns = patterns
    }
}

/// R4：既不可脱敏又不可置空 → 整表降级为仅结构。
public struct R4DropTableRule {
    public let tables: ArrayList<String>
    public let reason: String

    public init(tables: ArrayList<String>, reason: String) {
        this.tables = tables
        this.reason = reason
    }
}

/// 脱敏策略（`sql/seed/sanitize-policy.json` 的内存形态）。
public struct SanitizePolicy {
    public let schema: String
    public let r1: R1SecretRule
    public let r2: R2EnvRule
    public let r3: R3KeepRule
    public let r4: R4DropTableRule
    /// 原样保留清单（**只对 R2 生效**，见 `keepVerbatimAppliesToR1`）。
    public let keepVerbatim: ArrayList<KeepVerbatim>
    public let scanPatterns: ArrayList<String>
    /// `is_sensitive` 回填目标。
    public let backfillTable: String
    public let backfillColumn: String

    public init(schema: String, r1: R1SecretRule, r2: R2EnvRule, r3: R3KeepRule,
                r4: R4DropTableRule, keepVerbatim: ArrayList<KeepVerbatim>,
                scanPatterns: ArrayList<String>, backfillTable: String, backfillColumn: String) {
        this.schema = schema
        this.r1 = r1
        this.r2 = r2
        this.r3 = r3
        this.r4 = r4
        this.keepVerbatim = keepVerbatim
        this.scanPatterns = scanPatterns
        this.backfillTable = backfillTable
        this.backfillColumn = backfillColumn
    }

    /// 该表是否被 R4 整表降级为仅结构。
    public func droppedByR4(table: String): Bool {
        return r4.tables.contains(table)
    }
}

/// 保留清单**是否**对 R1 生效。恒为 `false`（REQ-RNI-105）。
///
/// 做成函数而非常量，是为了让调用点在代码里显式写出这个判断。
public func keepVerbatimAppliesToR1(): Bool {
    return false
}

/// 保留清单**是否**对 R2 生效。恒为 `true`。
public func keepVerbatimAppliesToR2(): Bool {
    return true
}

// ===================== 加载结果 =====================

/// 策略加载结果：**要么成功要么带明确原因**，不设"部分成功"。
public class LoadedPolicy {
    /// 加载与校验都通过时为 Some，否则 None。
    public var exportPolicy: Option<ExportPolicy>
    /// 脱敏策略。
    public var sanitizePolicy: Option<SanitizePolicy>
    /// 失败原因列表（多条同时命中，便于一次改完）。
    public var errors: ArrayList<String>

    public init() {
        this.exportPolicy = None<ExportPolicy>
        this.sanitizePolicy = None<SanitizePolicy>
        this.errors = ArrayList<String>()
    }

    /// 是否加载成功（两个策略都在且无错误）。
    public func ok(): Bool {
        return errors.isEmpty() && exportPolicy.isSome() && sanitizePolicy.isSome()
    }

    /// 面向人的错误摘要（每行一条）。
    public func errorText(): String {
        let sb = StringBuilder()
        var i = 0
        while (i < errors.size) {
            if (i > 0) {
                sb.append("\n")
            }
            sb.append("- ")
            sb.append(errors[i])
            i += 1
        }
        return sb.toString()
    }
}

/// T-F 同步/派生表的**应有清单**（R-34 的机器判据）。
///
/// 固化在代码里而非只靠策略文件：策略被人手删掉一项时，加载器要能报出
/// "你少了哪张表"，而不是安静地少导或多导。
public func syncDerivedTables(): ArrayList<String> {
    let a = ArrayList<String>()
    a.add("agents")
    a.add("agent_skills")
    a.add("db_connection")
    a.add("db_info")
    return a
}

// ===================== 加载器 =====================

/// 加载并校验导出策略**及其引用的**脱敏策略。
///
/// 校验失败**不抛异常**：全部原因收集进 `LoadedPolicy.errors`，
/// 由调用方打印成人话。读策略失败就不该开始导出（AC-197 的
/// "不覆盖既有产物"精神）。
public func loadExportPolicy(repoRoot: Path): LoadedPolicy {
    let out = LoadedPolicy()
    let exportPath = repoRoot.join(EXPORT_POLICY_REL)
    let root = match (parseJsonObject(readFileText(exportPath))) {
        case Some(o) => o
        case None =>
            out.errors.add("无法读取或解析导出策略：${exportPath.toString()}")
            return out
    }

    let schema = jsonStr(root, "schema", "")
    if (schema != EXPORT_POLICY_SCHEMA) {
        out.errors.add("导出策略 schema 不合法：期望 \"${EXPORT_POLICY_SCHEMA}\"，实际 \"${schema}\"")
    }

    // R-32 硬校验：默认档必须 structure-only。整个白名单机制的基石，
    // 填错等于把"默认拒绝"翻成"默认全导"，故不做降级容错。
    let defaultTier = jsonStr(root, "defaultTier", "")
    if (defaultTier != "structure-only") {
        out.errors.add(
            "导出策略 defaultTier 必须为 \"structure-only\"（白名单优先、默认拒绝），实际 \"${defaultTier}\"")
    }

    let tiers = match (jsonOptObj(root, "tiers")) {
        case Some(t) => t
        case None =>
            out.errors.add("导出策略缺少 tiers 段")
            return out
    }

    let bootstrap = jsonStrList(tiers, "bootstrap")
    if (bootstrap.isEmpty()) {
        out.errors.add("导出策略 tiers.bootstrap 为空：默认拒绝的机制下白名单也为空，导出物将不含任何引导数据")
    }
    let rowPreds = readStringMap(tiers, "bootstrapRowPredicates")
    let runtimeGen = readStringMap(tiers, "runtime-generated")
    let samples = readSamples(tiers, out.errors)
    let installerGen = jsonStrList(tiers, "installer-generated")
    let syncDerived = jsonStrList(tiers, "sync-derived")

    // R-35：`config` 行级分治必须同时声明两侧，否则 `.env` 镜像行会漏进 seed。
    checkConfigPredicate(rowPreds, "bootstrapRowPredicates.config", "env_key IS NULL", out.errors)
    checkConfigPredicate(runtimeGen, "runtime-generated.config", "env_key IS NOT NULL", out.errors)

    // R-34：T-F 四张表必须齐全，否则同步派生数据会被当业务数据导出去。
    for (t in syncDerivedTables()) {
        if (!syncDerived.contains(t)) {
            out.errors.add(
                "导出策略 tiers.sync-derived 缺少 ${t}：该表由启动期同步/派生，写进 seed 会被 upsert 覆盖或软删下线")
        }
    }
    // T-F 与 T-D 同时含 `agents` 不矛盾（导出侧恒不导 / 导入侧由安装器建），
    // 但两处都要在，缺一说明策略被只手改过。
    if (!installerGen.contains("agents")) {
        out.errors.add("导出策略 tiers.installer-generated 缺少 agents（导入侧由安装器建主 agent）")
    }

    // 仓颉元组不支持 `ns.principalTable` 具名访问（本工程惯例是解构，见 ssl.cj / config.cj）。
    let (principalTable, principalCols, agentTable, agentCols) = readNamespaces(root)
    if (principalTable.isEmpty()) {
        out.errors.add("identity.namespaces.principal.table 未声明（应为 uctoo_user）")
    }
    if (principalCols.isEmpty()) {
        out.errors.add("identity.namespaces.principal.columns 为空：身份列清单缺失会导致 creator 列裸 uuid 残留")
    }
    if (agentTable.isEmpty()) {
        out.errors.add("identity.namespaces.agent.table 未声明（应为 agents）")
    }

    let principals = readPrincipals(root)
    if (principals.isEmpty()) {
        out.errors.add("identity.principals 为空：没有任何主体可被替换，creator 列将保留真实 uuid")
    }
    let (orphanDefault, orphanOverrides) = readOrphanPolicy(root)
    checkOrphanOverrides(principals, orphanOverrides, out.errors)

    let guards = readGuards(root)
    checkGuards(guards, out.errors)

    if (out.errors.isEmpty()) {
        out.exportPolicy = Some(ExportPolicy(
            schema, jsonStr(root, "defaultDatabase", "uctoo"), defaultTier,
            bootstrap, rowPreds, samples, installerGen, runtimeGen, syncDerived,
            principalTable, principalCols, agentTable, agentCols,
            principals, orphanDefault, orphanOverrides, guards))
        loadSanitizeInto(out, repoRoot, guards.sanitizePolicy)
    }
    out
}

/// 加载并校验脱敏策略（独立入口，供 CLI 只读校验策略用）。
public func loadSanitizePolicy(repoRoot: Path): LoadedPolicy {
    let out = LoadedPolicy()
    let p = repoRoot.join(SANITIZE_POLICY_REL)
    let root = match (parseJsonObject(readFileText(p))) {
        case Some(o) => o
        case None =>
            out.errors.add("无法读取或解析脱敏策略：${p.toString()}")
            return out
    }
    if (!checkSanitizeRoot(out, root)) {
        return out
    }
    out.sanitizePolicy = buildSanitize(root)
    out
}

// ===================== 内部：脱敏策略 =====================

/// 把脱敏策略装进 `out`，并做校验。校验不过则把原因追加进 `errors`。
private func loadSanitizeInto(out: LoadedPolicy, repoRoot: Path, rel: String): Unit {
    let p = resolveSanitizePath(repoRoot, rel)
    let root = match (parseJsonObject(readFileText(p))) {
        case Some(o) => o
        case None =>
            out.errors.add("无法读取或解析脱敏策略：${p.toString()}（由 export-policy.guards.sanitizePolicy 指定）")
            return
    }
    if (!checkSanitizeRoot(out, root)) {
        return
    }
    out.sanitizePolicy = buildSanitize(root)
}

/// 校验脱敏策略根对象。返回 true 表示可继续构造。
private func checkSanitizeRoot(out: LoadedPolicy, root: JsonObject): Bool {
    let schema = jsonStr(root, "schema", "")
    if (schema != SANITIZE_POLICY_SCHEMA) {
        out.errors.add("脱敏策略 schema 不合法：期望 \"${SANITIZE_POLICY_SCHEMA}\"，实际 \"${schema}\"")
    }
    let rules = match (jsonOptObj(root, "rules")) {
        case Some(r) => r
        case None =>
            out.errors.add("脱敏策略缺少 rules 段")
            return false
    }
    let r1 = readR1(rules)
    if (r1.columns.isEmpty()) {
        out.errors.add("脱敏策略 rules.R1_secret.columns 为空：凭据不会被脱敏")
    }
    let r2 = readR2(rules)
    if (r2.patterns.isEmpty()) {
        out.errors.add("脱敏策略 rules.R2_env.patterns 为空：环境标识不会被归一")
    }
    let r3 = readR3(rules)
    if (r3.patterns.isEmpty()) {
        out.errors.add("脱敏策略 rules.R3_keep_placeholder.patterns 为空：已是占位形态的值会被二次替换")
    }
    let r4 = readR4(rules)
    if (r4.tables.isEmpty()) {
        out.errors.add("脱敏策略 rules.R4_drop_table.tables 为空")
    } else if (r4.reason.isEmpty()) {
        out.errors.add("脱敏策略 rules.R4_drop_table 缺少 reason：整表降级必须留理由")
    }
    if (jsonStrList(root, "scanPatterns").isEmpty()) {
        out.errors.add("脱敏策略 scanPatterns 为空")
    }

    // AC-261：keepVerbatim 三要素逐条校验。
    let keep = readKeepVerbatim(root)
    if (keep.isEmpty()) {
        out.errors.add("脱敏策略缺少 keepVerbatim：OQ-C1 要求把跨环境一致的框架常量显式列入原样保留清单")
    }
    for (k in keep) {
        if (k.table.isEmpty()) {
            out.errors.add("keepVerbatim 条目缺少 table 字段（三要素必填）")
        }
        if (k.key.isEmpty()) {
            out.errors.add("keepVerbatim 条目 ${k.table} 缺少 key 字段（三要素必填）")
        }
        if (k.reason.isEmpty()) {
            out.errors.add("keepVerbatim 条目 ${k.table}.${k.key} 缺少 reason 字段（三要素必填，AC-261）")
        }
    }

    let bf = match (jsonOptObj(root, "isSensitiveBackfill")) {
        case Some(b) => b
        case None =>
            out.errors.add("脱敏策略缺少 isSensitiveBackfill（表/列）")
            return false
    }
    if (jsonStr(bf, "table", "").isEmpty() || jsonStr(bf, "column", "").isEmpty()) {
        out.errors.add("脱敏策略 isSensitiveBackfill 的 table / column 不能为空")
    }
    return true
}

private func buildSanitize(root: JsonObject): SanitizePolicy {
    let rules = jsonOptObj(root, "rules").getOrThrow()
    let bf = jsonOptObj(root, "isSensitiveBackfill").getOrThrow()
    return SanitizePolicy(
        jsonStr(root, "schema", ""),
        readR1(rules), readR2(rules), readR3(rules), readR4(rules),
        readKeepVerbatim(root),
        jsonStrList(root, "scanPatterns"),
        jsonStr(bf, "table", ""), jsonStr(bf, "column", ""))
}

/// `sanitizePolicy` 相对仓库根；写成本身文件名时也接受（容错但不改语义）。
private func resolveSanitizePath(repoRoot: Path, rel: String): Path {
    if (rel.isEmpty()) {
        return repoRoot.join(SANITIZE_POLICY_REL)
    }
    return repoRoot.join(rel)
}

// ===================== 内部：导出策略校验 =====================

private func checkConfigPredicate(m: HashMap<String, String>, label: String,
                                 expected: String, errs: ArrayList<String>): Unit {
    match (m.get("config")) {
        case None => errs.add("导出策略缺少 ${label}（应为 \"${expected}\"）")
        case Some(v) =>
            if (v != expected) {
                errs.add("${label} 应为 \"${expected}\"，实际 \"${v}\"")
            }
    }
}

private func checkOrphanOverrides(principals: ArrayList<IdentityPrincipal>,
                                  ovs: ArrayList<OrphanOverride>,
                                  errs: ArrayList<String>): Unit {
    let refs = HashSet<String>()
    for (p in principals) {
        refs.add(p.ref)
    }
    for (ov in ovs) {
        if (ov.uuid.isEmpty()) {
            errs.add("orphanPolicy.overrides 存在缺 uuid 的条目")
            continue
        }
        if (!refs.contains(ov.to)) {
            errs.add("orphanPolicy.overrides 中 uuid=${ov.uuid} 指向未声明的 ref \"${ov.to}\"")
        }
        if (ov.reason.isEmpty()) {
            errs.add("orphanPolicy.overrides 中 uuid=${ov.uuid} 缺少 reason")
        }
    }
}

private func checkGuards(g: ExportGuards, errs: ArrayList<String>): Unit {
    if (g.maxFileBytes <= 0) {
        errs.add("guards.maxFileBytes 必须为正数")
    }
    if (g.maxRowsPerTable <= 0) {
        errs.add("guards.maxRowsPerTable 必须为正数")
    }
    if (g.forbidStatements.isEmpty()) {
        errs.add("guards.forbidStatements 为空：等于不拦破坏性语句")
    }
    if (g.secretScan.isEmpty()) {
        errs.add("guards.secretScan 为空：等于不做机密扫描")
    }
    if (g.sanitizePolicy.isEmpty()) {
        errs.add("guards.sanitizePolicy 未指定：导出期无法强制执行 E4.5 脱敏步")
    }
}

// ===================== 内部：JSON 解析 =====================

private func parseJsonObject(text: String): Option<JsonObject> {
    if (text.trimAscii().isEmpty()) {
        return None<JsonObject>
    }
    match (jsonParse(text)) {
        case Some(v) => asObject(v)
        case None => None<JsonObject>
    }
}

/// 读 `{"k": "v"}` 形态的对象为字符串映射；非字符串值按 `toString` 取。
private func readStringMap(o: JsonObject, key: String): HashMap<String, String> {
    let m = HashMap<String, String>()
    match (jsonOptObj(o, key)) {
        case Some(inner) =>
            for ((k, v) in inner.getFields()) {
                m.add(k, scalarText(v))
            }
        case None => ()
    }
    return m
}

/// JsonValue → 文本。字符串取原值，其余按 `toString`（用于调试输出）。
private func scalarText(v: JsonValue): String {
    match (v.kind()) {
        case JsonKind.JsString => v.asString().getValue()
        case _ => v.toString()
    }
}

/// `JsonArray` → `ArrayList<SamplePolicy>`。非对象条目记入 `errs`。
private func readSamples(tiers: JsonObject, errs: ArrayList<String>): ArrayList<SamplePolicy> {
    let out = ArrayList<SamplePolicy>()
    match (jsonOptObj(tiers, "sample")) {
        case Some(s) =>
            for ((name, v) in s.getFields()) {
                match (v.kind()) {
                    case JsonKind.JsObject =>
                        let so = v.asObject()
                        out.add(SamplePolicy(name, jsonInt(so, "maxRows", 200),
                            jsonStr(so, "orderBy", "id")))
                    case _ => errs.add("tiers.sample.${name} 不是对象，应为 {\"maxRows\":N,\"orderBy\":\"列\"}")
                }
            }
        case None => ()
    }
    return out
}

private func readNamespaces(root: JsonObject): (String, ArrayList<String>, String, ArrayList<String>) {
    var pt = ""
    var at = ""
    let pc = ArrayList<String>()
    let ac = ArrayList<String>()
    match (jsonOptObj(root, "identity")) {
        case Some(id) => match (jsonOptObj(id, "namespaces")) {
            case Some(ns) =>
                match (jsonOptObj(ns, "principal")) {
                    case Some(p) =>
                        pt = jsonStr(p, "table", "")
                        for (c in jsonStrList(p, "columns")) {
                            pc.add(c)
                        }
                    case None => ()
                }
                match (jsonOptObj(ns, "agent")) {
                    case Some(a) =>
                        at = jsonStr(a, "table", "")
                        for (c in jsonStrList(a, "columns")) {
                            ac.add(c)
                        }
                    case None => ()
                }
            case None => ()
        }
        case None => ()
    }
    return (pt, pc, at, ac)
}

private func readPrincipals(root: JsonObject): ArrayList<IdentityPrincipal> {
    let out = ArrayList<IdentityPrincipal>()
    match (jsonOptObj(root, "identity")) {
        case Some(id) => match (jsonOptArr(id, "principals")) {
            case Some(arr) => for (v in arr.getItems()) {
                match (v.kind()) {
                    case JsonKind.JsObject =>
                        let o = v.asObject()
                        out.add(IdentityPrincipal(
                            jsonStr(o, "ref", ""), jsonStr(o, "kind", ""),
                            jsonStr(o, "source", ""), jsonStr(o, "username", "")))
                    case _ => ()
                }
            }
            case None => ()
        }
        case None => ()
    }
    return out
}

private func readOrphanPolicy(root: JsonObject): (OrphanPolicy, ArrayList<OrphanOverride>) {
    let ovs = ArrayList<OrphanOverride>()
    var def = OrphanPolicy.Fail
    match (jsonOptObj(root, "identity")) {
        case Some(id) => match (jsonOptObj(id, "orphanPolicy")) {
            case Some(op) =>
                def = orphanPolicyFrom(jsonStr(op, "default", "fail"))
                match (jsonOptArr(op, "overrides")) {
                    case Some(arr) => for (v in arr.getItems()) {
                        match (v.kind()) {
                            case JsonKind.JsObject =>
                                let o = v.asObject()
                                ovs.add(OrphanOverride(jsonStr(o, "uuid", ""),
                                    jsonStr(o, "to", ""), jsonStr(o, "scope", ""),
                                    jsonStr(o, "reason", "")))
                            case _ => ()
                        }
                    }
                    case None => ()
                }
            case None => ()
        }
        case None => ()
    }
    return (def, ovs)
}

private func orphanPolicyFrom(s: String): OrphanPolicy {
    match (s) {
        case "drop" => return OrphanPolicy.Drop
        case "map-to" => return OrphanPolicy.MapTo
        case _ => return OrphanPolicy.Fail
    }
}

private func readGuards(root: JsonObject): ExportGuards {
    return match (jsonOptObj(root, "guards")) {
        case Some(g) => ExportGuards(
            jsonInt(g, "maxFileBytes", 2097152),
            jsonInt(g, "maxRowsPerTable", 5000),
            jsonStrList(g, "forbidStatements"),
            jsonStrList(g, "secretScan"),
            jsonStr(g, "sanitizePolicy", ""),
            jsonBool(g, "forbidSyncDerivedRows", true),
            jsonBool(g, "failOnUnsanitizedSensitiveColumn", true))
        case None => ExportGuards(2097152, 5000, ArrayList<String>(), ArrayList<String>(),
            SANITIZE_POLICY_REL, true, true)
    }
}

private func readR1(rules: JsonObject): R1SecretRule {
    return match (jsonOptObj(rules, "R1_secret")) {
        case Some(r) => R1SecretRule(jsonStrList(r, "columns"),
            jsonStr(r, "configValuePredicate", ""),
            jsonStr(r, "placeholder", "{{secret:<kind>}}"))
        case None => R1SecretRule(ArrayList<String>(), "", "{{secret:<kind>}}")
    }
}

private func readR2(rules: JsonObject): R2EnvRule {
    return match (jsonOptObj(rules, "R2_env")) {
        case Some(r) => R2EnvRule(jsonStrList(r, "columns"), jsonStrList(r, "patterns"),
            jsonStr(r, "placeholder", "{{env:<kind>}}"))
        case None => R2EnvRule(ArrayList<String>(), ArrayList<String>(), "{{env:<kind>}}")
    }
}

private func readR3(rules: JsonObject): R3KeepRule {
    return match (jsonOptObj(rules, "R3_keep_placeholder")) {
        case Some(r) => R3KeepRule(jsonStrList(r, "patterns"))
        case None => R3KeepRule(ArrayList<String>())
    }
}

private func readR4(rules: JsonObject): R4DropTableRule {
    return match (jsonOptObj(rules, "R4_drop_table")) {
        case Some(r) => R4DropTableRule(jsonStrList(r, "tables"), jsonStr(r, "reason", ""))
        case None => R4DropTableRule(ArrayList<String>(), "")
    }
}

private func readKeepVerbatim(root: JsonObject): ArrayList<KeepVerbatim> {
    let out = ArrayList<KeepVerbatim>()
    match (jsonOptArr(root, "keepVerbatim")) {
        case Some(arr) => for (v in arr.getItems()) {
            match (v.kind()) {
                case JsonKind.JsObject =>
                    let o = v.asObject()
                    out.add(KeepVerbatim(jsonStr(o, "table", ""), jsonStr(o, "key", ""),
                        jsonStr(o, "reason", "")))
                case _ => ()
            }
        }
        case None => ()
    }
    return out
}

// ===================== 查询辅助（供 T041~T048 复用） =====================

/// `keepVerbatim` 查询：该表.键是否在原样保留清单中。
public func isKeepVerbatim(p: SanitizePolicy, table: String, key: String): Bool {
    for (k in p.keepVerbatim) {
        if (k.table == table && k.key == key) {
            return true
        }
    }
    return false
}

/// 列通配匹配。
///
/// 策略文件里只有两种形态（`sanitize-policy.json` 现有清单即如此）：
/// - `*.<column>`：**任意表**的该列（如 `*.password`）
/// - `<table>.<column>`：仅该表的该列（如 `config.value`）
///
/// 不做正则/glob —— 清单是人工维护的，语义越窄越不容易出意外放行。
/// `*` 只允许出现在**第一段**；出现在第二段（如 `config.*`）一律不匹配，
/// 宁可不脱敏也不能错脱（错脱会把业务值变成占位符，导入后功能失效）。
public func columnPatternMatches(pattern: String, table: String, column: String): Bool {
    match (pattern.indexOf('.')) {
        case None =>
            // 没点号：裸列名，等价于 `*.<column>`（对齐 sanitize-policy 的 `*.api_key` 简写）。
            return column == pattern
        case Some(i) =>
            let head = pattern[0..i]
            let tail = pattern[i + 1..]
            if (head == "*") {
                return column == tail
            }
            return head == table && column == tail
    }
}

/// 按列通配清单判定某列是否命中 R1 / R2。
public func anyColumnMatches(patterns: ArrayList<String>, table: String, column: String): Bool {
    for (pat in patterns) {
        if (columnPatternMatches(pat, table, column)) {
            return true
        }
    }
    return false
}
