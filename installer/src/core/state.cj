package uc_installer.core

import std.fs.{Path, File, OpenMode, FileInfo, exists, rename}
import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool, JsonNull, JsonKind}

// ===================== 常量（与 schema 取值严格对齐） =====================

public let STEP_PENDING = "pending"
public let STEP_RUNNING = "running"
public let STEP_DONE = "done"
public let STEP_FAILED = "failed"
public let STEP_SKIPPED = "skipped"
public let STEP_ROLLED_BACK = "rolledback"

public let MODE_ENDUSER = "enduser"
public let MODE_DEV = "dev"

public let DEVKIT_PENDING = "pending"
public let DEVKIT_INSTALLED = "installed"
public let DEVKIT_SKIPPED = "skipped"
public let DEVKIT_FAILED = "failed"

public let MEDIA_LOCAL = "local"
public let MEDIA_REMOTE = "remote"

public let SCHEMA_VERSION: Int64 = 3

// ===================== 数据结构 =====================

/// 单步证据（键值对，写进状态文件供诊断）。
public struct StepEvidence {
    public var items: HashMap<String, String>
    public init() {
        this.items = HashMap<String, String>()
    }
    public init(items!: HashMap<String, String>) {
        this.items = items
    }
}

/// 单个安装步骤的持久化状态。
public struct StepState {
    public let id: String
    public var status: String
    public var at: Option<String>
    public var evidence: StepEvidence
    public init(id!: String, status!: String, at!: Option<String>, evidence!: StepEvidence) {
        this.id = id
        this.status = status
        this.at = at
        this.evidence = evidence
    }
}

/// DevKit 单个组件状态（DK-1~DK-8）。
public struct DevkitComponentState {
    public let id: String
    public var status: String
    public var at: Option<String>
    public var actual: String
    public var expected: String
    public init(id!: String, status!: String, at!: Option<String>, actual!: String, expected!: String) {
        this.id = id
        this.status = status
        this.at = at
        this.actual = actual
        this.expected = expected
    }
}

/// 降级项（如实记录被降级的探测/动作，附人工修复命令）。
public struct DegradedItem {
    public let id: String
    public let reason: String
    public let fallback: String
    public let manualCmd: String
    public init(id!: String, reason!: String, fallback!: String, manualCmd!: String) {
        this.id = id
        this.reason = reason
        this.fallback = fallback
        this.manualCmd = manualCmd
    }
}

/// 快照（回滚能力依赖）。
public struct SnapshotState {
    public var exists: Bool
    public var path: String
    public var at: Option<String>
    public init() {
        this.exists = false
        this.path = ""
        this.at = None<String>
    }
    public init(exists!: Bool, path!: String, at!: Option<String>) {
        this.exists = exists
        this.path = path
        this.at = at
    }
}

/// 损坏恢复标记。
public struct CorruptionState {
    public var recovered: Bool
    public var backupPath: Option<String>
    public init() {
        this.recovered = false
        this.backupPath = None<String>
    }
    public init(recovered!: Bool, backupPath!: Option<String>) {
        this.recovered = recovered
        this.backupPath = backupPath
    }
}

/// 完整安装状态（schema v3）。
/// 设计为 class（引用类型）：fillXInto 辅助函数直接修改调用方持有的同一实例，
/// 若用 struct（值类型）则传参是拷贝，辅助函数内的修改无法回传。
public class InstallState {
    public var schemaVersion: Int64
    public var installerVersion: String
    public var mode: String
    public var installRoot: String
    public var releaseDir: String
    public var currentStep: String
    public var port: Int64
    public var runtimeVersion: String
    public var steps: HashMap<String, StepState>
    public var devkit: String
    public var devkitComponents: HashMap<String, DevkitComponentState>
    public var mediaSource: String
    public var snapshot: SnapshotState
    public var corruption: CorruptionState
    public var degraded: ArrayList<DegradedItem>

    public init() {
        this.schemaVersion = SCHEMA_VERSION
        this.installerVersion = "1.0.0"
        this.mode = MODE_ENDUSER
        this.installRoot = ""
        this.releaseDir = ""
        this.currentStep = "S0"
        this.port = 3000
        this.runtimeVersion = ""
        this.steps = HashMap<String, StepState>()
        this.devkit = DEVKIT_PENDING
        this.devkitComponents = HashMap<String, DevkitComponentState>()
        this.mediaSource = MEDIA_LOCAL
        this.snapshot = SnapshotState()
        this.corruption = CorruptionState()
        this.degraded = ArrayList<DegradedItem>()
    }
}

