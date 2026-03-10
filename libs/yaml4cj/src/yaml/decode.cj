/**
 * @file
 * This file is about yaml decode.
 */

package yaml4cj.yaml

/**
 * The Function is decode
 *
 * @param data of Array<UInt8>
 *
 * @return Type of JsonValue
 * @since 0.30.4
 */
public func decode(data: Array<UInt8>): JsonValue {
    initResolve()
    decode(data, false)
}

/**
 * The Function is decode
 *
 * @param data of Array<UInt8>
 * @param strict of Bool
 *
 * @return Type of JsonValue
 * @since 0.30.4
 */
public func decode(data: Array<UInt8>, strict: Bool): JsonValue {
    initResolve()
    let p = Parser(data)
    try {
        let r = p.parse()
        match (r) {
            case Some(n) =>
                let d = Decoder(strict)
                let (out, _) = d.decode(n)
                if (d.terrors.size > 0) {
                    throw TypeError(d.terrors.toArray())
                }
                return out
            case _ => return JsonNull()
        }
    } catch (err: Exception) {
        throw err
    } finally {
        p.destroy()
    }
}

class Decoder {
    var doc: ?Node = None
    var aliases: HashMap<Node, Bool>
    var terrors: ArrayList<String> = ArrayList<String>()
    var strict: Bool
    var decodeCount: Int64 = 0
    var aliasCount: Int64 = 0
    var aliasDepth: Int64 = 0

    init(strict: Bool) {
        this.strict = strict
        this.aliases = HashMap<Node, Bool>()
    }

    func decode(n: Node): (JsonValue, Bool) {
        this.decodeCount++
        if (this.aliasDepth > 0) {
            this.aliasCount++
        }

        // if (this.aliasCount > 100 && this.decodeCount > 1000 && (Float64(this.aliasCount) / Float64(this.decodeCount)) >
        //     allowedAliasRatio(this.decodeCount)) {
        //     failf("document contains excessive aliasing")
        // }
        match (n.kind) {
            case ParserNodeType_DOCUMENT_NODE => return document(n)
            case ParserNodeType_ALIAS_NODE => return alias(n)
            case ParserNodeType_SCALAR_NODE => return scalar(n)
            case ParserNodeType_MAPPING_NODE => return mapping(n)
            case ParserNodeType_SEQUENCE_NODE => return sequence(n)
            case _ => throw Exception("internal error: unknown node kind: ${n.kind}")
        }
    }

    func document(n: Node): (JsonValue, Bool) {
        if (n.children.size == 1) {
            this.doc = n
            let (out, _) = decode(n.children[0].getOrThrow())
            return (out, true)
        }
        return (JsonNull(), false)
    }

    func alias(n: Node): (JsonValue, Bool) {
        if (match (this.aliases.get(n)) {
            case Some(r) => r
            case _ => false
        }) {
            failf("anchor '${n.value}' value contains itself")
        }
        this.aliases[n] = true
        this.aliasDepth++
        let (out, good) = decode(n.alias.getOrThrow())
        this.aliasDepth--
        this.aliases.remove(n)
        return (out, good)
    }

    func scalar(n: Node): (JsonValue, Bool) {
        var tag = ""
        var resolved: JsonValue = JsonNull()
        if (n.tag == "" && !n.implicit) {
            tag = YAML_STR_TAG
            resolved = JsonString(n.value)
        } else {
            let (t, r) = resolve(n.tag, n.value)
            tag = t
            resolved = r
            if (tag == YAML_BINARY_TAG) {
                let data = fromBase64String(resolved.asString().getValue().replace("\n", ""))
                match (data) {
                    case Some(d) =>
                        let resolve = JsonArray()
                        for (i in d) {
                            resolve.add(JsonInt(Int64(i)))
                        }
                        resolved = resolve

                    case _ => failf("!!binary value contains invalid base64 data")
                }
            }
        }
        return (resolved, true)
    }

    func mapping(n: Node): (JsonValue, Bool) {
        let parent = JsonObject()
        let children = n.children
        for (i in 0..children.size : 2) {
            if (isMerge(children[i].getOrThrow())) {
                continue
            }
            let (k, kok) = decode(children[i].getOrThrow())
            if (kok) {
                let (v, vok) = decode(children[i + 1].getOrThrow())
                if (vok) {
                    if (k is JsonArray) {
                        (k as JsonArray).getOrThrow()
                    }
                    parent.put(decodeKey(k), v)
                }
            }
        }
        (parent, true)
    }

    func sequence(n: Node): (JsonValue, Bool) {
        let parent = JsonArray()
        for (v in n.children) {
            let (item, ok) = decode(v.getOrThrow())
            if (ok) {
                parent.add(item)
            }
        }
        (parent, true)
    }
}

let aliasRatioRangeLow = 400000

let aliasRatioRangeHigh = 4000000

let aliasRatioRange = Float64(aliasRatioRangeHigh - aliasRatioRangeLow)

/*
   func allowedAliasRatio(decodeCount: Int64): Float64 {
       if (decodeCount <= aliasRatioRangeLow) {
           0.99
       } else if (decodeCount >= aliasRatioRangeHigh) {
           0.10
       } else {
           0.99 - 0.89 * (Float64(decodeCount - aliasRatioRangeLow) / aliasRatioRange)
       }
   }
 */
func isMerge(n: Node): Bool {
    return n.kind == ParserNodeType_SCALAR_NODE && n.value == "<<" && (n.implicit == true || n.tag == YAML_MERGE_TAG)
}

func decodeKey(k: JsonValue): String {
    if (k is JsonArray) {
        var s = ""
        var i = 0
        for (v in k.asArray().getItems()) {
            if (i > 0) {
                s += ","
            }
            s += decodeKey(v)
            i++
        }
        s
    } else if (k is JsonObject) {
        k.asObject().toJsonString()
    } else if (k is JsonString) {
        k.asString().getValue()
    } else {
        k.toString()
    }
}
