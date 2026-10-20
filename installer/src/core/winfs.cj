package uc_installer.core

import std.fs.{Path, exists, rename, Directory, File, OpenMode, FileInfo}
import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool, JsonNull, JsonKind}
import uc_installer.platform.{runCapped, decodeOutput}

/// 被占用文件的处理结果。
public enum ReplaceOutcome {
    | Switched
    | Deferred
}

public func replaceOutcomeCode(o: ReplaceOutcome): String {
    match (o) {
        case ReplaceOutcome.Switched => return "switched"
        case ReplaceOutcome.Deferred => return "deferred"
    }
}

/// GC 队列中的一条延迟替换记录。
public struct GcEntry {
    public let path: String
    public let pending: String
    public let firstFailedAt: String
    public var attempts: Int64
    public let reason: String
    public let holderPid: Option<Int64>
    public init(path!: String, pending!: String, firstFailedAt!: String, attempts!: Int64,
                reason!: String, holderPid!: Option<Int64>) {
        this.path = path
        this.pending = pending
        this.firstFailedAt = firstFailedAt
        this.attempts = attempts
        this.reason = reason
        this.holderPid = holderPid
    }
}

// ===================== GC 队列持久化 =====================

/// stdx.encoding.json：asXxx 返回包装子类，类型不符抛 JsonException，故先 kind() 判别。
private func wGetStr(o: JsonObject, key: String, def: String): String {
    return match (o.get(key)) {
        case Some(v) => match (v.kind()) {
            case JsonKind.JsString => v.asString().getValue()
            case _ => def
        }
        case None => def
    }
}

private func wGetInt(o: JsonObject, key: String, def: Int64): Int64 {
    return match (o.get(key)) {
        case Some(v) => match (v.kind()) {
            case JsonKind.JsInt => v.asInt().getValue()
            case _ => def
        }
        case None => def
    }
}

private func wGetOptInt(o: JsonObject, key: String): Option<Int64> {
    return match (o.get(key)) {
        case Some(v) => match (v.kind()) {
            case JsonKind.JsInt => Some(v.asInt().getValue())
            case _ => None<Int64>
        }
        case None => None<Int64>
    }
}

func gcEntryToJson(e: GcEntry): JsonObject {
    let o = JsonObject()
    o.put("path", JsonString(e.path))
    o.put("pending", JsonString(e.pending))
    o.put("firstFailedAt", JsonString(e.firstFailedAt))
    o.put("attempts", JsonInt(e.attempts))
    o.put("reason", JsonString(e.reason))
    match (e.holderPid) {
        case Some(p) => o.put("holderPid", JsonInt(p))
        case None => o.put("holderPid", JsonNull())
    }
    return o
}

func gcEntryFromJson(o: JsonObject): Option<GcEntry> {
    let path = wGetStr(o, "path", "")
    let pending = wGetStr(o, "pending", "")
    if (path.isEmpty() || pending.isEmpty()) {
        return None<GcEntry>
    }
    let firstFailedAt = wGetStr(o, "firstFailedAt", "")
    let attempts = wGetInt(o, "attempts", 0)
    let reason = wGetStr(o, "reason", "")
    let holderPid = wGetOptInt(o, "holderPid")
    return Some(GcEntry(path: path, pending: pending, firstFailedAt: firstFailedAt,
                        attempts: attempts, reason: reason, holderPid: holderPid))
}

/// 读取 GC 队列（文件不存在返回空列表）。
public func loadGc(gcFile: Path): ArrayList<GcEntry> {
    let out = ArrayList<GcEntry>()
    if (!exists(gcFile)) {
        return out
    }
    try {
        let info = FileInfo(gcFile)
        let buf = Array<Byte>(info.size, repeat: 0)
        let f = File(gcFile, OpenMode.Read)
        f.read(buf)
        f.close()
        let text = String.fromUtf8(buf)
        let parsed = JsonValue.fromStr(text)
        match (parsed.kind()) {
            case JsonKind.JsArray => for (d in parsed.asArray().getItems()) {
                match (d.kind()) {
                    case JsonKind.JsObject => match (gcEntryFromJson(d.asObject())) {
                        case Some(e) => out.add(e)
                        case None => ()
                    }
                    case _ => ()
                }
            }
            case _ => ()
        }
    } catch (_: Exception) {
        // 读坏也不阻断，当作空队列
    }
    return out
}

/// 写回 GC 队列（原子：tmp + rename）。
public func saveGc(gcFile: Path, entries: ArrayList<GcEntry>): Unit {
    let arr = JsonArray()
    for (e in entries) {
        arr.add(gcEntryToJson(e))
    }
    let text = arr.toJsonString()
    let tmp = Path(gcFile.toString() + ".tmp")
    let f = File(tmp, OpenMode.Write)
    f.write(text.toArray())
    f.close()
    rename(tmp, to: gcFile, overwrite: true)
}

/// 追加一条 GC 记录（读-改-写）。
public func appendGc(gcFile: Path, entry: GcEntry): Unit {
    let entries = loadGc(gcFile)
    entries.add(entry)
    saveGc(gcFile, entries)
}

// ===================== 占用文件处理 =====================

/// 把 staged 落地为 target。
///
/// - target 不存在：直接 rename（Switched）。
/// - target 存在且可挪走：先挪进 trash，再 rename staged → target（Switched）。
/// - 占用导致挪不动：登记 `.installer-gc.json` 延迟替换，返回 Deferred（不阻断安装）。
///
/// 设计约束（AC-011）：**绝不**主动 `taskkill` 不属于本安装器的进程；命中非本安装器所属占用者时
/// 只登记 deferred 并输出人工命令，不在安装阶段强杀。
public func replaceOrDefer(target: Path, staged: Path, gcFile: Path): ReplaceOutcome {
    if (!exists(target)) {
        rename(staged, to: target, overwrite: true)
        return ReplaceOutcome.Switched
    }
    let ts = DateTime.now().toString().replace(":", "-").replace(" ", "_")
    let trashTarget = target.parent.join(".trash-${ts}-${target.fileName}")
    try {
        rename(target, to: trashTarget, overwrite: true)
        rename(staged, to: target, overwrite: true)
        return ReplaceOutcome.Switched
    } catch (_: Exception) {
        let entry = GcEntry(path: target.toString(), pending: staged.toString(),
                           firstFailedAt: DateTime.now().toString(), attempts: 0,
                           reason: "sharing-violation", holderPid: None<Int64>)
        appendGc(gcFile, entry)
        return ReplaceOutcome.Deferred
    }
}

/// 执行一轮 GC：尝试把每条 pending 替换为目标；成功即从队列移除。
/// 返回本轮成功替换的条数。
public func runGcOnce(gcFile: Path): Int64 {
    let entries = loadGc(gcFile)
    if (entries.isEmpty()) {
        return 0
    }
    let remaining = ArrayList<GcEntry>()
    var resolved = 0
    for (e in entries) {
        let target = Path(e.path)
        let pending = Path(e.pending)
        if (!exists(pending)) {
            // pending 已不在，丢弃该记录
            continue
        }
        let ts = DateTime.now().toString().replace(":", "-").replace(" ", "_")
        let trashTarget = target.parent.join(".trash-${ts}-${target.fileName}")
        try {
            rename(target, to: trashTarget, overwrite: true)
            rename(pending, to: target, overwrite: true)
            resolved = resolved + 1
        } catch (_: Exception) {
            var updated = e
            updated.attempts = e.attempts + 1
            remaining.add(updated)
        }
    }
    saveGc(gcFile, remaining)
    return resolved
}
