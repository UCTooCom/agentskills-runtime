package uc_installer.services.devkit

// ============================================================================
// 磁盘空间闸口（AC-144）——**唯一实现**，CLI 与 HTTP 两条通道共用。
//
// 2026-10-09 从 `http/handlers/devkit.cj` 下沉到此：
// `devkit install` 补 CLI 通道时，若闸口留在 handler 里，命令行就只剩两条路——
// 要么复制一份（同一条规则两处维护，必然漂移），要么干脆不校验（AC-144 落空）。
// 两者都不可接受，故按「能力只写一份」的范式下沉到 services。
//
// 三条必须守住的语义（与原地实现逐条一致，未做简化）：
//   ① `availableMb == -1` 表示**探测不到**，不是"空间为零"；
//   ② 探测不到时**不阻断**安装，但必须显式留痕（交给调用方 degraded）；
//   ③ 只有探测到且确实不足时才中止，并给出「实际值 / 所需值 / 逐组件预估」。
//
// 同包跨文件免 import：`devkitRegistry` / `devkitSizeBreakdown` / `devkitTotalSizeMb`
// 都在 `registry.cj`，直接调用即可（写成 `uc_installer.services.devkit.registry.…`
// 会被当成子包解析并报 can not find the following dependencies）。
// ============================================================================

import std.fs.Path
import std.collection.ArrayList
import std.convert.Parsable
import std.core.StringBuilder
import uc_installer.platform.{runCapped, succeeded, decodeOutput, splitLines}

/// 目标路径所在卷的剩余空间（MB）；探测不到返回 **-1**（不是 0）。
///
/// 实现取 `wmic logicaldisk get DeviceID,FreeSpace`（Windows 内置、无需提权）。
/// 解析失败 / 命令不存在 / 输出无对应盘符，一律返回 -1，
/// **由调用方显式降级**，不在这里假装"空间充足"。
public func freeSpaceMb(dir: Path): Int64 {
    let drive = driveLetterOf(dir)
    if (drive.isEmpty()) {
        return -1
    }
    let args = ArrayList<String>()
    args.add("logicaldisk")
    args.add("get")
    args.add("DeviceID")
    args.add("FreeSpace")
    let r = runCapped("wmic", args.toArray(), cap: Duration.second * 10)
    if (!succeeded(r)) {
        return -1
    }
    let text = decodeOutput(r.stdout)
    for (raw in splitLines(text)) {
        let tokens = spaceTokens(raw.trimAscii())
        if (tokens.size < 2) {
            continue
        }
        if (tokens[0] != drive) {
            continue
        }
        return toMb(tokens[1])
    }
    return -1
}

/// 所选组件的体量合计（MB）；未知组件按 0 计。
public func requiredMbFor(ids: ArrayList<String>): Int64 {
    let all = devkitSizeBreakdown()
    var total: Int64 = 0
    for (c in devkitRegistry()) {
        if (!ids.contains(c.id)) {
            continue
        }
        match (all.get(c.id)) {
            case Some(v) => total += v
            case None => ()
        }
    }
    return total
}

/// 闸口判定：返回 Some(原因) 表示**已探测到且**空间不足，应中止安装。
///
/// 探测不到（freeSpaceMb < 0）时返回 None —— 不阻断，但调用方必须调
/// `diskProbeFailed` 留痕，"没校验过"不能被当成"校验通过"。
public func diskGate(dir: Path, ids: ArrayList<String>): Option<String> {
    let free = freeSpaceMb(dir)
    if (free < 0) {
        return None
    }
    let need = requiredMbFor(ids)
    if (free >= need) {
        return None
    }
    return "目标磁盘剩余 ${free} MB，不足以容纳所选组件所需的 ${need} MB" +
        "（逐组件预估见 sizeMb，全量预估 totalSizeMb）"
}

/// 磁盘探测是否失败（供调用方生成 degraded 留痕）。
public func diskProbeFailed(dir: Path): Bool {
    return freeSpaceMb(dir) < 0
}

// ===================== 内部：wmic 输出解析 =====================

/// 按空白切分并压缩连续分隔符（wmic 列用不定长空格对齐，
/// 直接 `split(" ")` 会产生一堆空 token，取错列）。
private func spaceTokens(line: String): ArrayList<String> {
    let out = ArrayList<String>()
    let runes = line.toRuneArray()
    var cur = StringBuilder()
    var i: Int64 = 0
    while (i < runes.size) {
        let c = runes[i]
        if (c == r' ' || c == r'\t') {
            if (cur.size > 0) {
                out.add(cur.toString())
                cur = StringBuilder()
            }
        } else {
            cur.append(c)
        }
        i = i + 1
    }
    if (cur.size > 0) {
        out.add(cur.toString())
    }
    return out
}

/// 取盘符（含冒号），如 `D:`；取不到返回空串。
private func driveLetterOf(dir: Path): String {
    let s = dir.toString()
    if (s.size < 2) {
        return ""
    }
    // `D:` 形态：首字符是字母、次字符是冒号。仓颉 String 按**字节**切片，
    // 而 ASCII 字母与冒号各占 1 字节，故此处不会切坏多字节字符。
    if (s[1..2] != ":") {
        return ""
    }
    let letter = s[0..1]
    let isLetter = (letter >= "A" && letter <= "Z") || (letter >= "a" && letter <= "z")
    if (!isLetter) {
        return ""
    }
    return letter + ":"
}

/// 字节数转 MB；解析失败返回 -1。
private func toMb(text: String): Int64 {
    let digits = keepDigits(text)
    if (digits.isEmpty()) {
        return -1
    }
    try {
        let bytes = Int64.parse(digits)
        return bytes / (1024 * 1024)
    } catch (_: Exception) {
        return -1
    }
}

/// 只保留数字（wmic 输出可能带千分位逗号）。
///
/// ⚠️ 必须走 `toRuneArray()`：`for (c in s)` 迭代 `String` 得到的是 **UTF-8 字节 UInt8**，
/// 拿它和字符串常量比较会报 `invalid binary operator '=='`（本仓 `net.cj` 同一坑）。
private func keepDigits(s: String): String {
    let sb = StringBuilder()
    let runes = s.toRuneArray()
    var i: Int64 = 0
    while (i < runes.size) {
        let c = runes[i]
        if (c >= r'0' && c <= r'9') {
            sb.append(c.toString())
        }
        i = i + 1
    }
    return sb.toString()
}
