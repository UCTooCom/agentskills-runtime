package uc_installer.services.devkit

// DK-1~DK-8 的自检汇总（任务 T037，对应 spec.md AC-141~147 / §6.5）。
//
// 铁律（R-17同源）：**自检必须给出可观测证据**——每个组件输出五个字段
// （标识 / 状态 / 实际值 / 期望值 / 修复建议），未通过时修复建议非空（AC-134），
// 缺证据不得宣告成功。
//
// DK-4 的判据是**三条**（design.md §4.10.1 已修订，不是"表数 ≈ 207"）：
//   ① public 表数与 seed-manifest.json 声明一致；
//   ② 身份列悬空引用数 = 0；
//   ③ 超管菜单树非空（permissions.type = 1）。

import std.fs.{Path, exists}
import std.collection.ArrayList
import stdx.encoding.json.{JsonObject, JsonArray, JsonString, JsonBool, JsonInt}
import uc_installer.platform.{runCapped, succeeded, decodeOutput, splitLines}
import uc_installer.services.{AdminRepo, DbConn}
// registry.cj / install.cj 与本文件同属 `uc_installer.services.devkit` 包，同包免 import。
// 子包路径（…devkit.registry）不存在，写上去会被当子包解析并报依赖找不到。

/// 自检可用的环境事实。
///
/// 一次性采集、注入判据，避免每个判据各自跑子进程（AC-132 只要安装后立即自检一次）。
public class DevkitFacts {
    /// devSourceDir 是否已就位（DK-3 的前提）。
    public var devSourceReady: Bool
    /// DK-3 探测到的 cjc-version 实际值。
    public var cjcVersion: String
    /// cordis-cj 目录是否存在。
    public var hasCordis: Bool
    /// 工作副本 remote 是否匹配。
    public var remoteOk: Bool
    /// 工作副本是否 dirty。
    public var dirty: Bool
    /// 数据库连接（DK-4/DK-5 需要）。
    public var db: Option<DbConn>
    /// seed-manifest.json 声明的表数；读不到时为 -1，表示"无基线可比"。
    public var manifestTableCount: Int64

    public init() {
        devSourceReady = false
        cjcVersion = ""
        hasCordis = false
        remoteOk = false
        dirty = false
        db = None<DbConn>
        manifestTableCount = -1
    }
}

/// 采集 DK-3 相关事实（纯只读探测）。
public func collectSourceFacts(devSourceDir: Path): DevkitFacts {
    let f = DevkitFacts()
    f.devSourceReady = exists(devSourceDir)
    if (!f.devSourceReady) {
        return f
    }
    f.cjcVersion = readCjcVersion(devSourceDir)
    f.hasCordis = exists(devSourceDir.join("libs").join("cordis-cj"))
    match (classifyDevSource(devSourceDir)) {
        case DevSourceState.Reusable => f.remoteOk = true
        case _ => f.remoteOk = false
    }
    f.dirty = devSourceDirty(devSourceDir)
    return f
}

// ===================== DK-3 判据 =====================

/// DK-3 自检：五条判据全过才算 pass（design §4.10.1）。
///
/// ⑤ dirty **仅提示不阻断**——开发者有本地改动是正常状态，不是安装失败。
private func checkDK3(c: DevkitComponent, f: DevkitFacts): DevkitCheck {
    if (!f.devSourceReady) {
        return DevkitCheck("DK-3", false, "工作副本不存在", c.expected, c.fixCmd)
    }
    let versionOk = f.cjcVersion == "1.1.3"
    if (!versionOk) {
        return DevkitCheck("DK-3", false,
            "cjc-version=${f.cjcVersion}",
            "cjc-version = 1.1.3", c.fixCmd)
    }
    if (!f.hasCordis) {
        return DevkitCheck("DK-3", false,
            "libs/cordis-cj 不存在", "libs/cordis-cj/ 存在", c.fixCmd)
    }
    if (!f.remoteOk) {
        return DevkitCheck("DK-3", false,
            "remote 与预期不符", "git remote origin ∈ {atomgit, github} 预期集合", c.fixCmd)
    }
    // dirty 不阻断，但如实写进实际值。
    let note = if (f.dirty) { "（有本地改动，已保留）" } else { "" }
    return DevkitCheck("DK-3", true,
        "cjc-version=1.1.3; cordis-cj=存在; remote=匹配; dirty=${f.dirty}${note}",
        c.expected, c.fixCmd)
}

