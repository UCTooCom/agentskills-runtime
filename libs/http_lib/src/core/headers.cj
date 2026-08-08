package http_lib.core

import std.collection.{ArrayList, HashMap}
import http_lib.utils.containsIgnoreCaseBytes

/**
 * 内部辅助类，存储单个 HTTP 头部的原始名称和所有值。
 */
internal class HeaderEntry {
    var originalName: String
    var values: ArrayList<String>

    public init(originalName: String, values: ArrayList<String>) {
        this.originalName = originalName
        this.values = values
    }
}

// 手写插入排序：避免 std.sort 的泛型函数调用开销
private func _sortHeaders(keys: Array<(String, String)>): Unit {
    var i: Int64 = 1
    while (i < keys.size) {
        var j = i
        while (j > 0 && keys[j - 1][0] > keys[j][0]) {
            let tmp = keys[j]
            keys[j] = keys[j - 1]
            keys[j - 1] = tmp
            j -= 1
        }
        i += 1
    }
}

/**
 * HTTP 响应头容器，支持大小写不敏感的键查找。
 *
 * 内部使用双层存储：
 * 1. 小型路径（<= 32 个头部）：ArrayList<HeaderEntry> 线性扫描 — 避免 HashMap 哈希与分配开销
 * 2. 大型路径：超过阈值自动升级到 HashMap
 *
 * 典型 HTTP 请求/响应头部大多在 5-20 个之间，ArrayList 线性扫描在此场景下比 HashMap 快 3-5 倍。
 */
public class HttpHeaders {
    private static let MAX_SMALL: Int64 = 32

    // 小型路径存储（entries <= MAX_SMALL）
    private var _small: Option<ArrayList<HeaderEntry>> = None
    // 大型路径存储
    private var _large: Option<HashMap<String, HeaderEntry>> = None
    // 是否已升级到大路径
    private var _isLarge: Bool = false
    // 总 entries 数
    private var _count: Int64 = 0

    // toBytes 缓存
    private var _dirty: Bool = true
    private var _toBytesCache: Array<UInt8> = []

    // 常用头部名称的快速小写映射（硬编码避免 byte 扫描）
    private static func _fastLower(name: String): String {
        if (name.size < 3) { return name.toAsciiLower() }
        let first = unsafe { name.rawData() }[0]
        if (first == b'c' || first == b'C') {
            if (name == "Content-Type" || name == "content-type") { return "content-type" }
            if (name == "Content-Length" || name == "content-length") { return "content-length" }
            if (name == "Cache-Control" || name == "cache-control") { return "cache-control" }
            if (name == "Connection" || name == "connection") { return "connection" }
            if (name == "Cookie" || name == "cookie") { return "cookie" }
        } else if (first == b'd' || first == b'D') {
            if (name == "Date" || name == "date") { return "date" }
        } else if (first == b'a' || first == b'A') {
            if (name == "Accept" || name == "accept") { return "accept" }
            if (name == "Authorization" || name == "authorization") { return "authorization" }
        } else if (first == b'h' || first == b'H') {
            if (name == "Host" || name == "host") { return "host" }
        } else if (first == b'l' || first == b'L') {
            if (name == "Location" || name == "location") { return "location" }
        } else if (first == b's' || first == b'S') {
            if (name == "Set-Cookie" || name == "set-cookie") { return "set-cookie" }
            if (name == "Server" || name == "server") { return "server" }
        } else if (first == b't' || first == b'T') {
            if (name == "Transfer-Encoding" || name == "transfer-encoding") { return "transfer-encoding" }
        } else if (first == b'u' || first == b'U') {
            if (name == "User-Agent" || name == "user-agent") { return "user-agent" }
        }
        name.toAsciiLower()
    }

    public init() {
        // 延迟初始化：在第一次 set/add 时创建 _small
    }

