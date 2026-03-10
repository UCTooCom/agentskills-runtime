/**
 * @file
 * This file is about resolve.
 */

package yaml4cj.yaml

let longTagPrefix = "tag:yaml.org,2002:"

var resolveInited = false
let resolveTable = Array<UInt8>(256, repeat: 0)
let resolveMap = HashMap<String, ResolveMapItem>()

open class ResolveMapItem {
    let value: JsonValue
    let tag: String

    protected init(value: JsonValue, tag: String) {
        this.value = value
        this.tag = tag
    }
}

class ResolveMapListItem <: ResolveMapItem {
    let list: Array<String>

    init(value: JsonValue, tag: String, list: Array<String>) {
        super(value, tag)
        this.list = list
    }
}

let yamlStyleFloat = Regex("^[-+]?(\\.[0-9]+|[0-9]+(\\.[0-9]*)?)([eE][-+]?[0-9]+)?$")

// 初始化
func initResolve() {
    if (resolveInited) {
        return
    }
    resolveTable[0x2B] = 0x53 // + => S
    resolveTable[0x2D] = 0x53 // - => S
    for (v in [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39]) { // 数字 => D
        resolveTable[v] = 0x44
    }
    for (v in [0x79, 0x59, 0x6E, 0x4E, 0x74, 0x54, 0x66, 0x46, 0x6F, 0x4F, 0x7E]) { // Map => M
        resolveTable[v] = 0x4D
    }
    resolveTable[0x2E] = 0x2E // . => .

    let resolveMapList = [
        ResolveMapListItem(JsonBool(true), YAML_BOOL_TAG, ["y", "Y", "yes", "Yes", "YES"]),
        ResolveMapListItem(JsonBool(true), YAML_BOOL_TAG, ["true", "True", "TRUE"]),
        ResolveMapListItem(JsonBool(true), YAML_BOOL_TAG, ["on", "On", "ON"]),
        ResolveMapListItem(JsonBool(false), YAML_BOOL_TAG, ["n", "N", "no", "No", "NO"]),
        ResolveMapListItem(JsonBool(false), YAML_BOOL_TAG, ["false", "False", "FALSE"]),
        ResolveMapListItem(JsonBool(false), YAML_BOOL_TAG, ["off", "Off", "OFF"]),
        ResolveMapListItem(JsonNull(), YAML_NULL_TAG, ["", "~", "null", "Null", "NULL"]),
        ResolveMapListItem(JsonFloat(Float64.Inf), YAML_FLOAT_TAG, [".inf", ".Inf", ".INF"]),
        ResolveMapListItem(JsonFloat(Float64.Inf), YAML_FLOAT_TAG, ["+.inf", "+.Inf", "+.INF"]),
        ResolveMapListItem(JsonFloat(-Float64.Inf), YAML_FLOAT_TAG, ["-.inf", "-.Inf", "-.INF"]),
        ResolveMapListItem(JsonString("<<"), YAML_MERGE_TAG, ["<<"])
    ]

    for (item in resolveMapList) {
        for (s in item.list) {
            resolveMap[s] = ResolveMapItem(item.value, item.tag)
        }
    }
}

/* func shortTag(tag: String): String {
   if (tag.startsWith(longTagPrefix)) {
       return "!!${tag[longTagPrefix.size..tag.size]}"
   }
   return tag
   }*/
func resolvableTag(tag: String): Bool {
    if (tag == "" || tag == YAML_STR_TAG || tag == YAML_BOOL_TAG || tag == YAML_INT_TAG || tag == YAML_FLOAT_TAG ||
        tag == YAML_NULL_TAG || tag == YAML_TIMESTAMP_TAG) {
        true
    } else {
        false
    }
}

