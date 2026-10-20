package uc_installer.cli

// ============================================================================
// `check-environment` 子命令（命令行入口层）。
//
// 分层：本文件只做「探测结果 → §4.11.1 报告形态」的翻译，探测本身在
// `services/envcheck.cj`（与 HTTP 端点 `GET /setup/check-environment` 共用同一实现）。
//
// 契约：
//   - 每项都带 actual / expected / fix（AC-021 / AC-164）
//   - 必填项不可达 → fail，exitCode = EXIT_ENV(3)
//   - 非必填项不可达 → degraded（如实标记，不静默、不冒充通过），exitCode 仍为 0
//   - --json 下 stdout 只有 JSON，诊断走 diagnostics 字段（AC-162）
// ============================================================================

import uc_installer.services.checkEnvironment

/// 环境自检：`ucInstaller.exe [--json] check-environment`
public func runCheckEnvironment(parsed: CliArgs): Report {
    let report = Report()
    report.command = "check-environment"

    if (parsed.offline) {
        report.diagnostics.add("离线模式：环境自检只做本机探测，不访问网络")
    }

    let res = checkEnvironment()

    for (it in res.items) {
        // 仓颉 if/else 作表达式必须带花括号，故先声明后赋值
        var status = STATUS_PASS
        var actual = ""
        var fix = ""
        var code: Int64 = EXIT_OK
        if (it.reachable) {
            status = STATUS_PASS
            if (it.version.isEmpty()) {
                actual = "可达（探测手段=${it.method}，细节=${it.detail}）"
            } else {
                actual = "${it.version}（探测手段=${it.method}）"
            }
        } else if (it.required) {
            status = STATUS_FAIL
            code = EXIT_ENV
            actual = "不可达（${it.detail}）"
            fix = it.hint
        } else {
            status = STATUS_DEGRADED
            actual = "不可达（${it.detail}）"
            fix = it.hint
        }

        // 记下写入前的下标，便于把 degraded 标记补到刚加入的这一项上
        let at = report.items.size
        addCheck(report, "env.${it.name}", status, actual,
            "版本命令 / 端口 / 进程 任一命中即为可达", fix, code)
        if (status == STATUS_DEGRADED) {
            report.items[at].degraded = true
        }
    }

    for (m in res.missing) {
        report.remediation.add("补齐依赖 ${m} 后重跑：ucInstaller.exe check-environment")
    }
    if (!res.ok) {
        report.diagnostics.add("存在必填依赖不可达：${res.missing.size} 项，安装将阻断")
    }

    return report
}
