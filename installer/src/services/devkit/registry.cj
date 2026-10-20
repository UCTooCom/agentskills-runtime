package uc_installer.services.devkit

// DK-1~DK-8 组件注册表（spec.md §6.5 / design.md §4.10.1，任务 T035）。
//
// 本文件只放**声明**与**纯判据**：组件元数据、自检函数签名、期望值、修复命令。
// 不做安装动作（那是 install.cj），不做子进程调用（判据里的探测由调用方注入结果）。
//
// 字段严格对齐 spec.md §6.5 的九项：标识 / 必需性档位 / 体量预估 / 自检判据 /
// 推荐标记 / 推荐理由 / 安装状态 / 组件间依赖 / SDK 校验和。
//
// DK-4 判据是**三条**（表数一致 + 身份列悬空引用数 0 + 超管菜单树非空），
// 不是"表数 ≈ 207"——后者是 2026-10-07 前的旧口径，已被design §4.10.1 修订。

import std.collection.{ArrayList, HashMap}

// ===================== 文件级常量 =====================
//
// 顶层 `let` 是运行时初始化：跨文件引用时依赖**文件加载顺序**，同包内不可靠
// （install.cj 字典序在 registry.cj 之前，却要用这里的常量）。
// 故凡是被同包其他文件引用的顶层变量，一律提到文件头部。

/// DK-3 的 git 仓库地址集合（design.md §4.10.1.1）。
///
/// 主地址为 atomgit，镜像为 github。**只做 clone/fetch，绝不丢弃开发者改动**（R-22）。
public let DEVKIT_REPO_PRIMARY: String = "https://atomgit.com/UCToo/agentskills-runtime"
public let DEVKIT_REPO_MIRROR: String = "https://github.com/UCTooCom/agentskills-runtime.git"

/// 必需性档位（spec.md §6.5-2）。
public enum ReqTier {
    | Required
    | Recommended
    | Optional
}

public func reqTierCode(t: ReqTier): String {
    match (t) {
        case ReqTier.Required => return "required"
        case ReqTier.Recommended => return "recommended"
        case ReqTier.Optional => return "optional"
    }
}

/// 安装状态（spec.md §6.5-7）。
public enum DevkitStatus {
    | NotInstalled
    | Installing
    | Installed
    | Failed
    | RolledBack
}

public func devkitStatusCode(s: DevkitStatus): String {
    match (s) {
        case DevkitStatus.NotInstalled => return "notInstalled"
        case DevkitStatus.Installing => return "installing"
        case DevkitStatus.Installed => return "installed"
        case DevkitStatus.Failed => return "failed"
        case DevkitStatus.RolledBack => return "rolledBack"
    }
}

/// 单项自检结果（spec.md §6.5 的 AC-133 五字段：标识/状态/实际值/期望值/修复建议）。
public struct DevkitCheck {
    public let id: String
    public let passed: Bool
    public let actual: String
    public let expected: String
    public let fix: String

    public init(id: String, passed: Bool, actual: String, expected: String, fix: String) {
        this.id = id
        this.passed = passed
        this.actual = actual
        this.expected = expected
        this.fix = fix
    }
}

/// 一个DK 组件的注册信息。
///
/// 用 class 而非 struct：注册表构建时会先建对象再逐字段填充（spec §6.5 有九个字段），
/// class 在 let 绑定下即可改成员，struct 需var 绑定（语言文档 struct §2.2）。
public class DevkitComponent {
    public let id: String
    public let title: String
    public let tier: ReqTier
    /// 体量预估，单位统一为 MB（spec.md §6.5-3）；DK-1 另在 install 说明里给解压后体积。
    public let sizeMb: Int64
    /// 期望值描述（AC-133 字段 4）。
    public let expected: String
    /// 修复命令（AC-134 要求未通过时非空）。
    public let fixCmd: String
    /// 前置依赖组件 id 列表（spec.md §6.5-8）。
    public let deps: ArrayList<String>
    /// SDK 类组件必须携带官方校验和（spec.md §6.5-9）；其余组件为 None。
    public let sha256: Option<String>
    /// 推荐标记（spec.md §6.5-5），由环境探测结果推导，故可写。
    public var recommended: Bool
    /// 推荐理由（spec.md §6.5-6），必须含探测到的实际值。
    public var reason: String
    /// 安装状态（spec.md §6.5-7）。
    public var status: DevkitStatus

    public init(id: String, title: String, tier: ReqTier, sizeMb: Int64, expected: String,
                fixCmd: String, deps: ArrayList<String>, sha256: Option<String>) {
        this.id = id
        this.title = title
        this.tier = tier
        this.sizeMb = sizeMb
        this.expected = expected
        this.fixCmd = fixCmd
        this.deps = deps
        this.sha256 = sha256
        this.recommended = true
        this.reason = ""
        this.status = DevkitStatus.NotInstalled
    }
}

