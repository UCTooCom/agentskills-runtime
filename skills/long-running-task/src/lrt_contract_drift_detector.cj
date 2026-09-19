/*
 * LrtContractDriftDetector（long-running-task / Ch14.3）
 * 数据契约漂移检测（spec 5.16.3 规则 7）
 *
 * 比对 DATA_CONTRACT.yaml 声明的表结构与 db_schema_lookup 返回的实际结构，
 * 不一致时产出 DriftFinding 列表，并经 LrtEventEmitter 推送告警。
 *
 * 比对维度：
 *   1. 表缺失：契约声明了但 DB 里没有（或查不到）
 *   2. 列缺失/多余：契约有列 DB 没有，或 DB 有列契约没有
 *   3. 类型不一致：契约声明 type=uuid，DB 实际是 text
 *   4. nullable 不一致：契约 required=true 但 DB nullable=YES
 *
 * 告警出口（spec 5.16.3）：检测到 drift 时经 LrtEventEmitter.emit 推送
 * "contract_drift" 事件。事件是观测面，上报失败不阻断检测流程。
 *
 * 编码依据：
 *   - YAML 解析：lrt_composition_runner.cj 的 yaml4cj.yaml.decode + StdJsonValue 模式
 *   - host 调用：lrt_composition_runner.cj 的 ctx.invoke<JsonValue, JsonValue> 模式
 *   - ctx 获取：LrtPersistService.currentCtx()（与 buildContractBlock 同源）
 *   - 事件推送：LrtEventEmitter.emit（新增 contract_drift 事件类型）
 */
package skill_long_running_task

import std.collection.{ArrayList, HashMap}
import std.fs.{File, Path, exists}
import ystyle::cordis_plugin.PluginContext
import stdx.encoding.json.{JsonValue as StdJsonValue, JsonObject, JsonKind}
import yaml4cj.yaml.decode
import jsonvalue.*

/// 漂移严重级别
public enum DriftSeverity <: Equatable<DriftSeverity> {
    | Error
    | Warning

    public operator func ==(right: DriftSeverity): Bool {
        match ((this, right)) {
            case (DriftSeverity.Error, DriftSeverity.Error) => true
            case (DriftSeverity.Warning, DriftSeverity.Warning) => true
            case _ => false
        }
    }

    public operator func !=(right: DriftSeverity): Bool {
        return !(this == right)
    }
}

public func driftSeverityToString(s: DriftSeverity): String {
    match (s) {
        case DriftSeverity.Error => "error"
        case DriftSeverity.Warning => "warning"
    }
}

/// 单条漂移发现
public class DriftFinding {
    public var table: String = ""
    public var field: String = ""
    public var findingType: String = ""
    public var expected: String = ""
    public var actual: String = ""
    public var severity: DriftSeverity = DriftSeverity.Error

    public init() {}
}

/// 契约中单表的列声明（从 DATA_CONTRACT.yaml 解析）
private class ContractColumn {
    var name: String = ""
    var colType: String = ""
    var required: Bool = false

    init() {}
}

/// 契约中单表声明
private class ContractTable {
    var name: String = ""
    var columns: ArrayList<ContractColumn> = ArrayList<ContractColumn>()

    init() {}
}

public class LrtContractDriftDetector {
    private let _skillDir: String

    public init(skillDir: String) {
        _skillDir = skillDir
    }

    /// 执行漂移检测，返回所有发现的不一致项。
    /// best-effort：任一表查询失败跳过该表，不阻断整体检测。
    public func detect(): ArrayList<DriftFinding> {
        let findings = ArrayList<DriftFinding>()
        let tables = this.loadContractTables()
        if (tables.isEmpty()) {
            eprintln("[LrtContractDriftDetector] DATA_CONTRACT.yaml 未声明任何表，跳过漂移检测")
            return findings
        }
        match (LrtPersistService.currentCtx()) {
            case None =>
                eprintln("[LrtContractDriftDetector] 无 ctx，跳过漂移检测")
                return findings
            case Some(ctx) =>
                for (ct in tables) {
                    let actual = this.lookupSchema(ctx, ct.name)
                    match (actual) {
                        case Some(schema) =>
                            this.compareTable(ct, schema, findings)
                        case None =>
                            let f = DriftFinding()
                            f.table = ct.name
                            f.field = ""
                            f.findingType = "table_missing"
                            f.expected = "表存在"
                            f.actual = "查不到或查询失败"
                            f.severity = DriftSeverity.Error
                            findings.add(f)
                    }
                }
        }
        return findings
    }