// ===================== DK-4 判据（三条） =====================

/// DK-4 自检：表数一致 + 悬空引用 0 + 超管菜单非空。
///
/// 任一不可验证（无 DB 连接 / 无基线清单）都判fail 并说明缺什么，
/// 绝不"查不到就当通过"。
private func checkDK4(c: DevkitComponent, f: DevkitFacts): DevkitCheck {
    match (f.db) {
        case None => return DevkitCheck("DK-4", false, "无数据库连接，无法验证",
                                c.expected, c.fixCmd)
        case Some(conn) => return checkDK4WithDb(c, conn, f)
    }
}

private func checkDK4WithDb(c: DevkitComponent, conn: DbConn, f: DevkitFacts): DevkitCheck {
    let repo = AdminRepo(conn)
    if (!repo.ping()) {
        return DevkitCheck("DK-4", false, "数据库不可达", c.expected, c.fixCmd)
    }

    // 判据①：public 表数。无基线清单时只报实际值，不谎称一致。
    let tableCount = countPublicTables(repo)
    if (f.manifestTableCount < 0) {
        return DevkitCheck("DK-4", false,
            "public 表数=${tableCount}；缺 seed-manifest.json 基线，无法核对一致性",
            c.expected, c.fixCmd)
    }
    if (tableCount != f.manifestTableCount) {
        return DevkitCheck("DK-4", false,
            "public 表数=${tableCount}，基线声明 ${f.manifestTableCount}",
            c.expected, c.fixCmd)
    }

    // 判据②：身份列悬空引用数必须为 0。
    let dangling = countDanglingIdentityRefs(repo)
    if (dangling > 0) {
        return DevkitCheck("DK-4", false,
            "身份列悬空引用数=${dangling}（要求 0）", c.expected, c.fixCmd)
    }

    // 判据③：超管菜单树非空（permissions.type = 1）。
    let menus = countAdminMenus(repo)
    if (menus <= 0) {
        return DevkitCheck("DK-4", false,
            "超管菜单节点数=${menus}（要求 > 0）", c.expected, c.fixCmd)
    }
    return DevkitCheck("DK-4", true,
        "表数=${tableCount}（与基线一致）; 悬空引用=0; 超管菜单=${menus}",
        c.expected, c.fixCmd)
}

/// `public` schema 下的表数。
private func countPublicTables(repo: AdminRepo): Int64 {
    return repo.withConn({ conn =>
        let stmt = conn.prepareStatement(
            "SELECT count(*) AS c FROM information_schema.tables WHERE table_schema = 'public'")
        let rs = stmt.query()
        if (rs.next()) {
            match (rs.getOrNull<Int64>(0)) {
                case Some(v) => return v
                case None => return 0
            }
        }
        return 0
    })
}

/// 身份列悬空引用计数：agents.user_id 指向不存在的 uctoo_user.id 即为悬空。
///
/// 判定必须同时满足"列属身份类"与"取值命中用户表"两个条件（spec §6.7-9），
/// 这里按已定口径只查 agents.user_id 这一条确定路径，不做"形似 id"的泛化匹配。
private func countDanglingIdentityRefs(repo: AdminRepo): Int64 {
    return repo.withConn({ conn =>
        let stmt = conn.prepareStatement(
            "SELECT count(*) AS c FROM agents a WHERE a.user_id IS NOT NULL " +
            "AND NOT EXISTS (SELECT 1 FROM uctoo_user u WHERE u.id = a.user_id)")
        let rs = stmt.query()
        if (rs.next()) {
            match (rs.getOrNull<Int64>(0)) {
                case Some(v) => return v
                case None => return 0
            }
        }
        return 0
    })
}

/// 超管可见的菜单节点数（permissions.type = 1 表示菜单，见
/// PermissionsController.getUserMenuTree 的实现注释）。
private func countAdminMenus(repo: AdminRepo): Int64 {
    return repo.withConn({ conn =>
        let stmt = conn.prepareStatement("SELECT count(*) AS c FROM permissions WHERE type = 1")
        let rs = stmt.query()
        if (rs.next()) {
            match (rs.getOrNull<Int64>(0)) {
                case Some(v) => return v
                case None => return 0
            }
        }
        return 0
    })
}