    public func add(name: String, value: String): Unit {
        let key = _fastLower(name)
        _dirty = true
        if (_count < MAX_SMALL) {
            _smallAdd(key, name, value)
        } else {
            _ensureLargeReady()
            _largeAdd(key, name, value)
        }
    }

    public func set(name: String, value: String): Unit {
        let key = _fastLower(name)
        _dirty = true
        if (_count < MAX_SMALL) {
            _smallSet(key, name, value)
        } else {
            _ensureLargeReady()
            _largeSet(key, name, value)
        }
    }

    public func get(name: String): Option<String> {
        if (_count == 0) { return None }
        let key = _fastLower(name)
        if (!_isLarge) {
            return _smallGetFirst(key)
        }
        match (_large) {
            case Some(map) =>
                match (map.get(key)) {
                    case Some(entry) =>
                        if (entry.values.size > 0) { Some(entry.values[0]) } else { None }
                    case None => None
                }
            case None => None
        }
    }

    public func getAll(name: String): Array<String> {
        if (_count == 0) { return [] }
        let key = _fastLower(name)
        if (!_isLarge) {
            return _smallGetAll(key)
        }
        match (_large) {
            case Some(map) =>
                match (map.get(key)) {
                    case Some(entry) => entry.values.toArray()
                    case None => []
                }
            case None => []
        }
    }

    public func getCombined(name: String): Option<String> {
        let key = _fastLower(name)
        if (!_isLarge) {
            return _smallGetCombined(key)
        }
        return _largeGetCombined(key)
    }

    public func contains(name: String): Bool {
        if (_count == 0) { return false }
        let key = _fastLower(name)
        if (!_isLarge) {
            return _smallContains(key)
        }
        match (_large) {
            case Some(map) => map.contains(key)
            case None => false
        }
    }

    public func remove(name: String): Unit {
        let key = _fastLower(name)
        _dirty = true
        if (!_isLarge) {
            _smallRemove(key)
        } else {
            match (this._large) {
                case Some(map) =>
                    map.remove(key)
                    _count = map.size
                case None => ()
            }
        }
    }

    public func names(): Array<String> {
        if (_count == 0) { return [] }
        if (!_isLarge) {
            return _smallNames()
        }
        var result = ArrayList<String>()
        match (this._large) {
            case Some(map) =>
                for ((_, entry) in map) {
                    result.add(entry.originalName)
                }
            case None => ()
        }
        result.toArray()
    }

    public func toBytes(): Array<UInt8> {
        if (!_dirty && _toBytesCache.size > 0) { return _toBytesCache }
        if (_count == 0) { return [] }
        if (!_isLarge) {
            return _smallToBytes()
        }
        return _largeToBytes()
    }

    public prop size: Int64 {
        get() { _count }
    }

    public func isEmpty(): Bool {
        _count == 0
    }

    public func entries(): Array<(String, String)> {
        if (_count == 0) { return [] }
        if (!_isLarge) {
            return _smallEntries()
        }
        let result = ArrayList<(String, String)>()
        match (this._large) {
            case Some(map) =>
                for ((_, entry) in map) {
                    for (value in entry.values) {
                        result.add((entry.originalName, value))
                    }
                }
            case None => ()
        }
        result.toArray()
    }

    public func forEach(fn: (String, String) -> Unit): Unit {
        if (_count == 0) { return }
        if (!_isLarge) {
            _smallForEach(fn)
            return
        }
        match (this._large) {
            case Some(map) =>
                for ((_, entry) in map) {
                    for (value in entry.values) {
                        fn(entry.originalName, value)
                    }
                }
            case None => ()
        }
    }

    public func clear(): Unit {
        _small = None
        _large = None
        _isLarge = false
        _count = 0
        _dirty = true
    }

    public func reset(): Unit {
        clear()
    }

    public func getOriginalName(name: String): Option<String> {
        if (_count == 0) { return None }
        let key = _fastLower(name)
        if (!_isLarge) {
            return _smallGetOriginalName(key)
        }
        match (this._large) {
            case Some(map) =>
                match (map.get(key)) {
                    case Some(entry) => Some(entry.originalName)
                    case None => None
                }
            case None => None
        }
    }