    /// 检测并推送告警事件。返回发现列表。
    /// 事件推送失败不阻断（LrtEventEmitter 内部已吞异常）。
    public func detectAndAlert(
        taskId: String, sessionId: String, agentId: String, traceId: String
    ): ArrayList<DriftFinding> {
        let findings = this.detect()
        if (findings.isEmpty()) {
            return findings
        }
        this.emitDriftAlert(findings, taskId, sessionId, agentId, traceId)
        return findings
    }

    // ── 契约解析 ───────────────────────────────────────────────────

    /// 从 DATA_CONTRACT.yaml 解析出表声明列表
    private func loadContractTables(): ArrayList<ContractTable> {
        let result = ArrayList<ContractTable>()
        let path = Path(_skillDir).join("DATA_CONTRACT.yaml").toString()
        if (!exists(path)) {
            eprintln("[LrtContractDriftDetector] DATA_CONTRACT.yaml not found: ${path}")
            return result
        }
        try {
            let bytes = File.readFrom(path)
            let content = String.fromUtf8(bytes)
            let parsed = decode(content.toArray())
            if (!(parsed is JsonObject)) {
                eprintln("[LrtContractDriftDetector] DATA_CONTRACT.yaml root is not a mapping")
                return result
            }
            let root = (parsed as JsonObject).getOrThrow()
            match (root.get("tables")) {
                case Some(tablesVal) =>
                    match (tablesVal.kind()) {
                        case JsonKind.JsArray =>
                            for (item in tablesVal.asArray().getItems()) {
                                match (item.kind()) {
                                    case JsonKind.JsObject =>
                                        match (this.parseContractTable(item.asObject())) {
                                            case Some(ct) => result.add(ct)
                                            case None => ()
                                        }
                                    case _ => ()
                                }
                            }
                        case _ => ()
                    }
                case None => ()
            }
        } catch (e: Exception) {
            eprintln("[LrtContractDriftDetector] 解析 DATA_CONTRACT.yaml 失败: ${e.message}")
        }
        return result
    }

    private func parseContractTable(obj: JsonObject): Option<ContractTable> {
        let ct = ContractTable()
        ct.name = this.optString(obj, "name")
        if (ct.name.isEmpty()) {
            return None
        }
        match (obj.get("columns")) {
            case Some(colsVal) =>
                match (colsVal.kind()) {
                    case JsonKind.JsArray =>
                        for (colItem in colsVal.asArray().getItems()) {
                            match (colItem.kind()) {
                                case JsonKind.JsObject =>
                                    let col = ContractColumn()
                                    let colObj = colItem.asObject()
                                    col.name = this.optString(colObj, "name")
                                    col.colType = this.optString(colObj, "type")
                                    col.required = this.optBool(colObj, "required")
                                    if (!col.name.isEmpty()) {
                                        ct.columns.add(col)
                                    }
                                case _ => ()
                            }
                        }
                    case _ => ()
                }
            case None => ()
        }
        return Some(ct)
    }

    // ── 实际结构查询 ───────────────────────────────────────────────