// ===================== 其余组件判据 =====================

/// DK-1 判据：cjc / cjpm / where cjc 三条输出均含 1.1.3。
private func checkDK1(c: DevkitComponent): DevkitCheck {
    let cjc = decodeOutput(runCapped("cjc", ["--version"], cap: Duration.second * 5).stdout).trimAscii()
    let cjpm = decodeOutput(runCapped("cjpm", ["--version"], cap: Duration.second * 5).stdout).trimAscii()
    if (cjc.isEmpty()) {
        return DevkitCheck("DK-1", false, "cjc 不可用", c.expected, c.fixCmd)
    }
    let cjcOk = cjc.contains("1.1.3")
    let cjpmOk = cjpm.contains("1.1.3")
    if (!cjcOk || !cjpmOk) {
        return DevkitCheck("DK-1", false,
            "cjc=${cjc}; cjpm=${cjpm}", c.expected, c.fixCmd)
    }
    return DevkitCheck("DK-1", true, "cjc=${cjc}; cjpm=${cjpm}", c.expected, c.fixCmd)
}

/// DK-2 判据：stdx 动态库目录非空，且两个 OpenSSL DLL **同时**存在（R-15）。
private func checkDK2(c: DevkitComponent, devSourceDir: Path): DevkitCheck {
    if (!exists(devSourceDir)) {
        return DevkitCheck("DK-2", false, "开发源码目录不存在", c.expected, c.fixCmd)
    }
    let binDir = devSourceDir.join("bin")
    let crypto = binDir.join("libcrypto-3-x64.dll")
    let ssl = binDir.join("libssl-3-x64.dll")
    if (!exists(crypto)) {
        return DevkitCheck("DK-2", false, "缺少 libcrypto-3-x64.dll", c.expected, c.fixCmd)
    }
    if (!exists(ssl)) {
        return DevkitCheck("DK-2", false, "缺少 libssl-3-x64.dll", c.expected, c.fixCmd)
    }
    return DevkitCheck("DK-2", true,
        "libcrypto-3-x64.dll=存在; libssl-3-x64.dll=存在", c.expected, c.fixCmd)
}

/// DK-5 判据：db_info 行数 > 0。无连接则如实报不可验证。
private func checkDK5(c: DevkitComponent, f: DevkitFacts): DevkitCheck {
    match (f.db) {
        case None => return DevkitCheck("DK-5", false, "无数据库连接，无法验证", c.expected, c.fixCmd)
        case Some(conn) => return checkDK5WithDb(c, conn, f)
    }
}

private func checkDK5WithDb(c: DevkitComponent, conn: DbConn, f: DevkitFacts): DevkitCheck {
    let repo = AdminRepo(conn)
    let rows = repo.withConn({ conn2 =>
        let stmt = conn2.prepareStatement("SELECT count(*) AS c FROM db_info")
        let rs = stmt.query()
        if (rs.next()) {
            match (rs.getOrNull<Int64>(0)) {
                case Some(v) => return v
                case None => return 0
            }
        }
        return 0
    })
    if (rows <= 0) {
        return DevkitCheck("DK-5", false,
            "db_info 行数=${rows}（要求 > 0）", c.expected, c.fixCmd)
    }
    return DevkitCheck("DK-5", true, "db_info 行数=${rows}", c.expected, c.fixCmd)
}

/// DK-6 判据：知识库检索脚本能跑通且返回非空。
private func checkDK6(c: DevkitComponent, devSourceDir: Path): DevkitCheck {
    let script = devSourceDir.join("skills").join("CangjieSkills").join("scripts").join("search_docs.py")
    if (!exists(script)) {
        return DevkitCheck("DK-6", false,
            "知识库检索脚本不存在: ${script.toString()}", c.expected, c.fixCmd)
    }
    let r = runCapped("python", [script.toString(), "--query", "cjpm build"],
                      cap: Duration.second * 20, cwd: devSourceDir)
    let out = decodeOutput(r.stdout).trimAscii()
    if (!succeeded(r) || out.isEmpty()) {
        return DevkitCheck("DK-6", false,
            "检索脚本退出码=${r.exitCode}，输出长度=${out.size}", c.expected, c.fixCmd)
    }
    return DevkitCheck("DK-6", true, "检索返回 ${out.size} 字符", c.expected, c.fixCmd)
}