// ===================== JSON 辅助读（stdx.encoding.json：asXxx 返回包装子类，类型不符抛 JsonException，故先 kind() 判别） =====================

private func getStr(o: JsonObject, key: String, def: String): String {
    return match (o.get(key)) {
        case Some(v) => match (v.kind()) {
            case JsonKind.JsString => v.asString().getValue()
            case _ => def
        }
        case None => def
    }
}

private func getInt(o: JsonObject, key: String, def: Int64): Int64 {
    return match (o.get(key)) {
        case Some(v) => match (v.kind()) {
            case JsonKind.JsInt => v.asInt().getValue()
            case _ => def
        }
        case None => def
    }
}

private func getBool(o: JsonObject, key: String, def: Bool): Bool {
    return match (o.get(key)) {
        case Some(v) => match (v.kind()) {
            case JsonKind.JsBool => v.asBool().getValue()
            case _ => def
        }
        case None => def
    }
}

private func getObj(o: JsonObject, key: String): Option<JsonObject> {
    return match (o.get(key)) {
        case Some(v) => match (v.kind()) {
            case JsonKind.JsObject => Some(v.asObject())
            case _ => None<JsonObject>
        }
        case None => None<JsonObject>
    }
}

private func getOptStr(o: JsonObject, key: String): Option<String> {
    return match (o.get(key)) {
        case Some(v) => match (v.kind()) {
            case JsonKind.JsString => optStrNonEmpty(v.asString().getValue())
            case _ => None<String>
        }
        case None => None<String>
    }
}

private func optStrNonEmpty(s: String): Option<String> {
    if (s.isEmpty()) { return None<String> }
    return Some(s)
}

// ===================== JSON 序列化 =====================

/// 把状态序列化为 JSON 字符串（schema v3）。
public func installStateToJson(st: InstallState): String {
    let root = JsonObject()
    root.put("schemaVersion", JsonInt(st.schemaVersion))
    root.put("installerVersion", JsonString(st.installerVersion))
    root.put("mode", JsonString(st.mode))
    root.put("installRoot", JsonString(st.installRoot))
    root.put("releaseDir", JsonString(st.releaseDir))
    root.put("currentStep", JsonString(st.currentStep))
    root.put("port", JsonInt(st.port))
    root.put("runtimeVersion", JsonString(st.runtimeVersion))

    let steps = JsonObject()
    for ((k, v) in st.steps) {
        let so = JsonObject()
        so.put("status", JsonString(v.status))
        match (v.at) {
            case Some(s) => so.put("at", JsonString(s))
            case None => so.put("at", JsonNull())
        }
        let ev = JsonObject()
        for ((ek, evv) in v.evidence.items) {
            ev.put(ek, JsonString(evv))
        }
        so.put("evidence", ev)
        steps.put(k, so)
    }
    root.put("steps", steps)

    root.put("devkit", JsonString(st.devkit))
    let dk = JsonObject()
    for ((k, v) in st.devkitComponents) {
        let dko = JsonObject()
        dko.put("status", JsonString(v.status))
        match (v.at) {
            case Some(s) => dko.put("at", JsonString(s))
            case None => dko.put("at", JsonNull())
        }
        dko.put("actual", JsonString(v.actual))
        dko.put("expected", JsonString(v.expected))
        dk.put(k, dko)
    }
    root.put("devkitComponents", dk)

    root.put("mediaSource", JsonString(st.mediaSource))

    let snap = JsonObject()
    snap.put("exists", JsonBool(st.snapshot.exists))
    snap.put("path", JsonString(st.snapshot.path))
    match (st.snapshot.at) {
        case Some(s) => snap.put("at", JsonString(s))
        case None => snap.put("at", JsonNull())
    }
    root.put("snapshot", snap)

    let corr = JsonObject()
    corr.put("recovered", JsonBool(st.corruption.recovered))
    match (st.corruption.backupPath) {
        case Some(s) => corr.put("backupPath", JsonString(s))
        case None => corr.put("backupPath", JsonNull())
    }
    root.put("corruption", corr)

    let deg = JsonArray()
    for (d in st.degraded) {
        let do_ = JsonObject()
        do_.put("id", JsonString(d.id))
        do_.put("reason", JsonString(d.reason))
        do_.put("fallback", JsonString(d.fallback))
        do_.put("manualCmd", JsonString(d.manualCmd))
        deg.add(do_)
    }
    root.put("degraded", deg)

    return root.toJsonString()
}

