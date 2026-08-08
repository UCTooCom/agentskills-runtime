package kaca_json

import std.collection.*

public enum PatchOp {
    | Add
    | Remove
    | Replace
    | Move
    | Copy
    | Test
}

public class PatchOperation {
    public var op: PatchOp
    public var path: String
    public var value: ?JsonValue = None
    public var fromPath: ?String = None
    private var cachedPathText: ?String = None
    private var cachedPathParts: ?ArrayList<String> = None
    private var cachedFromPathText: ?String = None
    private var cachedFromPathParts: ?ArrayList<String> = None
    
    public init(op: PatchOp, path: String) {
        this.op = op
        this.path = path
    }
    
    public static func add(path: String, value: JsonValue): PatchOperation {
        let patch = PatchOperation(PatchOp.Add, path)
        patch.value = value
        patch
    }
    
    public static func remove(path: String): PatchOperation {
        PatchOperation(PatchOp.Remove, path)
    }
    
    public static func replace(path: String, value: JsonValue): PatchOperation {
        let patch = PatchOperation(PatchOp.Replace, path)
        patch.value = value
        patch
    }
    
    public static func move(from: String, path: String): PatchOperation {
        let patch = PatchOperation(PatchOp.Move, path)
        patch.fromPath = from
        patch
    }
    
    public static func copy(from: String, path: String): PatchOperation {
        let patch = PatchOperation(PatchOp.Copy, path)
        patch.fromPath = from
        patch
    }
    
    public static func test(path: String, value: JsonValue): PatchOperation {
        let patch = PatchOperation(PatchOp.Test, path)
        patch.value = value
        patch
    }

    public func getPathParts(): ArrayList<String> {
        let currentPath = path
        if (let Some(cachedText) <- cachedPathText) {
            if (cachedText == currentPath) {
                if (let Some(parts) <- cachedPathParts) {
                    return parts
                }
            }
        }

        let parsed = parsePath(currentPath)
        cachedPathText = Some(currentPath)
        cachedPathParts = Some(parsed)
        parsed
    }

    public func getFromPathParts(): ?ArrayList<String> {
        let fromOpt = fromPath
        if (let Some(from) <- fromOpt) {
            if (let Some(cachedText) <- cachedFromPathText) {
                if (cachedText == from) {
                    if (let Some(parts) <- cachedFromPathParts) {
                        return parts
                    }
                }
            }

            let parsed = parsePath(from)
            cachedFromPathText = Some(from)
            cachedFromPathParts = Some(parsed)
            return parsed
        }

        None
    }
}

public class JsonPatchError <: Exception {
    public let errMsg: String
    
    public init(msg: String) {
        this.errMsg = msg
    }
}

public func jsonPatch(value: JsonValue, operations: ArrayList<PatchOperation>): JsonValue {
    var result = deepClone(value)
    
    for (op in operations) {
        result = applyPatchOperation(result, op)
    }
    
    result
}

private func applyPatchOperation(value: JsonValue, op: PatchOperation): JsonValue {
    match (op.op) {
        case PatchOp.Add => applyAdd(value, op)
        case PatchOp.Remove => applyRemovePath(value, op.getPathParts())
        case PatchOp.Replace => applyReplace(value, op)
        case PatchOp.Move => applyMove(value, op)
        case PatchOp.Copy => applyCopy(value, op)
        case PatchOp.Test => applyTest(value, op)
    }
}

private func applyAdd(value: JsonValue, op: PatchOperation): JsonValue {
    let valOpt = op.value
    if (let Some(val) <- valOpt) {
        return applyAddPath(value, op.getPathParts(), val)
    }
    
    throw JsonPatchError("Add operation requires 'value'")
}

private func applyAddPath(value: JsonValue, pathParts: ArrayList<String>, val: JsonValue): JsonValue {
    if (pathParts.size == 0) {
        return val
    }

    addAtPath(value, pathParts, 0, val)
    value
}

private func addAtPath(value: JsonValue, pathParts: ArrayList<String>, index: Int64, newValue: JsonValue): Unit {
    if (index >= pathParts.size) {
        return
    }
    
    let part = pathParts[index]
    let isLast = index == pathParts.size - 1
    
    if (part == "-") {
        if (isLast && value.isArray()) {
            if (let Some(arr) <- value.getArray()) {
                arr.add(newValue)
            }
        }
        return
    }
    
    if (value.isArray()) {
        if (let Some(arr) <- value.getArray()) {
            let idx = parseIndex(part)
            if (idx >= 0) {
                if (isLast) {
                    insertAt(arr, idx, newValue)
                } else if (idx < arr.size) {
                    addAtPath(arr[idx], pathParts, index + 1, newValue)
                }
            }
        }
    } else if (value.isObject()) {
        if (isLast) {
            if (let Some(obj) <- value.getObject()) {
                setField(obj, part, newValue)
            }
        } else {
            if (let Some(obj) <- value.getObject()) {
                let childOpt = getField(obj, part)
                if (let Some(child) <- childOpt) {
                    addAtPath(child, pathParts, index + 1, newValue)
                }
            }
        }
    }
}

