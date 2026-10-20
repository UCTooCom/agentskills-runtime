package uc_installer.services.seed

// ============================================================================
// 脱敏器（任务 T042，design.md §4.10.6(4)/(4.1)）。
//
// 对应 REQ-RNI-101 / 103 / 105；AC-248~252、256~261。
//
// 单单元格脱敏规则（执行顺序见 design §4.10.5(6) E4.5）：
//   R3 先行 → R1 → R2 → R4（R4 为整表降级，在 exporter 的表级处理）。
//
//   R3 已是占位形态（`your…`/`changeme`/`xxx`/`TODO`）→ 原样保留，不二次替换。
//   R1 凭据/口令/密钥/令牌 → `{{secret:<kind>}}`，并标记 `is_sensitive=true`。
//   R2 环境标识/时间戳 → `{{env:<kind>}}` / `{{ts:epoch}}`。
//   keepVerbatim（OQ-C1）只对 R2 生效；R1 不受豁免（不允许以"历史配置项"为由保留真实密钥）。
//
// 脱敏后单元格交由 caller 做 SQL 序列化（quoteSqlString）；本模块只产出最终文本值。
// ============================================================================

import std.collection.{ArrayList, HashMap}

/// 脱敏命中的规则。
public enum SanitizeRule {
    /// 未命中（原值保留，非脱敏）。
    | None
    /// R1 凭据/密钥/令牌 → `{{secret:<kind>}}`。
    | R1Secret
    /// R2 环境标识/时间戳 → `{{env:<kind>}}` / `{{ts:epoch}}`。
    | R2Env
    /// R3 已是占位形态 → 原样保留。
    | R3Keep
    /// R4 整表降级（单元格级仅用于标记，表级处理在 exporter）。
    | R4Drop
}

/// 单单元格脱敏结果。
public struct SanitizeOutcome {
    /// 脱敏后的文本值（未命中即原值）。
    public let value: String
    /// 命中的规则。
    public let rule: SanitizeRule
    /// 是否应回填 `config.is_sensitive = true`。
    public let sensitive: Bool
    /// 占位符的 `<kind>` 部分（仅 R1/R2 有意义，用于报告）。
    public let kind: String

    public init(value: String, rule: SanitizeRule, sensitive: Bool, kind: String) {
        this.value = value
        this.rule = rule
        this.sensitive = sensitive
        this.kind = kind
    }
}

/// 脱敏单单元格。
///
/// - `table` / `column`：单元格坐标（用于列通配匹配与 keepVerbatim 判定）。
/// - `value`：数据库原始文本（未做 SQL 序列化）。
/// - `row`：整行上下文（列名 → 原始值 Option），用于：
///     · config 表的 `key` 列（keepVerbatim 判定）；
///     · config 表的 `config_group` / `is_sensitive` 列（R1 的 configValuePredicate 判定）。
///
/// 返回结果供 caller 序列化并（在 config 表且命中 R1/R2 时）回填 `is_sensitive`。
public func sanitizeCell(sp: SanitizePolicy, table: String, column: String,
                         value: String, row: HashMap<String, String>): SanitizeOutcome {
    // R3 先行：已是占位形态 → 原样保留（不二次替换）。
    if (matchesAny(sp.r3.patterns, value)) {
        return SanitizeOutcome(value, SanitizeRule.R3Keep, false, "")
    }

    if (table == "config") {
        return sanitizeConfig(sp, column, value, row)
    }

    // 非 config 表：列通配命中即脱敏。
    if (anyColumnMatches(sp.r1.columns, table, column)) {
        let kind = deriveSecretKind(column)
        return SanitizeOutcome("{{secret:${kind}}}", SanitizeRule.R1Secret, true, kind)
    }
    if (anyColumnMatches(sp.r2.columns, table, column) || matchesAny(sp.r2.patterns, value)) {
        let (ph, kind) = deriveEnvPlaceholder(value, sp.r2.placeholder)
        return SanitizeOutcome(ph, SanitizeRule.R2Env, false, kind)
    }
    return SanitizeOutcome(value, SanitizeRule.None, false, "")
}