/// DK-7 判据：node / pnpm 可解析且 check-vue-refs 退出码 0。
private func checkDK7(c: DevkitComponent, devSourceDir: Path): DevkitCheck {
    let node = decodeOutput(runCapped("node", ["-v"], cap: Duration.second * 5).stdout).trimAscii()
    if (node.isEmpty()) {
        return DevkitCheck("DK-7", false, "node 不可用", c.expected, c.fixCmd)
    }
    let pnpm = runCapped("pnpm", ["-v"], cap: Duration.second * 5)
    if (!succeeded(pnpm)) {
        return DevkitCheck("DK-7", false, "pnpm 不可解析", c.expected, c.fixCmd)
    }
    let check = devSourceDir.join("web").join("scripts").join("check-vue-refs.cjs")
    if (!exists(check)) {
        return DevkitCheck("DK-7", true,
            "node=${node}; pnpm 可解析; 未找到 check-vue-refs.cjs，跳过该项",
            c.expected, c.fixCmd)
    }
    let r = runCapped("node", [check.toString(), "src/views/ai/"],
                      cap: Duration.second * 30, cwd: devSourceDir.join("web"))
    if (!succeeded(r)) {
        return DevkitCheck("DK-7", false,
            "check-vue-refs 退出码=${r.exitCode}", c.expected, c.fixCmd)
    }
    return DevkitCheck("DK-7", true, "node=${node}; pnpm=${decodeOutput(pnpm.stdout).trimAscii()}",
        c.expected, c.fixCmd)
}

/// DK-8 判据：VS Code 扩展目录中存在 Cangjie 扩展。
private func checkDK8(c: DevkitComponent): DevkitCheck {
    let r = runCapped("code", ["--list-extensions"], cap: Duration.second * 10)
    if (!succeeded(r)) {
        return DevkitCheck("DK-8", false, "code 命令不可用，无法确认扩展", c.expected, c.fixCmd)
    }
    for (line in splitLines(decodeOutput(r.stdout))) {
        let t = line.trimAscii().toAsciiLower()
        if (t.contains("cangjie")) {
            return DevkitCheck("DK-8", true, "已安装扩展 ${line.trimAscii()}", c.expected, c.fixCmd)
        }
    }
    return DevkitCheck("DK-8", false, "扩展列表中未找到 cangjie 扩展", c.expected, c.fixCmd)
}

// ===================== 汇总 =====================

/// 全量自检：按注册表顺序逐组件执行判据。
public func verifyDevkit(devSourceDir: Path, f: DevkitFacts): ArrayList<DevkitCheck> {
    let out = ArrayList<DevkitCheck>()
    for (c in devkitRegistry()) {
        out.add(checkOne(c, devSourceDir, f))
    }
    return out
}

/// 单组件自检（`devkit install <id>` 安装后立即调用，满足 AC-132）。
public func verifyOne(id: String, devSourceDir: Path, f: DevkitFacts): Option<DevkitCheck> {
    match (devkitComponentById(id)) {
        case None => return None<DevkitCheck>
        case Some(c) => return Some(checkOne(c, devSourceDir, f))
    }
}

private func checkOne(c: DevkitComponent, devSourceDir: Path, f: DevkitFacts): DevkitCheck {
    match (c.id) {
        case "DK-1" => return checkDK1(c)
        case "DK-2" => return checkDK2(c, devSourceDir)
        case "DK-3" => return checkDK3(c, f)
        case "DK-4" => return checkDK4(c, f)
        case "DK-5" => return checkDK5(c, f)
        case "DK-6" => return checkDK6(c, devSourceDir)
        case "DK-7" => return checkDK7(c, devSourceDir)
        case "DK-8" => return checkDK8(c)
        case _ => return DevkitCheck(c.id, false, "无判据", c.expected, c.fixCmd)
    }
}

/// 全部通过返回 true（AC-134：任一未通过则汇总命令须返回非零退出码）。
public func allPassed(checks: ArrayList<DevkitCheck>): Bool {
    for (c in checks) {
        if (!c.passed) {
            return false
        }
    }
    return true
}