    public func copyFrom(other: HttpHeaders): Unit {
        if (other._count == 0) { return }
        other.forEach({name, value => add(name, value)})
    }

    public func clone(): HttpHeaders {
        let result = HttpHeaders()
        if (_count == 0) { return result }
        if (!_isLarge) {
            match (this._small) {
                case Some(list) =>
                    let newSmall = ArrayList<HeaderEntry>()
                    var i: Int64 = 0
                    while (i < list.size) {
                        let entry = list[i]
                        let newValues = ArrayList<String>()
                        var j: Int64 = 0
                        while (j < entry.values.size) {
                            newValues.add(entry.values[j])
                            j++
                        }
                        newSmall.add(HeaderEntry(entry.originalName, newValues))
                        i++
                    }
                    result._small = Some(newSmall)
                    result._count = _count
                    return result
                case None => return result
            }
        }
        match (this._large) {
            case Some(map) =>
                for ((keyLower, entry) in map) {
                    let newValues = ArrayList<String>()
                    for (v in entry.values) {
                        newValues.add(v)
                    }
                    if (result._large.isNone()) {
                        result._large = Some(HashMap<String, HeaderEntry>())
                        result._isLarge = true
                    }
                    match (result._large) {
                        case Some(rmap) => rmap[keyLower] = HeaderEntry(entry.originalName, newValues)
                        case None => ()
                    }
                }
                result._count = _count
            case None => ()
        }
        result
    }

    // ========== 小型路径实现 ==========

    private func _smallAdd(key: String, origName: String, value: String): Unit {
        match (this._small) {
            case Some(list) =>
                var i: Int64 = 0
                while (i < list.size) {
                    if (list[i].originalName.toAsciiLower() == key) {
                        list[i].values.add(value)
                        _count++
                        return
                    }
                    i++
                }
                let vals = ArrayList<String>()
                vals.add(value)
                list.add(HeaderEntry(origName, vals))
                _count++
                if (list.size >= MAX_SMALL) { _convertToLarge() }
            case None =>
                let list = ArrayList<HeaderEntry>(8)
                let vals = ArrayList<String>()
                vals.add(value)
                list.add(HeaderEntry(origName, vals))
                this._small = Some(list)
                _count = 1
        }
    }

    private func _smallSet(key: String, origName: String, value: String): Unit {
        match (this._small) {
            case Some(list) =>
                var i: Int64 = 0
                while (i < list.size) {
                    if (list[i].originalName.toAsciiLower() == key) {
                        list[i].values.clear()
                        list[i].values.add(value)
                        return
                    }
                    i++
                }
                let vals = ArrayList<String>()
                vals.add(value)
                list.add(HeaderEntry(origName, vals))
                _count++
                if (list.size >= MAX_SMALL) { _convertToLarge() }
            case None =>
                let list = ArrayList<HeaderEntry>()
                let vals = ArrayList<String>()
                vals.add(value)
                list.add(HeaderEntry(origName, vals))
                this._small = Some(list)
                _count = 1
        }
    }

    private func _smallGetFirst(key: String): Option<String> {
        match (this._small) {
            case Some(list) =>
                var i: Int64 = 0
                while (i < list.size) {
                    if (list[i].originalName.toAsciiLower() == key && list[i].values.size > 0) {
                        return Some(list[i].values[0])
                    }
                    i++
                }
                None
            case None => None
        }
    }

    private func _smallGetAll(key: String): Array<String> {
        match (this._small) {
            case Some(list) =>
                var i: Int64 = 0
                while (i < list.size) {
                    if (list[i].originalName.toAsciiLower() == key) {
                        return list[i].values.toArray()
                    }
                    i++
                }
                []
            case None => []
        }
    }