/// 目标目录在 clone 前的三分状态（design.md §4.10.1.1 (3)）。
public enum DevSourceState {
    /// 路径不存在 → 直接 clone。
    | Absent
    /// 目录存在且为空 → clone 到该目录。
    | Empty
    /// 是本仓库且 remote 匹配 → fetch 复用。
    | Reusable
    /// 是其它 git 仓库 → 默认拒绝。
    | ForeignRepo
    /// 非 git 目录 → 默认拒绝（允许在其下新建子层再 clone）。
    | NotARepo
}

public func devSourceStateCode(s: DevSourceState): String {
    match (s) {
        case DevSourceState.Absent => return "absent"
        case DevSourceState.Empty => return "empty"
        case DevSourceState.Reusable => return "reusable"
        case DevSourceState.ForeignRepo => return "foreignRepo"
        case DevSourceState.NotARepo => return "notARepo"
    }
}

/// 判定该状态是否可以直接 clone / fetch（False 表示必须拒绝并换目录）。
public func devSourceStateAcceptable(s: DevSourceState): Bool {
    match (s) {
        case DevSourceState.Absent => return true
        case DevSourceState.Empty => return true
        case DevSourceState.Reusable => return true
        case DevSourceState.ForeignRepo => return false
        case DevSourceState.NotARepo => return false
    }
}

/// 由字面量构造依赖表。
///
/// 形参收`ArrayList<String>` 而非 `Array<String>`：`Array<String>()` 是**定长**数组，
/// 其构造器签名是 `Array<T>(Int64, (Int64) -> T)`，不吃集合字面量（传 `["a"]` 会报
/// "missing argument… expected 2 arguments, found 1"）。`ArrayList<String>([...])` 才是
/// 宿主通用写法（例：`src/tool/sub_agent_contract_verifier.cj:65`）。
private func depsOf(ids: ArrayList<String>): ArrayList<String> {
    let out = ArrayList<String>()
    for (d in ids) {
        out.add(d)
    }
    return out
}

private func noSha(): Option<String> {
    return None<String>
}

/// DK-1~DK-8 的注册表（design.md §4.10.1 表，含体量预估 / 判据 / 期望值 / 修复命令）。
///
/// 依赖关系（spec.md §6.5-8）按"能独立安装、可后续补齐"的原则：
///   DK-3（源码树）是 DK-5（loaddbinfo）、DK-6（知识库）、DK-7（前端）的前提；
///   DK-4（数据库基线）独立；DK-1（SDK）是 DK-5/DK-6 的环境前提但**不强制**，
///   因为标准库与知识库均可离线取（AC-143）。
public func devkitRegistry(): ArrayList<DevkitComponent> {
    let list = ArrayList<DevkitComponent>()

    // DK-1仓颉 SDK：安装器只做下载引导 + SHA256 校验，绝不内置 SDK 交付物（AC-139）。
    list.add(DevkitComponent("DK-1", "仓颉 SDK（cjc/cjpm 1.1.3）", ReqTier.Required, 374,
        "cjc --version、cjpm --version、where cjc 三条输出均含 1.1.3",
        "ucInstaller.exe devkit install DK-1 --sdk-path <本地包>",
        depsOf(ArrayList<String>()), noSha()))

    // DK-2 vendored stdx + OpenSSL DLL：文件名写死为 libcrypto-3-x64/libssl-3-x64（design §4.10.1）。
    list.add(DevkitComponent("DK-2", "vendored stdx + OpenSSL DLL", ReqTier.Required, 30,
        "stdx 动态库目录非空，且 bin/ 下 libcrypto-3-x64.dll 与 libssl-3-x64.dll 同时存在",
        "copy libs\\cangjie-stdx-windows-x64-1.1.3.1\\windows_x86_64_cjnative\\dynamic\\stdx\\*.dll <binDir>",
        depsOf(ArrayList<String>()), noSha()))

    // DK-3 源码树：**唯一路径 git clone**，无离线兜底（R-22）。
    list.add(DevkitComponent("DK-3", "源码工作副本（git clone）", ReqTier.Required, 0,
        ".git/ 存在；cjpm.toml 的 cjc-version = 1.1.3；libs/cordis-cj/ 存在；git remote origin 属预期集合",
        "ucInstaller.exe devkit install DK-3 --source-dir <开发者自选目录>",
        depsOf(ArrayList<String>()), noSha()))

    // DK-4 数据库基线：判据是**三条**，不是"表数 ≈207"（design §4.10.1 已修订）。
    list.add(DevkitComponent("DK-4", "数据库基线（建库 + 导入 +增量）", ReqTier.Required, 0,
        "public 表数与 seed-manifest.json 一致；身份列悬空引用数 = 0；超管菜单树非空",
        "psql -U postgres -d uctoo -f sql/uctooDB.sql",
        depsOf(ArrayList<String>()), noSha()))

    // DK-5 loaddbinfo：脚手架随源码树，无需额外安装，只需跑一次。
    list.add(DevkitComponent("DK-5", "db_info 元数据（loaddbinfo）", ReqTier.Required, 0,
        "db_info 行数 > 0 且覆盖 seed-manifest.json 声明的表数",
        "cjpm run --skip-build --name magic.app.tools.loaddbinfo --run-args \"--db uctoo\"",
        depsOf(ArrayList<String>(["DK-3", "DK-4"])), noSha()))

    // DK-6 标准库 API 知识库：离线 19.1 MB / 7822文件。
    list.add(DevkitComponent("DK-6", "标准库 API 知识库（CangjieSkills）", ReqTier.Recommended, 20,
        "search_docs.py --query \"cjpm build\" 返回非空且退出码 0",
        "python skills/CangjieSkills/scripts/search_docs.py --query \"cjpm build\"",
        depsOf(ArrayList<String>(["DK-3"])), noSha()))

    // DK-7 web-admin 前端：Node 端到端联调。
    list.add(DevkitComponent("DK-7", "web-admin 前端工程（pnpm）", ReqTier.Optional, 0,
        "node -v >= 14；pnpm -v 可解析；node scripts/check-vue-refs.cjs src/views/ai/ 退出码 0",
        "pnpm install && pnpm prebuild",
        depsOf(ArrayList<String>(["DK-3"])), noSha()))

    // DK-8 VS Code 扩展。
    list.add(DevkitComponent("DK-8", "Cangjie VS Code 扩展", ReqTier.Optional, 6,
        "VS Code 扩展目录中存在 Cangjie 扩展",
        "code --install-extension cangjie-vscode-1.1.3.tar.gz",
        depsOf(ArrayList<String>()), noSha()))

    return list
}