func resolve(tag: String, input: String): (String, JsonValue) {
    if (!resolvableTag(tag)) {
        return (tag, JsonString(input))
    }

    let hint: Rune = if (input != "") {
        Rune(UInt32(resolveTable[Int64(input.toArray()[0])]))
    } else {
        r'N'
    }

    if (hint != Rune(0) && tag != YAML_STR_TAG && tag != YAML_BINARY_TAG) {
        if (let Some(item) <- resolveMap.get(input)) {
            return (item.tag, item.value)
        }
        match (hint) {
            case r'M' => ()
            case r'.' =>
                if (let Some(f) <- Float64.tryParse(input)) {
                    return (YAML_FLOAT_TAG, JsonFloat(f))
                }
            case r'D' | r'S' =>
                if (tag == "" || tag == YAML_TIMESTAMP_TAG) {
                    let (t, f) = parseTimestamp(input)
                    match (t) {
                        case Some(ti) => return (YAML_TIMESTAMP_TAG, JsonString(ti.format(f)))
                        case _ => ()
                    }
                }
                let plain = input.replace("_", "")
                if (let Some(i) <- Int64.tryParse(plain)) {
                    if (isOverflow("${Int64.Max}", plain)) {
                        return (YAML_STR_TAG, JsonString(plain))
                    }
                    return (YAML_INT_TAG, JsonInt(i))
                }
                if (let Some(i) <- UInt64.tryParse(plain)) {
                    if (isOverflow("${UInt64.Max}", plain)) {
                        return (YAML_STR_TAG, JsonString(plain))
                    }
                    try {
                        return (YAML_INT_TAG, JsonInt(Int64(i)))
                    } catch (e: OverflowException) {
                        return (YAML_STR_TAG, JsonString(plain))
                    }
                }
                if (yamlStyleFloat.matches(input)) {
                    if (let Some(f) <- Float64.tryParse(input)) {
                        return (YAML_FLOAT_TAG, JsonFloat(f))
                    }
                }
                if (input.startsWith("0b")) {
                    if (let Some(i) <- Int64.tryParse(plain[2..plain.size])) {
                        if (isOverflow("${Int64.Max}", plain[2..plain.size])) {
                            return (YAML_STR_TAG, JsonString(plain))
                        }
                        return (YAML_INT_TAG, JsonInt(i))
                    }
                } else if (input.startsWith("-0b")) {
                    if (let Some(i) <- Int64.tryParse("-${plain[2..plain.size]}")) {
                        if (isOverflow("${Int64.Max}", "-${plain[2..plain.size]}")) {
                            return (YAML_STR_TAG, JsonString(plain))
                        }
                        return (YAML_INT_TAG, JsonInt(i))
                    }
                }
            case _ => throw Exception("resolveTable item not yet handled: ${hint} (with ${input})")
        }
    }

    (YAML_STR_TAG, JsonString(input))
}

func isOverflow(maxValue: String, targetValue: String): Bool {
    if (maxValue.size < targetValue.size) {
        true
    } else if (maxValue.size == targetValue.size) {
        let mA = maxValue.toArray()
        let tA = targetValue.toArray()
        for (i in 0..mA.size) {
            if (mA[i] < tA[i]) {
                return true
            }
        }
        false
    } else {
        false
    }
}

let allowedTimestampFormats = [
    "dd MMM yyyy HH:mm:ss z",
    "MMM dd HH:mm:ss zzz yyyy",
    "yyyy-MM-dd'T'HH:mm:ss'Z'",
    "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
    "yyyy-MM-dd'T'HH:mm:ssZ",
    "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
    "yyyy年MM月dd日 HH时mm分ss秒",
    "yyyy-MM-dd HH:mm:ss.SSS",
    "yyyy/MM/dd HH:mm:ss",
    "yyyy.MM.dd HH:mm:ss",
    "yyyy-MM-dd HH:mm",
    "yyyyMMddHHmmssSSS",
    "yyyyMMddHHmmss",
    "yyyyMMdd",
    "HH时mm分ss秒",
    "yyyy-MM-dd",
    "yyyy/MM/dd",
    "yyyy.MM.dd",
    "HH:mm:ss"
]

func parseTimestamp(s: String): (?DateTime, String) {
    for (t in allowedTimestampFormats) {
        try {
            let n = DateTime.parse(s, t)
            return (n, t)
        } catch (e: Exception) {}
    }
    (None, "")
}