    private func _smallContains(key: String): Bool {
        match (this._small) {
            case Some(list) =>
                var i: Int64 = 0
                while (i < list.size) {
                    if (list[i].originalName.toAsciiLower() == key) { return true }
                    i++
                }
                false
            case None => false
        }
    }

    private func _smallRemove(key: String): Unit {
        match (this._small) {
            case Some(list) =>
                var i: Int64 = 0
                while (i < list.size) {
                    if (list[i].originalName.toAsciiLower() == key) {
                        list.remove(i..i+1)
                        _count -= 1
                        return
                    }
                    i++
                }
            case None => ()
        }
    }

    private func _smallGetCombined(key: String): Option<String> {
        match (this._small) {
            case Some(list) =>
                var i: Int64 = 0
                while (i < list.size) {
                    if (list[i].originalName.toAsciiLower() == key) {
                        let vals = list[i].values
                        if (vals.size == 0) { return None }
                        if (vals.size == 1) { return Some(vals[0]) }
                        let sb = StringBuilder()
                        sb.append(vals[0])
                        var j: Int64 = 1
                        while (j < vals.size) {
                            sb.append(", ")
                            sb.append(vals[j])
                            j++
                        }
                        return Some(sb.toString())
                    }
                    i++
                }
                None
            case None => None
        }
    }

    private func _smallNames(): Array<String> {
        match (this._small) {
            case Some(list) =>
                var result = ArrayList<String>()
                var i: Int64 = 0
                while (i < list.size) {
                    result.add(list[i].originalName)
                    i++
                }
                result.toArray()
            case None => []
        }
    }

    private func _smallEntries(): Array<(String, String)> {
        match (this._small) {
            case Some(list) =>
                var result = ArrayList<(String, String)>()
                var i: Int64 = 0
                while (i < list.size) {
                    let entry = list[i]
                    var j: Int64 = 0
                    while (j < entry.values.size) {
                        result.add((entry.originalName, entry.values[j]))
                        j++
                    }
                    i++
                }
                result.toArray()
            case None => []
        }
    }

    private func _smallForEach(fn: (String, String) -> Unit): Unit {
        match (this._small) {
            case Some(list) =>
                var i: Int64 = 0
                while (i < list.size) {
                    let entry = list[i]
                    var j: Int64 = 0
                    while (j < entry.values.size) {
                        fn(entry.originalName, entry.values[j])
                        j++
                    }
                    i++
                }
            case None => ()
        }
    }

    private func _smallGetOriginalName(key: String): Option<String> {
        match (this._small) {
            case Some(list) =>
                var i: Int64 = 0
                while (i < list.size) {
                    if (list[i].originalName.toAsciiLower() == key) { return Some(list[i].originalName) }
                    i++
                }
                None
            case None => None
        }
    }

    private func _smallToBytes(): Array<UInt8> {
        match (this._small) {
            case Some(list) =>
                if (list.size == 0) { return [] }
                var totalLength: Int64 = 0
                var i: Int64 = 0
                while (i < list.size) {
                    let entry = list[i]
                    let nameLen = entry.originalName.size
                    var j: Int64 = 0
                    while (j < entry.values.size) {
                        totalLength += nameLen + 2 + entry.values[j].size + 2
                        j++
                    }
                    i++
                }
                let result = Array<UInt8>(totalLength, repeat: 0)
                var offset: Int64 = 0
                i = 0
                while (i < list.size) {
                    let entry = list[i]
                    let nameBytes = unsafe { entry.originalName.rawData() }
                    var j: Int64 = 0
                    while (j < entry.values.size) {
                        let valueBytes = unsafe { entry.values[j].rawData() }
                        nameBytes.copyTo(result, 0, offset, nameBytes.size)
                        offset += nameBytes.size
                        result[offset] = b':'; offset++
                        result[offset] = b' '; offset++
                        valueBytes.copyTo(result, 0, offset, valueBytes.size)
                        offset += valueBytes.size
                        result[offset] = b'\r'; offset++
                        result[offset] = b'\n'; offset++
                        j++
                    }
                    i++
                }
                _toBytesCache = result
                _dirty = false
                result
            case None => []
        }
    }