    /// 调 host.db_schema_lookup 取表结构，返回 JsonValue.Map 或 None
    private func lookupSchema(ctx: PluginContext, table: String): Option<JsonValue> {
        let args = HashMap<String, JsonValue>()
        args["table"] = JsonValue.String(table)
        let invokeArgs = Array<JsonValue>(1, { _ => JsonValue.Null })
        invokeArgs[0] = JsonValue.from(args)
        try {
            let raw = ctx.invoke<JsonValue, JsonValue>(
                "host.db_schema_lookup", "lookup", invokeArgs)
            match (raw) {
                case JsonValue.Map(_) => return Some(raw)
                case _ => return None
            }
        } catch (e: Exception) {
            eprintln("[LrtContractDriftDetector] 查表 '${table}' 结构失败: ${e}")
            return None
        }
    }

    // ── 比对 ───────────────────────────────────────────────────────

    /// 比对单表：契约声明 vs DB 实际
    private func compareTable(
        ct: ContractTable,
        actual: JsonValue,
        findings: ArrayList<DriftFinding>
    ): Unit {
        match (actual) {
            case JsonValue.Map(f) =>
                let actualCols = this.extractActualColumns(f)
                let actualColNames = HashMap<String, Bool>()
                for (ac in actualCols) {
                    actualColNames.add(ac.name, true)
                }
                let contractColNames = HashMap<String, Bool>()
                for (cc in ct.columns) {
                    contractColNames.add(cc.name, true)
                }
                for (cc in ct.columns) {
                    var found: Option<ActualColumn> = None
                    for (ac in actualCols) {
                        if (ac.name == cc.name) {
                            found = Some(ac)
                            break
                        }
                    }
                    match (found) {
                        case Some(ac) =>
                            this.compareColumn(ct.name, cc, ac, findings)
                        case None =>
                            let f = DriftFinding()
                            f.table = ct.name
                            f.field = cc.name
                            f.findingType = "column_missing_in_db"
                            f.expected = "列 ${cc.name} 存在（类型 ${cc.colType}）"
                            f.actual = "DB 中无此列"
                            f.severity = DriftSeverity.Error
                            findings.add(f)
                    }
                }
                for (ac in actualCols) {
                    match (contractColNames.get(ac.name)) {
                        case None =>
                            let f = DriftFinding()
                            f.table = ct.name
                            f.field = ac.name
                            f.findingType = "column_missing_in_contract"
                            f.expected = "契约未声明此列"
                            f.actual = "DB 有列 ${ac.name}（类型 ${ac.colType}）"
                            f.severity = DriftSeverity.Warning
                            findings.add(f)
                        case _ => ()
                    }
                }
            case _ =>
                let f = DriftFinding()
                f.table = ct.name
                f.field = ""
                f.findingType = "schema_format_error"
                f.expected = "JsonMap"
                f.actual = "格式异常"
                f.severity = DriftSeverity.Error
                findings.add(f)
        }
    }

    /// 比对单列：类型 + nullable
    private func compareColumn(
        table: String,
        contractCol: ContractColumn,
        actualCol: ActualColumn,
        findings: ArrayList<DriftFinding>
    ): Unit {
        let contractType = this.normalizeType(contractCol.colType)
        let actualType = this.normalizeType(actualCol.colType)
        if (contractType != actualType && !contractType.isEmpty() && !actualType.isEmpty()) {
            let f = DriftFinding()
            f.table = table
            f.field = contractCol.name
            f.findingType = "type_mismatch"
            f.expected = contractCol.colType
            f.actual = actualCol.colType
            f.severity = DriftSeverity.Error
            findings.add(f)
        }
        let actualNullable = actualCol.nullable
        if (contractCol.required && actualNullable) {
            let f = DriftFinding()
            f.table = table
            f.field = contractCol.name
            f.findingType = "nullable_mismatch"
            f.expected = "required=true（NOT NULL）"
            f.actual = "DB nullable=YES"
            f.severity = DriftSeverity.Error
            findings.add(f)
        }
    }

    /// 类型归一化：去掉长度修饰（varchar(100) -> varchar, numeric -> numeric）
    /// 用于宽松比对——契约写 varchar(100)，DB 返回 character varying(100)，
    /// 归一后都按基类型比对，避免长度差异误报。
    private func normalizeType(t: String): String {
        let lower = t.trimAscii().toAsciiLower()
        if (lower.startsWith("character varying")) {
            return "varchar"
        }
        if (lower.startsWith("timestamp")) {
            return "timestamptz"
        }
        let paren = match (lower.indexOf("(")) {
            case Some(idx) => idx
            case None => -1
        }
        if (paren >= 0) {
            return lower[0..paren]
        }
        return lower
    }

