package kaca_json

import std.collection.*

enum PathSegment {
    | Root
    | Field(String)
    | Index(Int64)
    | Wildcard
    | RecursiveDescent
}

private let JSON_PATH_CACHE_MAX: Int64 = 256
private let JSON_PATH_CACHE: HashMap<String, JsonPath> = HashMap<String, JsonPath>()

class JsonPath {
    private var segments: ArrayList<PathSegment>
    
    public JsonPath() {
        this.segments = ArrayList<PathSegment>()
        this.segments.add(PathSegment.Root)
    }
    
    public static func parse(path: String): JsonPath {
        let parser = PathParser(path)
        parser.parse()
    }
    
    public func query(value: JsonValue): ArrayList<JsonValue> {
        var currentValues = ArrayList<JsonValue>()
        currentValues.add(value)
        
        var i: Int64 = 1
        while (i < segments.size) {
            let segment = segments[i]
            let nextValues = ArrayList<JsonValue>()
            
            for (val in currentValues) {
                applySegmentInto(val, segment, nextValues)
            }
            
            currentValues = nextValues
            if (currentValues.size == 0) {
                return currentValues
            }
            i++
        }

        currentValues
    }
    
    public func queryFirst(value: JsonValue): ?JsonValue {
        if (segments.size <= 1) {
            return value
        }

        var currentValues = ArrayList<JsonValue>()
        currentValues.add(value)

        var i: Int64 = 1
        while (i < segments.size) {
            let segment = segments[i]
            let nextValues = ArrayList<JsonValue>()
            let isLast = i == segments.size - 1

            for (val in currentValues) {
                let before = nextValues.size
                applySegmentInto(val, segment, nextValues)
                if (isLast && nextValues.size > before) {
                    return nextValues[before]
                }
            }

            currentValues = nextValues
            if (currentValues.size == 0) {
                return None
            }
            i++
        }

        None
    }
    
    public func addField(name: String): JsonPath {
        segments.add(PathSegment.Field(name))
        this
    }
    
    public func addIndex(index: Int64): JsonPath {
        segments.add(PathSegment.Index(index))
        this
    }
    
    public func addWildcard(): JsonPath {
        segments.add(PathSegment.Wildcard)
        this
    }
    
    public func addRecursive(): JsonPath {
        segments.add(PathSegment.RecursiveDescent)
        this
    }
    
    private func applySegmentInto(value: JsonValue, segment: PathSegment, results: ArrayList<JsonValue>): Unit {
        match (segment) {
            case PathSegment.Field(name) => applyField(value, name, results)
            case PathSegment.Index(index) => applyIndex(value, index, results)
            case PathSegment.Wildcard => applyWildcard(value, results)
            case PathSegment.RecursiveDescent => collectRecursive(value, results)
            case PathSegment.Root => ()
        }
    }
    
    private func applyField(value: JsonValue, name: String, results: ArrayList<JsonValue>): Unit {
        if (!value.isObject()) {
            return
        }
        if (let Some(obj) <- value.getObject()) {
            if (let Some(v) <- obj.get(name)) {
                results.add(v)
            }
        }
    }
    
    private func applyIndex(value: JsonValue, index: Int64, results: ArrayList<JsonValue>): Unit {
        if (!value.isArray()) {
            return
        }
        if (let Some(arr) <- value.getArray()) {
            if (index >= 0 && index < arr.size) {
                results.add(arr[index])
            }
        }
    }
    
    private func applyWildcard(value: JsonValue, results: ArrayList<JsonValue>): Unit {
        if (value.isObject()) {
            if (let Some(obj) <- value.getObject()) {
                for ((_, v) in obj) {
                    results.add(v)
                }
            }
        } else if (value.isArray()) {
            if (let Some(arr) <- value.getArray()) {
                for (item in arr) {
                    results.add(item)
                }
            }
        }
    }
    
    private func collectRecursive(value: JsonValue, results: ArrayList<JsonValue>): Unit {
        results.add(value)
        
        if (value.isObject()) {
            if (let Some(obj) <- value.getObject()) {
                for ((_, v) in obj) {
                    collectRecursive(v, results)
                }
            }
        } else if (value.isArray()) {
            if (let Some(arr) <- value.getArray()) {
                for (item in arr) {
                    collectRecursive(item, results)
                }
            }
        }
    }
}

class PathParser {
    private var bytes: Array<Byte>
    private var pos: Int64 = 0
    private let len: Int64
    
    public PathParser(input: String) {
        this.bytes = stringToBytes(input)
        this.len = bytes.size
    }
    
    public func parse(): JsonPath {
        let path = JsonPath()
        
        if (pos < len && bytes[pos] == 0x24) {
            pos++
        }
        
        while (pos < len) {
            let b = bytes[pos]
            
            if (b == 0x2E) {
                pos++
                if (pos < len && bytes[pos] == 0x2E) {
                    pos++
                    path.addRecursive()
                    if (pos < len) {
                        let field = parseField()
                        if (field.size > 0) {
                            path.addField(field)
                        }
                    }
                } else {
                    let field = parseField()
                    if (field.size > 0) {
                        path.addField(field)
                    }
                }
            } else if (b == 0x5B) {
                pos++
                skipWhitespace()
                
                if (pos < len) {
                    if (bytes[pos] == 0x2A) {
                        pos++
                        path.addWildcard()
                    } else if (bytes[pos] == 0x27) {
                        pos++
                        let field = parseQuotedField()
                        path.addField(field)
                    } else if (isDigitByte(bytes[pos])) {
                        let index = parseNumber()
                        path.addIndex(index)
                    }
                }
                
                skipWhitespace()
                if (pos < len && bytes[pos] == 0x5D) {
                    pos++
                }
            } else {
                pos++
            }
        }
        
        path
    }
    
    private func parseField(): String {
        let output = ByteBuilder(32)
        while (pos < len) {
            let b = bytes[pos]
            if (b == 0x2E || b == 0x5B || b == 0x20) {
                break
            }
            output.append(b)
            pos++
        }
        output.build()
    }
    
    private func parseQuotedField(): String {
        let output = ByteBuilder(32)
        while (pos < len && bytes[pos] != 0x27) {
            output.append(bytes[pos])
            pos++
        }
        if (pos < len && bytes[pos] == 0x27) {
            pos++
        }
        output.build()
    }
    
    private func parseNumber(): Int64 {
        var result: Int64 = 0
        while (pos < len && isDigitByte(bytes[pos])) {
            result = result * 10 + Int64(UInt8(bytes[pos]) - 48)
            pos++
        }
        result
    }
    
    private func skipWhitespace(): Unit {
        while (pos < len) {
            let b = bytes[pos]
            if (b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D) {
                pos++
            } else {
                return
            }
        }
    }
}

public func jsonPath(value: JsonValue, path: String): ArrayList<JsonValue> {
    let p = getCachedJsonPath(path)
    p.query(value)
}

public func jsonPathFirst(value: JsonValue, path: String): ?JsonValue {
    let p = getCachedJsonPath(path)
    p.queryFirst(value)
}

private func getCachedJsonPath(path: String): JsonPath {
    if (let Some(cached) <- JSON_PATH_CACHE.get(path)) {
        return cached
    }

    let parsed = JsonPath.parse(path)
    if (JSON_PATH_CACHE.size >= JSON_PATH_CACHE_MAX) {
        JSON_PATH_CACHE.clear()
    }
    JSON_PATH_CACHE[path] = parsed
    parsed
}

