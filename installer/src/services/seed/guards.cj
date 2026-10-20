package uc_installer.services.seed

// ============================================================================
// 导出门禁（任务 T044，design.md §4.10.5(5) E5）。
//
// 对应 REQ-RNI-093 / 099；AC-224~226、243~244、252。
//
// 六条门禁（任一不过 → 导出失败，不覆盖既有产物）：
//   ① 体积 / 行数上限（guards.maxFileBytes / maxRowsPerTable）
//   ② 破坏性语句扫描（guards.forbidStatements：DROP TABLE / TRUNCATE / DELETE FROM）
//   ③ 敏感形态扫描（guards.secretScan：^sk-/^ghp_/^fc- 等前缀锚定形态；
//      postgres:///jdbc:/eyJ/$2a$/$2b$/BEGIN PRIVATE KEY 为子串形态）。
//      注：前缀形态必须以 `^` 锚定（值"以该形态开头"），否则会误伤 UUID 十六进制
//      段（如 `04fc-` 含 `fc-`）与普通路径段（如 `task-status` 含 `sk-`）。
//   ④ 脱敏生效校验（敏感列值必须为占位符；failOnUnsanitizedSensitiveColumn）
//   ⑤ 同步残留校验（forbidSyncDerivedRows：放行表不得有 source_path 非空行）
//   ⑥ 身份列裸 uuid 残留 + 外键自洽（principalColumns/agentColumns 不得出现裸 uuid）
//
// 实现：单次扫描（scanSqlFile）用收集器累积六类命中，再统一判定。
// ============================================================================

import std.fs.Path
import std.collection.{ArrayList, HashMap}

/// 单条门禁发现。
public struct GuardFinding {
    /// 门禁编号：size / statements / secret / sanitize / sync / identity。
    public let gate: String
    /// 人类可读说明。
    public let message: String

    public init(gate!: String, message!: String) {
        this.gate = gate
        this.message = message
    }
}

/// 六门禁总判定。
public struct GuardReport {
    public let passed: Bool
    public let findings: ArrayList<GuardFinding>

    public init(passed!: Bool, findings!: ArrayList<GuardFinding>) {
        this.passed = passed
        this.findings = findings
    }
}

/// 门禁扫描收集器：在 scanSqlFile 的回调里累积六类命中。
/// 用 class 承载状态（而非捕获局部 var 的闭包，规避仓颉"闭包不能捕获局部 var"限制）。
private class GateCollector {
    // 配置（构造时注入）
    let identityCols: ArrayList<String>
    let sensitiveCols: ArrayList<String>
    let syncTables: ArrayList<String>
    let guards: ExportGuards

    // 累积命中
    let perTableRows: HashMap<String, Int64> = HashMap<String, Int64>()
    let forbiddenHits: ArrayList<String> = ArrayList<String>()
    let secretHits: ArrayList<String> = ArrayList<String>()
    let sensitiveUnsanitized: ArrayList<String> = ArrayList<String>()
    let syncSourcePathHits: ArrayList<String> = ArrayList<String>()
    let identityBareUuid: ArrayList<String> = ArrayList<String>()

    init(identityCols!: ArrayList<String>, sensitiveCols!: ArrayList<String>,
         syncTables!: ArrayList<String>, guards!: ExportGuards) {
        this.identityCols = identityCols
        this.sensitiveCols = sensitiveCols
        this.syncTables = syncTables
        this.guards = guards
    }

    func onInsert(ins: InsertStatement): Unit {
        // ① 行数累计（每条 INSERT 可能含多行 VALUES）。
        let n = match (perTableRows.get(ins.table)) { case Some(x) => x; case None => 0 }
        perTableRows.add(ins.table, n + ins.rows.size)

        // ⑤ 同步残留：sync 表不得有 source_path 非空行。
        if (syncTables.contains(ins.table)) {
            var spIdx: Int64 = -1
            for (j in 0..ins.columns.size) {
                if (ins.columns[j] == "source_path") { spIdx = j }
            }
            if (spIdx >= 0) {
                for (row in ins.rows) {
                    if (spIdx < row.size) {
                        match (row[spIdx].text) {
                            case Some(t) =>
                                if (!t.isEmpty()) {
                                    syncSourcePathHits.add(
                                        "${ins.table}.source_path = '${t}'（放行表不得含同步残留行）")
                                }
                            case None => ()
                        }
                    }
                }
            }
        }

        // ③ ④ ⑥ 逐单元格扫描
        for (j in 0..ins.columns.size) {
            let colName = ins.columns[j]
            for (row in ins.rows) {
                if (j >= row.size) { continue }
                match (row[j].text) {
                    case Some(t) =>
                        // ③ 敏感形态：命中 secretScan 即记（支持 `^` 前缀锚定）。
                        for (pat in guards.secretScan) {
                            if (secretPatternMatches(t, pat)) {
                                let lbl = if (pat.startsWith("^")) { pat[1..] } else { pat }
                                secretHits.add("${ins.table}.${colName} 命中机密形态 '${lbl}'")
                            }
                        }
                        // ⑥ 身份列裸 uuid 残留（外键自洽：身份引用必须已是占位符）。
                        if (identityCols.contains(colName) && looksLikeUuid(t)) {
                            identityBareUuid.add("${ins.table}.${colName} = ${t}（身份列不得残留裸 uuid）")
                        }
                        // ④ 脱敏生效：敏感列必须已是占位符。
                        if (sensitiveCols.contains(colName)) {
                            let isPlaceholder = t.startsWith("{{secret:") || t.startsWith("{{env:")
                            if (!isPlaceholder) {
                                for (pat in guards.secretScan) {
                                    if (secretPatternMatches(t, pat)) {
                                        let lbl = if (pat.startsWith("^")) { pat[1..] } else { pat }
                                        sensitiveUnsanitized.add("${ins.table}.${colName} 含未脱敏机密（${lbl}）：${t}")
                                    }
                                }
                            }
                        }
                    case None => ()
                }
            }
        }
    }

