package uc_installer.core

import std.fs.{File, OpenMode, Path, FileInfo, exists, rename, remove}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonKind}

/// runtime 进程 PID 文件记录。
///
/// 落盘格式（design.md §4.9 / §6.6.8）：
///   {"pid":<Int64>,"image":"agentskills-runtime.exe","exe":<path>,"startedAt":<ISO8601>}
public struct RuntimePidRecord {
    public let pid: Int64
    public let image: String
    public let exe: String
    public let startedAt: String
    public init(pid!: Int64, image!: String, exe!: String, startedAt!: String) {
        this.pid = pid
        this.image = image
        this.exe = exe
        this.startedAt = startedAt
    }
}

/// PID 文件固定路径：<installRoot>/.installer-runtime.pid
public func runtimePidFilePath(installRoot: Path): Path {
    return installRoot.join(".installer-runtime.pid")
}

/// 读取 PID 文件；不存在或解析失败返回 None（视为未运行）。
public func readRuntimePidFile(installRoot: Path): ?RuntimePidRecord {
    let p = runtimePidFilePath(installRoot)
    if (!exists(p)) {
        return None<RuntimePidRecord>
    }
    try {
        let info = FileInfo(p)
        let buf = Array<Byte>(info.size, repeat: 0)
        let f = File(p, OpenMode.Read)
        f.read(buf)
        f.close()
        let text = String.fromUtf8(buf)
        let parsed = JsonValue.fromStr(text)
        match (parsed.kind()) {
            case JsonKind.JsObject =>
                let o = parsed.asObject()
                let pid = match (o.get("pid")) {
                    case Some(v) => match (v.kind()) { case JsonKind.JsInt => v.asInt().getValue(); case _ => -1 }
                    case None => -1
                }
                let image = strField(o, "image")
                let exe = strField(o, "exe")
                let startedAt = strField(o, "startedAt")
                if (pid > 0) {
                    return Some(RuntimePidRecord(pid: pid, image: image, exe: exe, startedAt: startedAt))
                }
                return None<RuntimePidRecord>
            case _ => return None<RuntimePidRecord>
        }
    } catch (_: Exception) {
        return None<RuntimePidRecord>
    }
}

/// 原子写 PID 文件（tmp + rename）；失败返回 false。
public func writeRuntimePidFile(installRoot: Path, rec: RuntimePidRecord): Bool {
    try {
        let o = JsonObject()
        o.put("pid", JsonInt(rec.pid))
        o.put("image", JsonString(rec.image))
        o.put("exe", JsonString(rec.exe))
        o.put("startedAt", JsonString(rec.startedAt))
        let text = o.toJsonString()
        let p = runtimePidFilePath(installRoot)
        let tmp = Path(p.toString() + ".tmp")
        let f = File(tmp, OpenMode.Write)
        f.write(text.toArray())
        f.close()
        rename(tmp, to: p, overwrite: true)
        return true
    } catch (_: Exception) {
        return false
    }
}

/// 删除 PID 文件（进程停止或确认未运行时清理）。
public func removeRuntimePidFile(installRoot: Path): Unit {
    let p = runtimePidFilePath(installRoot)
    if (exists(p)) {
        try { remove(p) } catch (_: Exception) { () }
    }
}

private func strField(o: JsonObject, key: String): String {
    match (o.get(key)) {
        case Some(v) => match (v.kind()) { case JsonKind.JsString => v.asString().getValue(); case _ => "" }
        case None => ""
    }
}