// ===================== JSON 反序列化（容错） =====================

func buildEvidence(svo: JsonObject): HashMap<String, String> {
    let evItems = HashMap<String, String>()
    match (getObj(svo, "evidence")) {
        case Some(evo) => for ((ek, evv) in evo.getFields()) {
            match (evv.kind()) {
                case JsonKind.JsString => evItems.add(ek, evv.asString().getValue())
                case _ => ()
            }
        }
        case None => ()
    }
    return evItems
}

func stepFromJson(k: String, svo: JsonObject): StepState {
    let evItems = buildEvidence(svo)
    return StepState(id: k, status: getStr(svo, "status", STEP_PENDING),
                     at: getOptStr(svo, "at"), evidence: StepEvidence(items: evItems))
}

func fillStepsInto(st: InstallState, so: JsonObject): Unit {
    for ((k, v) in so.getFields()) {
        match (v.kind()) {
            case JsonKind.JsObject => st.steps.add(k, stepFromJson(k, v.asObject()))
            case _ => ()
        }
    }
}

func devkitFromJson(k: String, dvo: JsonObject): DevkitComponentState {
    return DevkitComponentState(id: k, status: getStr(dvo, "status", DEVKIT_PENDING),
                                at: getOptStr(dvo, "at"), actual: getStr(dvo, "actual", ""),
                                expected: getStr(dvo, "expected", ""))
}

func fillDevkitInto(st: InstallState, dko: JsonObject): Unit {
    for ((k, v) in dko.getFields()) {
        match (v.kind()) {
            case JsonKind.JsObject => st.devkitComponents.add(k, devkitFromJson(k, v.asObject()))
            case _ => ()
        }
    }
}

func fillSnapshotInto(st: InstallState, sno: JsonObject): Unit {
    st.snapshot = SnapshotState(exists: getBool(sno, "exists", false),
                                path: getStr(sno, "path", ""), at: getOptStr(sno, "at"))
}

func fillCorruptionInto(st: InstallState, co: JsonObject): Unit {
    st.corruption = CorruptionState(recovered: getBool(co, "recovered", false),
                                   backupPath: getOptStr(co, "backupPath"))
}

func degradedFromJson(do_: JsonObject): DegradedItem {
    return DegradedItem(id: getStr(do_, "id", ""), reason: getStr(do_, "reason", ""),
                        fallback: getStr(do_, "fallback", ""), manualCmd: getStr(do_, "manualCmd", ""))
}

func fillDegradedInto(st: InstallState, arr: JsonArray): Unit {
    for (d in arr.getItems()) {
        match (d.kind()) {
            case JsonKind.JsObject => st.degraded.add(degradedFromJson(d.asObject()))
            case _ => ()
        }
    }
}

func parseRootObject(root: JsonObject): Option<InstallState> {
    let installRoot = getStr(root, "installRoot", "")
    let releaseDir = getStr(root, "releaseDir", "")
    if (installRoot.isEmpty() || releaseDir.isEmpty()) {
        return None<InstallState>
    }
    let st = freshState(installRoot, releaseDir)
    st.schemaVersion = getInt(root, "schemaVersion", SCHEMA_VERSION)
    if (st.schemaVersion > SCHEMA_VERSION) {
        return None<InstallState>
    }
    st.installerVersion = getStr(root, "installerVersion", "1.0.0")
    st.mode = getStr(root, "mode", MODE_ENDUSER)
    st.currentStep = getStr(root, "currentStep", "S0")
    st.port = getInt(root, "port", 3000)
    st.runtimeVersion = getStr(root, "runtimeVersion", "")
    st.devkit = getStr(root, "devkit", DEVKIT_PENDING)
    st.mediaSource = getStr(root, "mediaSource", MEDIA_LOCAL)

    match (getObj(root, "steps")) { case Some(so) => fillStepsInto(st, so); case None => () }
    match (getObj(root, "devkitComponents")) { case Some(dko) => fillDevkitInto(st, dko); case None => () }
    match (getObj(root, "snapshot")) { case Some(sno) => fillSnapshotInto(st, sno); case None => () }
    match (getObj(root, "corruption")) { case Some(co) => fillCorruptionInto(st, co); case None => () }
    match (root.get("degraded")) {
        case Some(darr) => match (darr.kind()) {
            case JsonKind.JsArray => fillDegradedInto(st, darr.asArray())
            case _ => ()
        }
        case None => ()
    }
    ensureSteps(st)
    return Some(st)
}