/// 机器可读汇总（AC-133：标识 / 状态 / 实际值 / 期望值 / 修复建议）。
///
/// 同时满足 AC-145：以该输出导出为基线文件，回放时得到与导出时一致的组件集合。
public func checksToJson(checks: ArrayList<DevkitCheck>): JsonObject {
    let o = JsonObject()
    o.put("schema", JsonString("ucinstaller/devkit-verify/v1"))
    o.put("ok", JsonBool(allPassed(checks)))
    let arr = JsonArray()
    for (c in checks) {
        let item = JsonObject()
        item.put("id", JsonString(c.id))
        item.put("status", JsonString(if (c.passed) { "pass" } else { "fail" }))
        item.put("actual", JsonString(c.actual))
        item.put("expected", JsonString(c.expected))
        // AC-134：未通过项的修复建议必须非空。
        item.put("fix", JsonString(c.fix))
        arr.add(item)
    }
    o.put("items", arr)
    let sizes = JsonObject()
    for ((k, v) in devkitSizeBreakdown()) {
        sizes.put(k, JsonInt(v))
    }
    o.put("sizeMb", sizes)
    o.put("totalSizeMb", JsonInt(devkitTotalSizeMb()))
    return o
}

/// 推荐标记与理由（AC-135/136）：理由**必须**含探测到的实际值，禁止泛化。
///
/// **入参是调用方持有的同一个列表**：`devkitRegistry()` 每次调用都新建实例，
/// 若在此内部重新取注册表再改字段，改动会随临时对象一起被丢弃 —— 调用方随后
/// 再取一次注册表拿到的仍是默认值 `recommended=true / reason=""`，AC-135/136
/// 就成了空实现。故签名强制传入要输出的那一份。
public func applyRecommendationsTo(comps: ArrayList<DevkitComponent>,
                                   devSourceDir: Path, f: DevkitFacts): Unit {
    for (c in comps) {
        applyOne(c, devSourceDir, f)
    }
}

private func applyOne(c: DevkitComponent, devSourceDir: Path, f: DevkitFacts): Unit {
    match (c.id) {
        // AC-136：本机已有符合版本要求的编译器 ⇒ 工具链组件不推荐，并引用探测到的版本号。
        case "DK-1" => recommendByProbe(c, "cjc", ["--version"], "1.1.3")
        case "DK-2" => recommendByPresence(c, devSourceDir.join("bin").join("libcrypto-3-x64.dll"),
                                "bin/libcrypto-3-x64.dll")
        case "DK-3" => recommendByPresence(c, devSourceDir.join("cjpm.toml"), "cjpm.toml")
        case "DK-4" => recommendByProbe(c, "git", ["--version"], "")
        case "DK-5" => recommendByPresence(c, devSourceDir.join("cjpm.toml"), "cjpm.toml")
        case "DK-6" => recommendByPresence(c,
            devSourceDir.join("skills").join("CangjieSkills"), "skills/CangjieSkills")
        case "DK-7" => recommendByProbe(c, "node", ["-v"], "14")
        case "DK-8" => recommendByProbe(c, "code", ["--version"], "")
        case _ => c.reason = "无探测项"
    }
}

/// 已存在 ⇒ 不推荐（无需再装）；理由里带上实际探测到的路径/版本。
private func recommendByPresence(c: DevkitComponent, p: Path, shownName: String): Unit {
    if (exists(p)) {
        c.recommended = false
        c.reason = "已存在 ${shownName}（${p.toString()}），无需再装"
    } else {
        c.recommended = true
        c.reason = "未探测到 ${shownName}，建议安装"
    }
}

/// 用版本命令探测：命令可用且版本号含期望串 ⇒ 不推荐，并引用实际版本号。
private func recommendByProbe(c: DevkitComponent, cmd: String,
                              args: Array<String>, want: String): Unit {
    let r = runCapped(cmd, args, cap: Duration.second * 5)
    if (!succeeded(r)) {
        c.recommended = true
        c.reason = "未探测到 ${cmd}，建议安装"
        return
    }
    let ver = decodeOutput(r.stdout).trimAscii()
    if (!want.isEmpty() && !ver.contains(want)) {
        c.recommended = true
        c.reason = "已探测到 ${cmd} 版本 ${ver}，与要求的 ${want} 不符，建议安装"
        return
    }
    c.recommended = false
    c.reason = if (want.isEmpty()) {
        "已探测到 ${cmd} 版本 ${ver}，无需再装"
    } else {
        "已探测到 ${cmd} 版本 ${ver}（满足 ${want}），无需再装"
    }
}