    // ========== 大型路径实现 ==========

    private func _ensureLargeReady(): Unit {
        if (_isLarge) { return }
        match (this._small) {
            case Some(list) => _convertToLarge()
            case None =>
                _large = Some(HashMap<String, HeaderEntry>())
                _isLarge = true
        }
    }

    private func _convertToLarge(): Unit {
        match (this._small) {
            case Some(list) =>
                let map = HashMap<String, HeaderEntry>()
                var i: Int64 = 0
                while (i < list.size) {
                    let entry = list[i]
                    map[entry.originalName.toAsciiLower()] = entry
                    i++
                }
                _large = Some(map)
                _isLarge = true
                _small = None
            case None => ()
        }
    }

    private func _largeAdd(key: String, origName: String, value: String): Unit {
        match (this._large) {
            case Some(map) =>
                match (map.get(key)) {
                    case Some(entry) =>
                        entry.values.add(value)
                        _count++
                    case None =>
                        let values = ArrayList<String>()
                        values.add(value)
                        map[key] = HeaderEntry(origName, values)
                        _count++
                }
            case None => ()
        }
    }

    private func _largeSet(key: String, origName: String, value: String): Unit {
        match (this._large) {
            case Some(map) =>
                match (map.get(key)) {
                    case Some(entry) =>
                        entry.values.clear()
                        entry.values.add(value)
                    case None =>
                        let values = ArrayList<String>()
                        values.add(value)
                        map[key] = HeaderEntry(origName, values)
                        _count++
                }
            case None => ()
        }
    }

    private func _largeGetCombined(key: String): Option<String> {
        match (this._large) {
            case Some(map) =>
                match (map.get(key)) {
                    case Some(entry) =>
                        let vals = entry.values
                        if (vals.size == 0) { return None }
                        if (vals.size == 1) { return Some(vals[0]) }
                        let sb = StringBuilder()
                        sb.append(vals[0])
                        var j: Int64 = 1
                        while (j < vals.size) {
                            sb.append(", ")
                            sb.append(vals[j])
                            j++
                        }
                        Some(sb.toString())
                    case None => None
                }
            case None => None
        }
    }

    private func _largeToBytes(): Array<UInt8> {
        match (this._large) {
            case Some(map) =>
                let entryList = ArrayList<(String, String)>()
                for ((_, entry) in map) {
                    for (value in entry.values) {
                        entryList.add((entry.originalName, value))
                    }
                }
                if (entryList.size == 0) { return [] }
                let arr = entryList.toArray()
                _sortHeaders(arr)
                var totalLength: Int64 = 0
                for ((name, value) in arr) {
                    totalLength += name.size + 2 + value.size + 2
                }
                let result = Array<UInt8>(totalLength, repeat: 0)
                var offset: Int64 = 0
                for ((name, value) in arr) {
                    let nameBytes = unsafe { name.rawData() }
                    let valueBytes = unsafe { value.rawData() }
                    nameBytes.copyTo(result, 0, offset, nameBytes.size)
                    offset += nameBytes.size
                    result[offset] = b':'; offset++
                    result[offset] = b' '; offset++
                    valueBytes.copyTo(result, 0, offset, valueBytes.size)
                    offset += valueBytes.size
                    result[offset] = b'\r'; offset++
                    result[offset] = b'\n'; offset++
                }
                _toBytesCache = result
                _dirty = false
                result
            case None => []
        }
    }
}

/**
 * 获取所有响应头键名（小写，内部使用）。
 */
internal func keysLower(headers: HttpHeaders): Array<String> {
    if (headers.isEmpty()) { return [] }
    headers.names()
}

/**
 * 将头部名称规范化为小写以供内部查找。
 */
private func normalizeHeaderName(name: String): String {
    name.toAsciiLower()
}