    // ── 实际结构提取 ───────────────────────────────────────────────

    private func extractActualColumns(f: HashMap<String, JsonValue>): ArrayList<ActualColumn> {
        let result = ArrayList<ActualColumn>()
        match (f.get("columns")) {
            case Some(JsonValue.Array(cols)) =>
                for (c in cols) {
                    match (c) {
                        case JsonValue.Map(cm) =>
                            let ac = ActualColumn()
                            ac.name = this.strField(cm, "name")
                            ac.colType = this.strField(cm, "type")
                            ac.nullable = this.strField(cm, "nullable").toAsciiLower() == "yes"
                            if (!ac.name.isEmpty()) {
                                result.add(ac)
                            }
                        case _ => ()
                    }
                }
            case _ => ()
        }
        return result
    }

    // ── 告警推送 ───────────────────────────────────────────────────

    /// 经 LrtEventEmitter 推送 contract_drift 事件
    private func emitDriftAlert(
        findings: ArrayList<DriftFinding>,
        taskId: String, sessionId: String, agentId: String, traceId: String
    ): Unit {
        let extra = HashMap<String, JsonValue>()
        let findingArr = ArrayList<JsonValue>()
        for (f in findings) {
            let obj = HashMap<String, JsonValue>()
            obj["table"] = JsonValue.String(f.table)
            obj["field"] = JsonValue.String(f.field)
            obj["type"] = JsonValue.String(f.findingType)
            obj["expected"] = JsonValue.String(f.expected)
            obj["actual"] = JsonValue.String(f.actual)
            obj["severity"] = JsonValue.String(driftSeverityToString(f.severity))
            findingArr.add(JsonValue.from(obj))
        }
        extra["findings"] = JsonValue.Array(findingArr)
        extra["count"] = JsonValue.Number(Float64(findings.size))
        LrtEventEmitter.emitContractDrift(
            taskId, sessionId, agentId, traceId, extra)
        let summary = StringBuilder()
        summary.append("[LrtContractDriftDetector] 检测到 ${findings.size} 处契约漂移:\n")
        for (f in findings) {
            summary.append("  [${driftSeverityToString(f.severity)}] ${f.table}.${f.field}"
                + " ${f.findingType}: expected=${f.expected}, actual=${f.actual}\n")
        }
        eprintln(summary.toString())
    }

    // ── JSON 取值小工具 ───────────────────────────────────────────

    private func optString(obj: JsonObject, key: String): String {
        match (obj.get(key)) {
            case Some(v) => this.scalarToString(v)
            case None => ""
        }
    }

    private func optBool(obj: JsonObject, key: String): Bool {
        match (obj.get(key)) {
            case Some(v) =>
                match (v.kind()) {
                    case JsonKind.JsBool => v.asBool().getValue()
                    case _ => false
                }
            case None => false
        }
    }

    private func scalarToString(v: StdJsonValue): String {
        match (v.kind()) {
            case JsonKind.JsString => v.asString().getValue()
            case JsonKind.JsInt => v.asInt().getValue().toString()
            case JsonKind.JsFloat => v.asFloat().getValue().toString()
            case JsonKind.JsBool => v.asBool().getValue().toString()
            case JsonKind.JsNull => ""
            case _ => v.toString()
        }
    }

    private func strField(m: HashMap<String, JsonValue>, key: String): String {
        match (m.get(key)) {
            case Some(JsonValue.String(s)) => s
            case _ => ""
        }
    }
}

/// DB 实际列结构（从 host.db_schema_lookup 返回解析）
private class ActualColumn {
    var name: String = ""
    var colType: String = ""
    var nullable: Bool = false

    init() {}
}