private func applyRemovePath(value: JsonValue, pathParts: ArrayList<String>): JsonValue {
    if (pathParts.size == 0) {
        throw JsonPatchError("Cannot remove root")
    }

    removeAtPath(value, pathParts, 0)
    value
}

private func removeAtPath(value: JsonValue, pathParts: ArrayList<String>, index: Int64): Unit {
    if (index >= pathParts.size) {
        return
    }
    
    let part = pathParts[index]
    let isLast = index == pathParts.size - 1
    
    if (value.isArray()) {
        if (let Some(arr) <- value.getArray()) {
            let idx = parseIndex(part)
            if (idx >= 0 && idx < arr.size) {
                if (isLast) {
                    removeAt(arr, idx)
                } else {
                    removeAtPath(arr[idx], pathParts, index + 1)
                }
            }
        }
    } else if (value.isObject()) {
        if (let Some(obj) <- value.getObject()) {
            if (isLast) {
                obj.remove(part)
            } else {
                let childOpt = getField(obj, part)
                if (let Some(child) <- childOpt) {
                    removeAtPath(child, pathParts, index + 1)
                }
            }
        }
    }
}

private func applyReplace(value: JsonValue, op: PatchOperation): JsonValue {
    let valOpt = op.value
    if (let Some(val) <- valOpt) {
        return applyReplacePath(value, op.getPathParts(), val)
    }
    
    throw JsonPatchError("Replace operation requires 'value'")
}

private func applyReplacePath(value: JsonValue, pathParts: ArrayList<String>, val: JsonValue): JsonValue {
    if (pathParts.size == 0) {
        return val
    }

    replaceAtPath(value, pathParts, 0, val)
    value
}

private func replaceAtPath(value: JsonValue, pathParts: ArrayList<String>, index: Int64, newValue: JsonValue): Unit {
    if (index >= pathParts.size) {
        return
    }
    
    let part = pathParts[index]
    let isLast = index == pathParts.size - 1
    
    if (value.isArray()) {
        if (let Some(arr) <- value.getArray()) {
            let idx = parseIndex(part)
            if (idx >= 0 && idx < arr.size) {
                if (isLast) {
                    arr[idx] = newValue
                } else {
                    replaceAtPath(arr[idx], pathParts, index + 1, newValue)
                }
            }
        }
    } else if (value.isObject()) {
        if (let Some(obj) <- value.getObject()) {
            if (isLast) {
                setField(obj, part, newValue)
            } else {
                let childOpt = getField(obj, part)
                if (let Some(child) <- childOpt) {
                    replaceAtPath(child, pathParts, index + 1, newValue)
                }
            }
        }
    }
}

private func applyMove(value: JsonValue, op: PatchOperation): JsonValue {
    let fromPathOpt = op.getFromPathParts()
    if (let Some(fromPath) <- fromPathOpt) {
        let fromValueOpt = getValueAtPath(value, fromPath, 0)

        if (let Some(fromValue) <- fromValueOpt) {
            // movedValue = fromValue (no clone needed, value already cloned at jsonPatch entry)
            let removed = applyRemovePath(value, fromPath)
            return applyAddPath(removed, op.getPathParts(), fromValue)
        }

        throw JsonPatchError("Source path not found")
    }

    throw JsonPatchError("Move operation requires 'from'")
}

private func applyCopy(value: JsonValue, op: PatchOperation): JsonValue {
    let fromPathOpt = op.getFromPathParts()
    if (let Some(fromPath) <- fromPathOpt) {
        let fromValueOpt = getValueAtPath(value, fromPath, 0)
        
        if (let Some(fromValue) <- fromValueOpt) {
            let clonedValue = deepClone(fromValue)
            return applyAddPath(value, op.getPathParts(), clonedValue)
        }
        
        throw JsonPatchError("Source path not found")
    }
    
    throw JsonPatchError("Copy operation requires 'from'")
}

private func applyTest(value: JsonValue, op: PatchOperation): JsonValue {
    let valOpt = op.value
    if (let Some(val) <- valOpt) {
        let pathParts = op.getPathParts()
        let actualValueOpt = getValueAtPath(value, pathParts, 0)
        
        if (let Some(av) <- actualValueOpt) {
            if (!jsonValuesEqual(av, val)) {
                throw JsonPatchError("Test failed: values not equal")
            }
            return value
        }
        
        throw JsonPatchError("Test path not found")
    }
    
    throw JsonPatchError("Test operation requires 'value'")
}

private func getValueAtPath(value: JsonValue, pathParts: ArrayList<String>, index: Int64): ?JsonValue {
    if (index >= pathParts.size) {
        return value
    }
    
    let part = pathParts[index]
    
    if (value.isArray()) {
        if (let Some(arr) <- value.getArray()) {
            let idx = parseIndex(part)
            if (idx >= 0 && idx < arr.size) {
                return getValueAtPath(arr[idx], pathParts, index + 1)
            }
        }
    } else if (value.isObject()) {
        if (let Some(obj) <- value.getObject()) {
            let childOpt = getField(obj, part)
            if (let Some(child) <- childOpt) {
                return getValueAtPath(child, pathParts, index + 1)
            }
        }
    }
    
    None
}

