package uc_installer.services

// ============================================================================
// 环境自检的**唯一实现**（CLI 与 HTTP 两条通道共用）。
//
// 分层范式对齐 runtime 侧的 crudgen：
//   src/app/tools/crudgen/crudgen.cj        （命令行入口）
//   src/app/services/tool/CrudGenService.cj （CLI 与 Controller 共用的底座）
//   src/app/controllers/.../DbInfoController.cj（HTTP 封装，供 web 端调用）
// 即「能力只写一份，命令行直接调，HTTP 再包一层」。本项目对应：
//   src/cli/env_check.cj          （ucInstaller.exe check-environment）
//   src/services/envcheck.cj      （本文件：唯一实现）
//   src/http/handlers/env.cj      （GET /setup/check-environment 封装）
//
// 为什么底座在 `services` 而不是 `core`：包依赖边里已有 `core → cli`（ctx.cj 用
// CliArgs），`cli` 若反向 import `core` 即成环，仓颉拒绝构建。而 `services` 只依赖
// `platform` / `util`，`cli` 与 `http.handlers` 都够得着，且都不成环。
//
// 对应 AC-002（15 s 内返回三项、单项子进程 ≤5 s）与 AC-164（非 pass 项必带 fix）。
// ============================================================================

import std.collection.ArrayList
import uc_installer.platform.{probeDependency, probeMethodCode}

/// 环境自检的单个探测目标（依赖清单的一行）。
public struct EnvTarget {
    public let label: String
    /// 一级探测命令（版本命令）
    public let versionCmd: String
    public let versionArgs: Array<String>
    /// 二级探测端口（0 = 无端口可探）
    public let port: Int64
    /// 三级探测进程镜像名（空 = 无进程可探）
    public let image: String
    /// 是否阻断安装：true 缺失即失败；false 缺失仅降级（仍给 fix，不静默）
    public let required: Bool
    /// 缺失时的可执行修复指引
    public let hint: String

    public init(label: String, versionCmd: String, versionArgs: Array<String>,
                port: Int64, image: String, required: Bool, hint: String) {
        this.label = label
        this.versionCmd = versionCmd
        this.versionArgs = versionArgs
        this.port = port
        this.image = image
        this.required = required
        this.hint = hint
    }
}

/// 单项自检结果 = 探测事实 + 目标元信息，供两条通道各自渲染。
public struct EnvCheckItem {
    public let name: String
    public let reachable: Bool
    /// `ProbeMethod` 的编码串：version / port / process / none
    public let method: String
    public let version: String
    public let detail: String
    public let required: Bool
    public let hint: String

    public init(name: String, reachable: Bool, method: String, version: String,
                detail: String, required: Bool, hint: String) {
        this.name = name
        this.reachable = reachable
        this.method = method
        this.version = version
        this.detail = detail
        this.required = required
        this.hint = hint
    }
}

/// 整轮自检结果。
public struct EnvCheckResult {
    public let items: ArrayList<EnvCheckItem>
    /// 所有 required 项均可达才为 true
    public let ok: Bool
    /// 不可达的依赖名（含非必填项，便于报告里逐项列出）
    public let missing: ArrayList<String>

    public init(items: ArrayList<EnvCheckItem>, ok: Bool, missing: ArrayList<String>) {
        this.items = items
        this.ok = ok
        this.missing = missing
    }
}

/// 依赖清单（AC-002 口径的三项）。
///
/// `node` 标为非必填，依据 AC-033：安装器自身是原生二进制，`start-installer.bat`
/// 不得要求 Node/pnpm；Node 只被 DevKit 校验（DK-7，见 devkit/verify.cj:285）与
/// 服务监控（status.cj:48）用到，缺失不阻断安装，但**必须如实报 degraded 并给 fix**
/// ——不静默、也不冒充通过。
public func environmentTargets(): ArrayList<EnvTarget> {
    let ts = ArrayList<EnvTarget>()
    ts.add(EnvTarget("node", "node", ["--version"], 0, "node.exe", false,
        "安装 Node.js 20 LTS 并确保 node.exe 在 PATH 中（仅 DevKit 校验与服务监控需要，不阻断安装）"))
    ts.add(EnvTarget("postgresql", "psql", ["--version"], 5432, "postgres.exe", true,
        "安装 PostgreSQL 16 并启动服务，或确认 5432 端口可达；再执行 ucInstaller.exe check-environment 复检"))
    ts.add(EnvTarget("redis", "redis-cli", ["--version"], 6379, "redis-server.exe", true,
        "安装 Redis 并启动服务，或确认 6379 端口可达；再执行 ucInstaller.exe check-environment 复检"))
    return ts
}

/// 执行一轮环境自检。单项探测异常由 `probeDependency` 内部兜住（记为不可达），
/// 因此本函数不抛、不中断，永远返回完整三项。
public func checkEnvironment(): EnvCheckResult {
    let items = ArrayList<EnvCheckItem>()
    let missing = ArrayList<String>()
    var ok = true
    for (t in environmentTargets()) {
        let r = probeDependency(t.label, t.versionCmd, t.versionArgs, t.port, t.image)
        items.add(EnvCheckItem(t.label, r.reachable, probeMethodCode(r.method),
            r.version, r.detail, t.required, t.hint))
        if (!r.reachable) {
            missing.add(t.label)
            if (t.required) {
                ok = false
            }
        }
    }
    return EnvCheckResult(items, ok, missing)
}