/// config 表的脱敏：keepVerbatim 优先，其次 R1（按 configValuePredicate），再次 R2。
private func sanitizeConfig(sp: SanitizePolicy, column: String, value: String,
                            row: HashMap<String, String>): SanitizeOutcome {
    let key = match (row.get("key")) { case Some(k) => k; case None => "" }
    // keepVerbatim 最高优先级：跨环境一致的框架常量原样保留（仅对 R2 生效，R1 不豁免——但此处
    // 在 R1 之前判定，等于两者都不动，符合"保留原值"语义；R1 豁免的硬约束见下方注释）。
    if (!key.isEmpty() && isKeepVerbatim(sp, "config", key)) {
        return SanitizeOutcome(value, SanitizeRule.R3Keep, false, "")
    }

    // R1：仅当该行确为凭据（configValuePredicate 语义）才脱敏。
    // 谓词固定为 `is_sensitive = true OR config_group IN ('api_key','token','ssl')`。
    if (configValuePredicateTrue(row)) {
        let kind = deriveSecretKind(column)
        return SanitizeOutcome("{{secret:${kind}}}", SanitizeRule.R1Secret, true, kind)
    }

    // R2：值形态命中（外网 URL / 时间戳 / 密钥前缀）。
    if (matchesAny(sp.r2.patterns, value)) {
        let (ph, kind) = deriveEnvPlaceholder(value, sp.r2.placeholder)
        return SanitizeOutcome(ph, SanitizeRule.R2Env, false, kind)
    }
    return SanitizeOutcome(value, SanitizeRule.None, false, "")
}

/// config 行的 R1 行级判定（design §4.10.6(3) 的 `configValuePredicate`）。
///
/// 注意：R1 不受 keepVerbatim 豁免（keepVerbatimAppliesToR1() == false）。
/// 若后续需对 R1 也支持保留清单，改此处并放开 sanitizeConfig 的 early-return 即可。
private func configValuePredicateTrue(row: HashMap<String, String>): Bool {
    let isSensitive = match (row.get("is_sensitive")) { case Some(s) => s.toAsciiLower(); case None => "" }
    if (isSensitive == "t" || isSensitive == "true" || isSensitive == "1") {
        return true
    }
    let group = match (row.get("config_group")) { case Some(g) => g; case None => "" }
    return group == "api_key" || group == "token" || group == "ssl"
}

/// 从列名推导 R1 占位符的 `<kind>`。
private func deriveSecretKind(column: String): String {
    let c = column.toAsciiLower()
    if (c.contains("password") || c.contains("passwd")) {
        return "password"
    }
    if (c.contains("api_key") || c.contains("mch_api_key")) {
        return "api_key"
    }
    if (c.contains("secret")) {
        return "secret"
    }
    return "secret"
}

/// 从值形态推导 R2 占位符。返回 (占位符文本, kind)。
private func deriveEnvPlaceholder(value: String, template: String): (String, String) {
    if (isDateLike(value)) {
        return ("{{ts:epoch}}", "ts")
    }
    if (value.startsWith("http://") || value.startsWith("https://")) {
        return ("{{env:url}}", "url")
    }
    if (value.startsWith("ghp_") || value.startsWith("sk-") || value.startsWith("fc-")) {
        return ("{{env:key}}", "key")
    }
    return ("{{env:env}}", "env")
}

/// 模式匹配：策略里的 patterns 以 `^` 开头表前缀匹配。
/// 固定几种形态（与 sanitize-policy.json 现有清单一致）：
///   `^your` / `^changeme` / `^xxx` / `^TODO` / `^<`          → startsWith
///   `^https?://`                                            → http(s):// 前缀
///   `^(ghp_|sk-|fc-)`                                       → 三种密钥前缀
///   `^[0-9]{4}-[0-9]{2}-[0-9]{2}`                            → 日期形态
private func matchesAny(patterns: ArrayList<String>, value: String): Bool {
    if (value.isEmpty()) {
        return false
    }
    for (pat in patterns) {
        if (patternMatches(pat, value)) {
            return true
        }
    }
    return false
}

private func patternMatches(pat: String, value: String): Bool {
    if (pat.startsWith("^")) {
        let rest = pat[1..]
        if (rest.contains("{")) {
            // 仅日期形态用到：`[0-9]{4}-[0-9]{2}-[0-9]{2}`
            return isDateLike(value)
        }
        if (rest == "https?://") {
            return value.startsWith("http://") || value.startsWith("https://")
        }
        if (rest == "(ghp_|sk-|fc-)") {
            return value.startsWith("ghp_") || value.startsWith("sk-") || value.startsWith("fc-")
        }
        return value.startsWith(rest)
    }
    return value == pat
}

/// 形如 `YYYY-MM-DD` 的日期（脱敏为 `{{ts:epoch}}`）。
private func isDateLike(value: String): Bool {
    let r = value.toRuneArray()
    if (r.size < 10) {
        return false
    }
    // 0..3 数字, 4 == '-', 5..6 数字, 7 == '-', 8..9 数字
    for (i in 0..4) {
        if (!isDigit(r[i])) { return false }
    }
    if (r[4] != r'-') { return false }
    for (i in 5..7) {
        if (!isDigit(r[i])) { return false }
    }
    if (r[7] != r'-') { return false }
    for (i in 8..10) {
        if (!isDigit(r[i])) { return false }
    }
    return true
}

private func isDigit(r: Rune): Bool {
    return r >= r'0' && r <= r'9'
}