/// 按 id 取单个组件；不存在返回 None（不抛异常，调用方按缺失处理）。
public func devkitComponentById(id: String): Option<DevkitComponent> {
    for (c in devkitRegistry()) {
        if (c.id == id) {
            return Some(c)
        }
    }
    return None<DevkitComponent>
}

/// 依赖闭包：返回安装某组件前必须先装好的组件 id 集合（含自身，用于错误提示）。
///
/// 只做**直接依赖**的传递闭包，不做循环检测——注册表是无环的固定表（spec §6.5-8）。
public func devkitDepsClosure(id: String): ArrayList<String> {
    let seen = ArrayList<String>()
    let queue = ArrayList<String>()
    queue.add(id)
    while (!queue.isEmpty()) {
        let cur = queue.remove(at: 0)
        if (seen.contains(cur)) {
            continue
        }
        seen.add(cur)
        match (devkitComponentById(cur)) {
            case Some(c) =>
                for (d in c.deps) {
                    queue.add(d)
                }
            case None => ()
        }
    }
    return seen
}

/// 校验某组件的前置依赖是否都已安装；缺失时返回缺失清单（AC-137 前置条件）。
///
/// 状态查询由调用方注入（形参类型 `(String) -> Bool` 即"按 id 查是否已安装"），
/// 本包不反向依赖 core去读 StateStore——core 的 orchestrator 已依赖 services，
/// 反向 import 会形成循环依赖（cjpm 直接拒绝构建）。
public func devkitMissingDeps(isInstalled: (String) -> Bool, id: String): ArrayList<String> {
    let missing = ArrayList<String>()
    match (devkitComponentById(id)) {
        case Some(c) =>
            for (d in c.deps) {
                if (!isInstalled(d)) {
                    missing.add(d)
                }
            }
        case None => ()
    }
    return missing
}

/// DevKit 总体量预估（MB），用于 DK 入口的磁盘空间闸口（AC-144）。
public func devkitTotalSizeMb(): Int64 {
    var total = 0
    for (c in devkitRegistry()) {
        total += c.sizeMb
    }
    return total
}

/// 逐组件体量预估的可读清单（AC-144 要求「逐组件给出体量预估与所需总量」）。
public func devkitSizeBreakdown(): HashMap<String, Int64> {
    let m = HashMap<String, Int64>()
    for (c in devkitRegistry()) {
        m[c.id] = c.sizeMb
    }
    return m
}