/// 从 JSON 文本解析状态；无法解析（schema 不可识别 / 缺关键字段）返回 None。
public func installStateFromJson(text: String): Option<InstallState> {
    try {
        let parsed = JsonValue.fromStr(text)
        return match (parsed.kind()) {
            case JsonKind.JsObject => parseRootObject(parsed.asObject())
            case _ => None<InstallState>
        }
    } catch (_: Exception) {
        return None<InstallState>
    }
}

/// 生成一份全新的状态（S0~S8 全部 pending）。
public func freshState(installRoot: String, releaseDir: String): InstallState {
    let st = InstallState()
    st.installRoot = installRoot
    st.releaseDir = releaseDir
    for (i in 0..9) {
        let id = "S${i}"
        st.steps.add(id, StepState(id: id, status: STEP_PENDING, at: None<String>, evidence: StepEvidence()))
    }
    return st
}

/// 确保 steps 包含 S0~S8（缺失补 pending）。
func ensureSteps(st: InstallState): Unit {
    for (i in 0..9) {
        let id = "S${i}"
        if (!st.steps.contains(id)) {
            st.steps.add(id, StepState(id: id, status: STEP_PENDING, at: None<String>, evidence: StepEvidence()))
        }
    }
}

// ===================== StateStore =====================

func recoverCorrupt(path: Path, text: String): StateStore {
    let backup = backupCorrupt(path, text)
    let st = freshState("", "")
    st.installRoot = path.parent.toString()
    st.releaseDir = path.parent.join("release").toString()
    st.corruption = CorruptionState(recovered: true, backupPath: backup)
    return StateStore(st, path)
}

/// 状态存储：封装原子写与损坏恢复。
public class StateStore {
    public var state: InstallState
    public let path: Path

    public init(state: InstallState, path: Path) {
        this.state = state
        this.path = path
    }

    /// 打开状态文件；不存在则初始化全新状态；解析失败/不可识别则备份并进入损坏恢复。
    public static func open(path: Path): StateStore {
        if (exists(path)) {
            try {
                let info = FileInfo(path)
                let buf = Array<Byte>(info.size, repeat: 0)
                let f = File(path, OpenMode.Read)
                f.read(buf)
                f.close()
                let text = String.fromUtf8(buf)
                match (installStateFromJson(text)) {
                    case Some(s) => return StateStore(s, path)
                    case None => return recoverCorrupt(path, text)
                }
            } catch (_: Exception) {
                let st = freshState("", "")
                st.installRoot = path.parent.toString()
                st.releaseDir = path.parent.join("release").toString()
                st.corruption = CorruptionState(recovered: true, backupPath: None<String>)
                return StateStore(st, path)
            }
        }
        let st = freshState(path.parent.toString(), path.parent.join("release").toString())
        return StateStore(st, path)
    }

    /// 原子写：临时文件 → fsync → rename（AC-010）。
    public func save(): Unit {
        let text = installStateToJson(state)
        let tmp = Path(path.toString() + ".tmp")
        let f = File(tmp, OpenMode.Write)
        f.write(text.toArray())
        f.close()
        rename(tmp, to: path, overwrite: true)
    }

    /// 标记某步骤状态并立即持久化。
    public func markStep(id: String, status: String, at: Option<String>,
                         evidence: HashMap<String, String>): Unit {
        let ss = StepState(id: id, status: status, at: at, evidence: StepEvidence(items: evidence))
        state.steps.add(id, ss)
        save()
    }

    /// 记录降级项并立即持久化。
    public func addDegraded(item: DegradedItem): Unit {
        state.degraded.add(item)
        save()
    }
}

/// 把损坏文件备份为 `.install-state.corrupt-<ts>.json`。返回备份路径（失败时 None）。
func backupCorrupt(path: Path, content: String): Option<String> {
    try {
        let ts = DateTime.now().toString().replace(":", "-")
        let bak = Path(path.toString() + ".corrupt-${ts}.json")
        let f = File(bak, OpenMode.Write)
        f.write(content.toArray())
        f.close()
        return Some(bak.toString())
    } catch (_: Exception) {
        return None<String>
    }
}