    func onOther(stmt: String): Unit {
        // ② 破坏性语句扫描（大小写不敏感）。
        let low = stmt.toAsciiLower()
        for (f in guards.forbidStatements) {
            if (low.contains(f.toAsciiLower())) {
                forbiddenHits.add("包含禁止语句 '${f}'：${stmt.trimAscii()}")
            }
        }
    }
}

/// 运行六条门禁，返回判定。任一不过 → `passed=false`。
///
/// `sqlPath` 为已落盘的导出 SQL（E6 之前在临时文件上跑，不过则不覆盖既有产物）。
public func guardExport(sqlPath: Path, policy: ExportPolicy, sp: SanitizePolicy): GuardReport {
    let findings = ArrayList<GuardFinding>()

    // 身份列集合（principalColumns ∪ agentColumns）。
    let identityCols = ArrayList<String>()
    for (c in policy.principalColumns) { identityCols.add(c) }
    for (c in policy.agentColumns) { identityCols.add(c) }

    // 敏感列集合：从 r1/r2 列通配里取"列"段（*.password → password；config.value → value）。
    let sensitiveCols = ArrayList<String>()
    for (pat in sp.r1.columns) { addColumnOf(sensitiveCols, pat) }
    for (pat in sp.r2.columns) { addColumnOf(sensitiveCols, pat) }

    let syncTables = syncDerivedTables()
    let g = policy.guards

    let collector = GateCollector(
        identityCols: identityCols,
        sensitiveCols: sensitiveCols,
        syncTables: syncTables,
        guards: g)

    // 单次扫描：回调累积六类命中。scanSqlFile 抛 SqlScanError 时不静默。
    //
    // 两条仓颉 lambda 硬约束（对齐 scanner.cj:1235~1239 的本仓先例）：
    //   ① **参数不加括号**：写作 `{ 名: 类型 => 体 }`。
    //      写成 `{(名: 类型) => 体}` 会报 "expected '=>' in lambda expression"（实测踩到）。
    //   ② **参数名不用 `_` 配类型标注**：本仓先例要么 `{ _ => }`（无类型），要么
    //      `{ a: T => }`（有类型），两者不混用。
    // 另外 scanSqlFile 的 onInsert / onOther 是**位置参数**（无 `!`），
    // 不能写 `onInsert:`（位置参数带名调用报 invalid named arguments prefix）。
    let onIns = { ins: InsertStatement => collector.onInsert(ins) }
    let onOth = { s: String => collector.onOther(s) }
    let scan = scanSqlFile(sqlPath, onIns, onOth)

    // ① 体积上限
    if (scan.totalBytes > g.maxFileBytes) {
        findings.add(GuardFinding(gate: "size",
            message: "导出文件 ${scan.totalBytes} 字节超过上限 ${g.maxFileBytes}"))
    }
    // ① 行数上限
    for ((t, n) in collector.perTableRows) {
        if (n > g.maxRowsPerTable) {
            findings.add(GuardFinding(gate: "rows",
                message: "表 ${t} 导出 ${n} 行超过上限 ${g.maxRowsPerTable}"))
        }
    }
    // ② 破坏性语句
    for (h in collector.forbiddenHits) {
        findings.add(GuardFinding(gate: "statements", message: h))
    }
    // ③ 敏感形态
    for (h in collector.secretHits) {
        findings.add(GuardFinding(gate: "secret", message: h))
    }
    // ④ 脱敏生效校验
    if (g.failOnUnsanitizedSensitiveColumn) {
        for (h in collector.sensitiveUnsanitized) {
            findings.add(GuardFinding(gate: "sanitize", message: h))
        }
    }
    // ⑤ 同步残留
    if (g.forbidSyncDerivedRows) {
        for (h in collector.syncSourcePathHits) {
            findings.add(GuardFinding(gate: "sync", message: h))
        }
    }
    // ⑥ 身份列裸 uuid 残留
    for (h in collector.identityBareUuid) {
        findings.add(GuardFinding(gate: "identity", message: h))
    }

    return GuardReport(passed: findings.isEmpty(), findings: findings)
}

/// 机密形态匹配：支持 `^` 前缀锚定（值"必须以该形态开头"），否则按子串包含匹配。
///
/// `sk-`/`fc-`/`ghp_` 这类"前缀形态"必须锚定，否则会误伤 UUID 十六进制段
/// （如 `04fc-` 含 `fc-`）与普通路径段（如 `task-status` 含 `sk-`）。
/// 与 sanitize-policy R2_env 的 `^(ghp_|sk-|fc-)` 保持同一语义。
private func secretPatternMatches(value: String, pattern: String): Bool {
    if (pattern.startsWith("^")) {
        return value.startsWith(pattern[1..])
    }
    return value.contains(pattern)
}

/// 把列通配 `*.col` / `tbl.col` 还原成列名 `col` 加入集合（只取第二段，第一段忽略）。
private func addColumnOf(out: ArrayList<String>, pattern: String): Unit {
    match (pattern.indexOf('.')) {
        case Some(i) =>
            let col = pattern[i + 1..]
            if (!col.isEmpty() && !out.contains(col)) {
                out.add(col)
            }
        case None => ()
    }
}