private func parsePath(path: String): ArrayList<String> {
    let parts = ArrayList<String>()
    
    if (path.size == 0 || path == "/") {
        return parts
    }
    
    let bytes = stringToBytes(path)
    let len = bytes.size
    var i: Int64 = 0
    
    if (i < len && bytes[i] == 0x2F) {
        i++
    }
    
    let current = ByteBuilder(32)
    
    while (i < len) {
        let b = bytes[i]
        if (b == 0x2F) {
            parts.add(current.build())
            current.clear()
        } else if (b == 0x7E) {
            if (i + 1 < len) {
                let next = bytes[i + 1]
                if (next == 0x30) {
                    current.append(0x7E)
                    i++
                } else if (next == 0x31) {
                    current.append(0x2F)
                    i++
                } else {
                    current.append(b)
                }
            } else {
                current.append(b)
            }
        } else {
            current.append(b)
        }
        i++
    }
    
    let remaining = current.build()
    if (remaining.size > 0) {
        parts.add(remaining)
    }
    
    parts
}

private func parseIndex(part: String): Int64 {
        let bytes = stringToBytes(part)
        var result: Int64 = 0
        var valid: Bool = true
        
        for (b in bytes) {
            if (UInt8(b) >= 48 && UInt8(b) <= 57) {
                result = result * 10 + Int64(UInt8(b) - 48)
            } else {
                valid = false
                break
            }
        }
        
        if (valid && bytes.size > 0) {
            return result
        }
        
        -1
    }

private func deepClone(value: JsonValue): JsonValue {
    match (value) {
        case JsonNull => JsonValue.JsonNull
        case JsonBool(b) => JsonValue.JsonBool(b)
        case JsonNumber(n) => JsonValue.JsonNumber(n)
        case JsonString(s) => JsonValue.JsonString(s)
        case JsonArray(arr) => cloneArray(arr)
        case JsonObject(obj) => cloneObject(obj)
    }
}

private func cloneArray(arr: ArrayList<JsonValue>): JsonValue {
    let newArr = ArrayList<JsonValue>()
    for (item in arr) {
        newArr.add(deepClone(item))
    }
    JsonValue.JsonArray(newArr)
}

private func cloneObject(obj: HashMap<String, JsonValue>): JsonValue {
    let newObj = HashMap<String, JsonValue>()
    for ((k, v) in obj) {
        newObj[k] = deepClone(v)
    }
    JsonValue.JsonObject(newObj)
}

private func insertAt(arr: ArrayList<JsonValue>, index: Int64, value: JsonValue): Unit {
    arr.add(value)
    let size = arr.size
    var i: Int64 = size - 2
    while (i >= index) {
        arr[i + 1] = arr[i]
        i--
    }
    arr[index] = value
}

private func removeAt(arr: ArrayList<JsonValue>, index: Int64): Unit {
    let size = arr.size
    var i: Int64 = index
    while (i < size - 1) {
        arr[i] = arr[i + 1]
        i++
    }
    arr.remove(arr.size - 1..arr.size)
}

private func getField(obj: HashMap<String, JsonValue>, key: String): ?JsonValue {
    obj.get(key)
}

private func setField(obj: HashMap<String, JsonValue>, key: String, value: JsonValue): Unit {
    obj[key] = value
}

private func jsonValuesEqual(a: JsonValue, b: JsonValue): Bool {
    match (a) {
        case JsonNull =>
            match (b) {
                case JsonNull => true
                case _ => false
            }
        case JsonBool(ba) =>
            match (b) {
                case JsonBool(bb) => ba == bb
                case _ => false
            }
        case JsonNumber(na) =>
            match (b) {
                case JsonNumber(nb) => na == nb
                case _ => false
            }
        case JsonString(sa) =>
            match (b) {
                case JsonString(sb) => sa == sb
                case _ => false
            }
        case JsonArray(arrA) =>
            match (b) {
                case JsonArray(arrB) => arraysEqual(arrA, arrB)
                case _ => false
            }
        case JsonObject(objA) =>
            match (b) {
                case JsonObject(objB) => objectsEqual(objA, objB)
                case _ => false
            }
    }
}

private func arraysEqual(a: ArrayList<JsonValue>, b: ArrayList<JsonValue>): Bool {
    if (a.size != b.size) {
        return false
    }
    
    var i: Int64 = 0
    while (i < a.size) {
        if (!jsonValuesEqual(a[i], b[i])) {
            return false
        }
        i++
    }
    
    true
}

private func objectsEqual(a: HashMap<String, JsonValue>, b: HashMap<String, JsonValue>): Bool {
    if (a.size != b.size) {
        return false
    }
    
    for ((k, v) in a) {
        let bValueOpt = b.get(k)
        if (let Some(bv) <- bValueOpt) {
            if (!jsonValuesEqual(v, bv)) {
                return false
            }
        } else {
            return false
        }
    }
    
    true
}

