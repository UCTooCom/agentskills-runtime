package uc_installer.cli

import std.collection.ArrayList
import std.time.DateTime
import stdx.encoding.json.JsonValue
import uc_installer.util.{jstr, jint, jbool, jobj, jarr}

// 报告项状态（T004 / §4.11.1）
public let STATUS_PASS: String = "pass"
public let STATUS_FAIL: String = "fail"
public let STATUS_DEGRADED: String = "degraded"   // 降级：仍可用但已如实标记，禁止静默降级
public let STATUS_MANUAL: String = "manual"      // 待人工介入 / 待后续 Phase 实现
public let STATUS_SKIP: String = "skip"

// 退出码类别（§4.11.2，AC-163）
public let EXIT_OK: Int64 = 0
public let EXIT_GENERIC: Int64 = 1
public let EXIT_ARGS: Int64 = 2
public let EXIT_ENV: Int64 = 3
public let EXIT_NETWORK: Int64 = 4
public let EXIT_CHECKSUM: Int64 = 5
public let EXIT_MANUAL: Int64 = 6

/// 单个检查 / 步骤结果项。
/// 设计依据：§4.11.1 的 items[] 形态（id/status/actual/expected/fix）+ T004 的 degraded/diagnostics。
public class ReportItem {
    public var id: String = ""
    public var status: String = STATUS_PASS
    public var actual: String = ""
    public var expected: String = ""
    public var fix: String = ""          // 可执行修复命令或操作路径；status != pass 时必填（AC-164）
    public var code: Int64 = EXIT_OK     // 该项所属退出码类别；0 = 无失败
    public var degraded: Bool = false    // 降级标记（逐项可见，T004）
    public var diagnostics: String = ""

    public init() {}
}

/// 统一报告骨架（T004 / §4.11.1）。
/// 顶层含 items（检查项）/ steps（步骤项）/ diagnostics / remediation，供 DevKit 与 seed 各子命令复用。
public class Report {
    public var schema: String = "ucinstaller/report/v1"
    public var command: String = ""
    public var generatedAt: String = ""
    public var ok: Bool = true
    public var exitCode: Int64 = EXIT_OK
    public var truncated: Bool = false
    public var items: ArrayList<ReportItem> = ArrayList<ReportItem>()
    public var steps: ArrayList<ReportItem> = ArrayList<ReportItem>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()
    public var remediation: ArrayList<String> = ArrayList<String>()

    public init() {}
}

/// 加入一项到 items，并就地维护 ok / exitCode（§4.11.2：exitCode = max(所有非 0 类别码)）。
public func addItem(report: Report, item: ReportItem): Unit {
    report.items.add(item)
    reconcile(report)
}

/// 加入一项到 steps（步骤），同样参与 exitCode 汇聚。
public func addStep(report: Report, item: ReportItem): Unit {
    report.steps.add(item)
    reconcile(report)
}

/// 维护 ok 与 exitCode：取 items/steps 中非 0 类别码的最大值；全 0 则 ok = true。
func reconcile(report: Report): Unit {
    var maxCode: Int64 = EXIT_OK
    for (it in report.items) {
        if (it.code > maxCode) { maxCode = it.code }
    }
    for (st in report.steps) {
        if (st.code > maxCode) { maxCode = st.code }
    }
    report.exitCode = maxCode
    report.ok = (maxCode == EXIT_OK)
}

/// 序列化 §4.11.1 形态的 JsonValue（pretty 多行，符合该节示例；stdout 仅承载此结构，AC-162）。
public func toJson(report: Report): JsonValue {
    let root = jobj()
    root.put("schema", jstr(report.schema))
    root.put("command", jstr(report.command))
    root.put("generatedAt", jstr(report.generatedAt))
    root.put("ok", jbool(report.ok))
    root.put("exitCode", jint(report.exitCode))
    root.put("truncated", jbool(report.truncated))

    let itemsArr = jarr()
    for (it in report.items) {
        itemsArr.add(itemToJson(it))
    }
    root.put("items", itemsArr)

    let stepsArr = jarr()
    for (st in report.steps) {
        stepsArr.add(itemToJson(st))
    }
    root.put("steps", stepsArr)

    let diagArr = jarr()
    for (d in report.diagnostics) {
        diagArr.add(jstr(d))
    }
    root.put("diagnostics", diagArr)

    let remArr = jarr()
    for (r in report.remediation) {
        remArr.add(jstr(r))
    }
    root.put("remediation", remArr)

    return root
}

func itemToJson(it: ReportItem): JsonValue {
    let o = jobj()
    o.put("id", jstr(it.id))
    o.put("status", jstr(it.status))
    o.put("actual", jstr(it.actual))
    o.put("expected", jstr(it.expected))
    o.put("fix", jstr(it.fix))
    o.put("code", jint(it.code))
    o.put("degraded", jbool(it.degraded))
    o.put("diagnostics", jstr(it.diagnostics))
    return o
}

/// 构造一个"失败 / 待人工"报告（参数错误、未实现等），符合 §4.11.1 + AC-164（fix 必填）。
public func failureReport(command: String, id: String, actual: String, expected: String, fix: String, code: Int64): Report {
    let r = Report()
    r.command = command
    let it = ReportItem()
    it.id = id
    // 仓颉 if 表达式必须带花括号：if (cond) { exprs1 } else { exprs2 }，裸单分支不合法
    it.status = if (code == EXIT_MANUAL) { STATUS_MANUAL } else { STATUS_FAIL }
    it.actual = actual
    it.expected = expected
    it.fix = fix
    it.code = code
    r.items.add(it)
    reconcile(r)
    return r
}

/// 输出报告：
///   --json 时 stdout 仅输出 JSON（诊断走 stderr，绝不混入，AC-162/AC-165）；
///   否则 stdout 输出人读摘要。
public func emitReport(report: Report, asJson: Bool): Unit {
    if (report.generatedAt.isEmpty()) {
        report.generatedAt = DateTime.now().format("yyyy-MM-dd HH:mm:ss")
    }
    if (asJson) {
        println(toJson(report).toJsonString())
    } else {
        emitHuman(report)
    }
}

func emitHuman(report: Report): Unit {
    println("command : ${report.command}")
    println("ok      : ${report.ok}")
    println("exitCode: ${report.exitCode}")
    if (!report.items.isEmpty()) {
        println("items:")
        for (it in report.items) {
            println("  [${it.status}] ${it.id} :: ${it.actual}")
            if (!it.fix.isEmpty()) {
                println("      fix: ${it.fix}")
            }
        }
    }
    if (!report.steps.isEmpty()) {
        println("steps:")
        for (st in report.steps) {
            println("  [${st.status}] ${st.id} :: ${st.actual}")
            if (!st.fix.isEmpty()) {
                println("      fix: ${st.fix}")
            }
        }
    }
    if (!report.diagnostics.isEmpty()) {
        println("diagnostics:")
        for (d in report.diagnostics) {
            println("  - ${d}")
        }
    }
}
